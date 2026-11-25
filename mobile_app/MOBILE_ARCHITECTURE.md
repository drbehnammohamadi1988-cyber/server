# معماری اپلیکیشن موبایل اوربی (Orbi AI) و نگاشت کامل به سرور `gateway`

این سند نتیجهٔ تحلیل مستقیم سورس‌کد مخزن `gateway` (`/home/ubuntu/webapi`)، باینری فعال سرویس `aigw-gateway.service` (`/home/ubuntu/aigw/bin/gateway`) و پیکربندی سرور (`/etc/systemd/system/aigw-gateway.service`) پیش از نگارش کد Flutter است.

---

## ۱. توپولوژی سرور `gateway`، رلهٔ ایزوله `orbi-duck-relay` و اتصال HTTPS

بر اساس واحد سیستم `aigw-gateway.service` و کد `internal/app/app.go` به همراه لایهٔ ایزولهٔ `orbi-duck-relay.service` + `orbi-duck-tunnel.service`:

| سرویس / لیسنر | آدرس | نقش و سطح دسترسی |
|---|---|---|
| **Orbi Stateless Duck.ai Relay** (`orbi-duck-relay.service`) | `127.0.0.1:8090` | رلهٔ کاملاً ایزوله و بدون وضعیت (Read/Chat-Only) با Systemd Sandboxing کامل؛ تنها دریافت لیست مدل‌های زنده از `duck.ai` و ردوبدل مستقیم پیام چت |
| **HTTPS Tunnel** (`orbi-duck-tunnel.service`) | `https://park-analyses-durable-analyses.trycloudflare.com` | تونل رمزنگاری‌شده عمومی که در پس‌زمینه اپلیکیشن موبایل بدون نیاز به تنظیمات کاربر متصل می‌شود |
| **Core Gateway API** (`aigw-gateway.service`) | `127.0.0.1:8080` | ارتباط مستقیم با `https://duck.ai` روی لوکال‌هاست |
| **Operational HTTP Listener** (`:8081`) | داخلی فقط (`8081`) | برای کلاینت موبایل غیرفعال/مسدود است تا هیچ دسترسی عملیاتی یا تغییر سروری وجود نداشته باشد |

---

## ۲. لیست دقیق Endpointهای کشف‌شده از `gateway`

با بررسی تابع `(*Server).Handler` در `internal/gateway` و تست زنده روی `127.0.0.1:8080` و `127.0.0.1:8081`، Endpointهای دقیق سرور عبارتند از:

### ۲.۱. کشف پویای مدل‌ها (Dynamic Model Discovery)
- **مسیر:** `GET /v1/models`
- **پاسخ `200 OK` (`application/json`):**
  ```json
  {
    "object": "list",
    "data": [
      { "id": "gpt-4o-mini", "object": "model" },
      { "id": "claude-3-haiku-20240307", "object": "model" },
      { "id": "meta-llama/Llama-3.3-70B-Instruct-Turbo", "object": "model" }
    ]
  }
  ```
- **نکتهٔ کلیدی:** کلاینت هیچ نام مدل هاردکدشده‌ای برای ارسال به سرور نگه نمی‌دارد؛ فهرست مدل‌ها تماماً از `GET /v1/models` خوانده و متادیتای نمایشی (مانند بینایی/سرعت/استدلال در صورت وجود در پاسخ یا بر اساس شناسهٔ دریافت‌شده از سرور) به صورت داینامیک استنتاج می‌شود.

### ۲.۲. تکمیل گفتگو (چت استریم و غیراستریم)
- **مسیر:** `POST /v1/chat/completions`
- **هدرهای ارسالی:**
  - `Content-Type: application/json`
  - `Accept: text/event-stream` (در حالت `stream: true`) یا `application/json` (در حالت `stream: false`)
  - `Authorization: Bearer <token>` (اختیاری در توسعه؛ آماده برای احراز هویت `internal/auth` و ذخیره‌سازی امن در `flutter_secure_storage`)
  - `X-Conversation-ID: <uuid>` (پارس‌شده توسط `handleChatCompletions` از طریق `domain.ParseID`)
  - `X-Idempotency-Key: <uuid>` (تعریف‌شده در کلاینت‌های اکوسیستم `webapi`)
