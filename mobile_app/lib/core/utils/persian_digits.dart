import 'package:shamsi_date/shamsi_date.dart';

/// Utilities for Persian numerals, Jalali calendar buckets, and microcopy.
class PersianFormatter {
  const PersianFormatter._();

  static const _digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  static String toPersianDigits(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        buffer.write(_digits[code - 48]);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  static String formatDurationSeconds(Duration duration) {
    final seconds = duration.inMilliseconds / 1000.0;
    return '${toPersianDigits(seconds.toStringAsFixed(1))} ثانیه';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${toPersianDigits(bytes.toString())} بایت';
    }
    if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '${toPersianDigits(kb)} کیلوبایت';
    }
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '${toPersianDigits(mb)} مگابایت';
  }

  static String formatJalaliShort(DateTime dateTime) {
    final j = Jalali.fromDateTime(dateTime);
    final monthName = j.formatter.mN;
    return '${toPersianDigits(j.day.toString())} $monthName';
  }

  static String formatTimePersian(DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return toPersianDigits('$h:$m');
  }

  /// Buckets conversation timestamps into authentic Persian history groups.
  static String historyBucketLabel(DateTime updatedAt, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final todayStart = DateTime(reference.year, reference.month, reference.day);
    final targetDay = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
    final diffDays = todayStart.difference(targetDay).inDays;

    if (diffDays <= 0) return 'امروز';
    if (diffDays == 1) return 'دیروز';
    if (diffDays <= 7) return '۷ روز گذشته';

    final nowJalali = Jalali.fromDateTime(reference);
    final targetJalali = Jalali.fromDateTime(updatedAt);
    if (nowJalali.year == targetJalali.year &&
        nowJalali.month == targetJalali.month) {
      return 'این ماه';
    }
    return 'قدیمی‌تر';
  }

  static String greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) return 'صبح بخیر! همهٔ ایده‌هات رو بپرس';
    if (hour >= 12 && hour < 17) return 'ظهر بخیر! چطور می‌تونم کمکت کنم؟';
    if (hour >= 17 && hour < 21) return 'عصر بخیر! آمادهٔ گفتگوی هوشمندیم';
    return 'همه‌چیز رو بپرس';
  }
}
