# 🖥️ سرور همگام‌سازی شکاتل کافی

این سرور، واسطه‌ی بین اپلیکیشن‌ها (exe و apk) و دیتابیس ابری آروان کلاد است.
اپ‌ها از طریق اینترنت به این سرور وصل می‌شوند و سرور به دیتابیس MySQL مدیریت‌شده‌ی آروان.

```
اپلیکیشن (exe / apk)  ──HTTPS──►  این سرور (Node.js)  ──MySQL──►  دیتابیس آروان
```

---

## ۱) اجرای محلی (تست / توسعه)

بدون نیاز به کلید دیتابیس، با SQLite اجرا می‌شود:

```bash
cd server
npm install
node server.js        # port 3000
```

برای اجرا با دیتابیس آروان، فایل `config.json` (یا متغیرهای محیطی) را پر کنید.

## ۲) پیکربندی دیتابیس آروان

فایل `config.json` را بسازید (از روی `config.example.json`) و کلیدها را بگذارید:

```json
{
  "port": 3000,
  "appKey": "یک-کلید-طولانی-تصادفی",
  "db": {
    "type": "mysql",
    "host": "8b197bce...db.arvandbaas.ir",
    "port": 3306,
    "user": "base-user",
    "password": "رمز-دیتابیس",
    "database": "default",
    "ssl": true
  }
}
```

> یا به‌جای `config.json` می‌توانید همه‌چیز را با متغیرهای محیطی ست کنید:
> `DB_TYPE=mysql DB_HOST=... DB_PORT=3306 DB_USER=... DB_PASSWORD=... DB_NAME=default DB_CA=/app/ca.pem APP_KEY=... PORT=3000`
>
> کلید `appKey` باید **دقیقاً** با مقدار داخل فایل `config.local.json` پروژه (که هنگام build در apk/exe قرار می‌گیرد) یکی باشد.

## ۳) ساخت ایمیج داکر و دیپلوی روی ArvanCloud

### ۳-الف) ساخت ایمیج (خودکار با GitHub Actions)

این ریپو یک workflow دارد (`.github/workflows/docker.yml`) که با هر push روی `main`
(یا به‌صورت دستی از تب **Actions**) ایمیج را می‌سازد و به **GHCR** می‌فرستد:

```
ghcr.io/drbehnammohamadi1988-cyber/server:latest
```

پکیج GHCR عمومی است — آروان بدون نیاز به هیچ توکنی می‌تواند آن را pull کند.

### ۳-ب) دیپلوی روی ArvanCloud Cloud Container

1. در پنل آروان → **Cloud Container** → container جدید با سورس **Docker Registry** بسازید.
2. آدرس ایمیج را بدهید:
   `ghcr.io/drbehnammohamadi1988-cyber/server:latest`
3. در تنظیمات container این **متغیرهای محیطی** را وارد کنید (رمز داخل تصویر نیست — این‌جا ست می‌شود):

   ```
   PORT=3000
   APP_KEY=همان-کلید-appKey
   DB_TYPE=mysql
   DB_HOST=8b197bce...db.arvandbaas.ir
   DB_PORT=3306
   DB_USER=base-user
   DB_PASSWORD=رمز-دیتابیس
   DB_NAME=default
   ```

4. پورت سرویس **3000** را ست کنید.
5. یک **دامنه** (مثلاً `api.shekatel.ir`) به container وصل کنید + **SSL** فعال کنید.
6. بعد از استارت، این آدرس باید پاسخ بدهد:
   `https://api.shekatel.ir/api/meta/version` → `{"version":1}`

> ⚠️ مهم: فایروال دیتابیس آروان باید به IP کانتینر دسترسی بدهد (پیش‌فرض «باز به همه» است).
> اگر دیتابیس‌تان از بیرون IP-allow کند، IP کانتینر را اضافه کنید.

## ۴) اتصال اپلیکیشن‌ها

بعد از دیپلوی، آدرس HTTPS سرور را در `config.local.json` ریشه‌ی پروژه بگذارید:

```json
{
  "apiUrl": "https://api.shekatel.ir",
  "appKey": "همان-کلید-appKey"
}
```

سپس دوباره APK و exe را build کنید — تنظیمات به‌صورت خودکار داخل فایل‌ها قرار می‌گیرد
و بعد از نصب روی هر سیستمی، بدون هیچ تنظیم دستی، آنلاین و به هم متصل می‌شوند.

## نکته امنیتی

- رمز دیتابیس فقط در `config.json` یا متغیر محیطی سرور است (و `config.json` در git نیست).
- `config.local.json` و `src/lib/config.generated.ts` هم git-ignore شده‌اند.
- فقط `appKey` (نه رمز دیتابیس) داخل apk/exe قرار می‌گیرد.