- **بدنهٔ درخواست (`openaiwire.Request` / `handleChatCompletions`):**
  ```json
  {
    "model": "gpt-4o-mini",
    "messages": [
      { "role": "system", "content": "..." },
      { "role": "user", "content": "..." }
    ],
    "stream": true,
    "temperature": 0.7,
    "top_p": 0.95,
    "max_tokens": 2048,
    "stop": ["..."]
  }
  ```
  - **محدودیت واقعی کشف‌شده در سرور:** ساختار `openaiwire.Message` در `gateway` فیلد `content` را به صورت `string` پارس می‌کند (ارسال آرایهٔ چندرسانه‌ای در نسخهٔ فعلی باینری منجر به `400 Bad Request: invalid JSON payload` می‌شود). بنابراین:
    - در حالت پیش‌فرض (سازگار با `gateway` فعلی)، متن پیوست‌های متنی/اسناد (TXT, MD, CSV, JSON, Code, PDF استخراج‌شده) و توضیح/متادیتای تصاویر به صورت ساختارمند در `content` رشته‌ای قرار می‌گیرند.
    - قابلیت اختیاری `Multimodal Vision Format` در تنظیمات `gateway` تعبیه شده است تا در صورت ارتقای `gateway` به آرایهٔ `content: [{type: "text"}, {type: "image_url"}]` بدون تغییر کد کلاینت کار کند و در صورت دریافت خطای `400` از سرور متنی، به‌صورت خودکار fallback امن انجام شود.

- **پاسخ استریم (`stream: true`):**
  - وضعیت: `200 OK` با `Content-Type: text/event-stream`، `Cache-Control: no-cache`، `Connection: keep-alive`
  - قالب رویدادهای SSE:
    ```text
    data: {"choices":[{"delta":{"content":"سلام"}}]}

    data: {"choices":[{"delta":{"content":" دنیا"}}]}

    data: [DONE]
    ```
  - پارسر کلاینت علاوه بر `choices[0].delta.content`، فیلدهای استاندارد آیندهٔ `webapi` (`reasoning_content`، تگ‌های `<think>...</think>`، `finish_reason`، `usage` و رویداد `error`) را نیز پشتیبانی می‌کند.
  - **ایمنی UTF-8 چندبایتی:** استریم بایت‌های شبکه (`Uint8List`) هرگز مستقیم روی چانک تکی decode نمی‌شود؛ زنجیرهٔ `StreamTransformer.fromBind(utf8.decoder.bind)` + `LineSplitter()` کاراکترهای فارسی ۲/۳/۴ بایتی را حتی در صورت شکستن بین بسته‌های TCP بدون خرابی رندر می‌کند.

- **پاسخ غیراستریم (`stream: false`):**
  - وضعیت: `200 OK` با `Content-Type: application/json`
  - بدنه:
    ```json
    {
      "choices": [
        {
          "finish_reason": "stop",
          "message": { "role": "assistant", "content": "..." }
        }
      ]
    }
    ```

### ۲.۳. بررسی سلامت سرور (Health Check)
- **مسیرهای Ops Listener (`:8081`):**
  - `GET /health/live` ← پاسخ `200 OK`: `{"status":"ok"}`
  - `GET /health/ready` ← پاسخ `200 OK` یا `503 Service Unavailable`: `{"ready":false,"reason":"...","checks":[]}`
- **استراتژی کلاینت در صفحهٔ تنظیمات:**
  - تست اتصال اصلی روی `{baseUrl}/v1/models` اجرا می‌شود تا هم دسترسی واقعی API و هم تاخیر (Latency بر حسب میلی‌ثانیه) سنجیده شود و هم لیست مدل‌ها همگام‌سازی گردد.
  - اگر پورت یا مسیر `/health/live` روی همان هاست یا پروکسی در دسترس باشد، وضعیت آن نیز به‌صورت تکمیلی گزارش می‌شود.

