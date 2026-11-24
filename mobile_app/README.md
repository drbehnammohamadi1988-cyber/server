# اوربی هوش (Orbi AI) — اپلیکیشن اندروید چت‌بات هوش مصنوعی فارسی

اپلیکیشن موبایل Flutter با طراحی **Cosmic Glass (شیشه کیهانی)** و موتور چندتمه زنده (شامل ۵ تم دست‌ساز: شیشه کیهانی، نئومورفیسم تاریک، سرامیک روشن، آمُلد خالص و شیشه یخی روشن)، تایپوگرافی بومی **Vazirmatn** و **JetBrains Mono**، اتصال ۱:۱ به سرور `gateway` (`/v1/models`, `/v1/chat/completions`, `/health/live`)، موتور ساخت فایل و PDF فارسی (با شکل‌دهی کامل فارسی و BiDi)، استودیو تصویر و مکالمه صوتی زنده.

## مستندات معماری و نگاشت سرور
- [MOBILE_ARCHITECTURE.md](MOBILE_ARCHITECTURE.md)

## اجرا و تست محلی
```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release --split-per-abi --dart-define=GATEWAY_BASE_URL=http://10.0.2.2:8080
```