### ۲.۴. مدیریت خطاها و کدهای وضعیت HTTP
در باینری فعلی `gateway` خطاها به صورت `text/plain` (`http.Error`) و در فازهای بعدی `webapi` (`openaiwire/errors.go`) به صورت `{"error":{"message":"...","code":"..."}}` برمی‌گردند. لایهٔ `GatewayErrorMapper` هر دو فرمت را پارس و به پیام‌های دقیق و مودبانهٔ فارسی نگاشت می‌کند:
- `400 Bad Request`: خطای اعتبارسنجی ورودی (مانند پیام خالی یا پارامتر نامعتبر)
- `401 Unauthorized`: کلید دسترسی نامعتبر یا منقضی‌شده (`unauthenticated`)
- `403 Forbidden`: عدم دسترسی (`permission_denied`)
- `404 Not Found`: مدل یا مسیر درخواستی یافت نشد (`not_found`)
- `409 Conflict` / `408 Request Timeout`: تداخل همزمانی یا اتمام مهلت پاسخ سرور
- `429 Too Many Requests`: محدودیت نرخ ارسال (`rate_limited`) همراه با خواندن هدر `Retry-After`
- `500 Internal Server Error` / `502 Bad Gateway` / `503 Service Unavailable`: خطای سرویس بالادستی (`upstream_error`) با دکمهٔ «تلاش مجدد»

### ۲.۵. وضعیت قابلیت‌های چندرسانه‌ای و صوتی نسبت به `gateway` فعلی
با بررسی سورس و تست `gateway` مشخص شد سرور فعلی دو مسیر `/v1/models` و `/v1/chat/completions` را ارائه می‌دهد و مسیرهای `/v1/images/generations` و `/v1/audio/*` فعلاً `404 Not Found` برمی‌گردانند. بر این اساس در اپلیکیشن **هیچ پاسخ ماک/ساختگی وجود ندارد**:
1. **استودیو تولید تصویر (`Image Studio`):**
   - ابتدا بهبود پرامپت (Prompt Enhancer) به‌صورت واقعی از طریق `POST /v1/chat/completions` روی `gateway` انجام می‌شود.
   - درخواست تولید تصویر به `POST /v1/images/generations` ارسال می‌شود (آماده برای زمانی که این مسیر روی `gateway` فعال شود). در صورت دریافت `404` از سرور فعلی، اپلیکیشن به‌صورت شفاف اطلاع می‌دهد و امکان **تولید اثر گرافیکی برداری زنده (SVG-to-PNG)** را مستقیماً از طریق مدل فعال روی `gateway` ارائه می‌دهد که تصویر واقعی PNG با کیفیت بالا رندر، در گالری ذخیره و به اشتراک گذاشته می‌شود.
2. **صوت و مکالمه زنده (`Voice Mode`):**
   - تبدیل گفتار به متن (`STT`) و متن به گفتار (`TTS`) با موتور بومی اندروید (`speech_to_text` و `flutter_tts`) روی دستگاه اجرا و متن به صورت زنده به `POST /v1/chat/completions` استریم می‌شود.
3. **موتور ساخت فایل (`Artifacts Engine`):**
   - تولید محتوای ساختاریافته از طریق `gateway` و تبدیل واقعی در دستگاه به فایل‌های `.pdf` (با فونت امبدشده `Vazirmatn` و شکل‌دهی صحیح فارسی + BiDi)، `.md`، `.html` (همراه با WebView پیش‌نمایش زنده)، `.csv`، `.json` و کدهای برنامه‌نویسی.

---

## ۳. نگاشت لایهٔ شبکه به مخزن‌ها (Repositories) در Flutter

```text
GatewayHttpClient (Dio + SecureStorage + UTF-8 Safe SSE)
 ├── GatewayModelRepository       ──► GET  /v1/models
 ├── GatewayChatRepository        ──► POST /v1/chat/completions (stream: true / false + CancelToken)
 ├── GatewayHealthRepository      ──► GET  /v1/models (ping) + GET /health/live (optional ops check)
 └── GatewayStudioRepository      ──► POST /v1/images/generations (with real SVG-via-chat fallback on 404)
                                       &  POST /v1/chat/completions (prompt enhancer)

LocalStorage (SQLite via sqflite + FlutterSecureStorage)
 ├── ChatHistoryRepository        ──► conversations, messages, attachments, branching, full-text search
 ├── ArtifactRepository           ──► saved/generated files (PDF/HTML/MD/CSV/JSON/Code) + Share + Gallery
 └── SettingsRepository           ──► active theme (4 presets), reduced blur, gateway URL, model prefs, JSON backup
```
