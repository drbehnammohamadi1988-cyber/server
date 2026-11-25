import 'dart:convert';

import 'package:dio/dio.dart';

enum GatewayErrorCode {
  invalidArgument,
  unauthenticated,
  permissionDenied,
  notFound,
  rateLimited,
  timeout,
  cancelled,
  upstreamError,
  networkError,
  unknown,
}

/// Structured, user-safe exception mapped from `gateway` HTTP or transport errors.
class GatewayException implements Exception {
  const GatewayException({
    required this.code,
    required this.messageFa,
    this.statusCode,
    this.rawDetail,
    this.retryAfter,
    this.isRetryable = false,
  });

  final GatewayErrorCode code;
  final String messageFa;
  final int? statusCode;
  final String? rawDetail;
  final Duration? retryAfter;
  final bool isRetryable;

  bool get isCancelled => code == GatewayErrorCode.cancelled;

  @override
  String toString() =>
      'GatewayException(code: $code, status: $statusCode, detail: $rawDetail)';
}

/// Translates `DioException` and HTTP error responses (both JSON
/// `{"error":{"message":...}}` and `text/plain` from `http.Error`) into
/// clear Persian [GatewayException] values.
class GatewayErrorMapper {
  const GatewayErrorMapper._();

  static GatewayException fromHttpStatus({
    required int statusCode,
    String? rawBody,
    String? retryAfterHeader,
  }) {
    final detail = extractMessage(rawBody);
    final retryAfter = parseRetryAfter(retryAfterHeader);

    switch (statusCode) {
      case 400:
      case 422:
        return GatewayException(
          code: GatewayErrorCode.invalidArgument,
          statusCode: statusCode,
          rawDetail: detail,
          messageFa: detail.isNotEmpty
              ? 'درخواست ارسالی معتبر نیست: $detail'
              : 'ساختار درخواست ارسالی معتبر نیست. لطفاً ورودی را بررسی کنید.',
        );
      case 401:
        return GatewayException(
          code: GatewayErrorCode.unauthenticated,
          statusCode: statusCode,
          rawDetail: detail,
          messageFa: 'دسترسی موقتاً مجاز نشد. لطفاً لحظاتی دیگر دوباره تلاش کنید.',
        );
      case 403:
        return GatewayException(
          code: GatewayErrorCode.permissionDenied,
          statusCode: statusCode,
          rawDetail: detail,
          messageFa:
              'دسترسی به این مدل موقتاً امکان‌پذیر نیست. مدل دیگری را امتحان کنید.',
        );
      case 404:
        return GatewayException(
          code: GatewayErrorCode.notFound,
          statusCode: statusCode,
          rawDetail: detail,
          messageFa: detail.isNotEmpty
              ? 'مدل یا مسیر درخواستی یافت نشد ($detail).'
              : 'مدل یا سرویس درخواستی در دسترس نیست.',
        );
      case 408:
      case 504:
        return GatewayException(
          code: GatewayErrorCode.timeout,
          statusCode: statusCode,
          rawDetail: detail,
          isRetryable: true,
          messageFa:
              'پاسخ‌گویی سرور بیش از حد طول کشید. لطفاً دوباره تلاش کنید.',
        );
      case 409:
        return GatewayException(
          code: GatewayErrorCode.invalidArgument,
          statusCode: statusCode,
          rawDetail: detail,
          isRetryable: true,
          messageFa:
              'یک درخواست هم‌زمان در حال پردازش است. چند لحظه دیگر دوباره تلاش کنید.',
        );
      case 429:
        final waitNote = retryAfter != null
            ? ' لطفاً ${retryAfter.inSeconds} ثانیه صبر کنید.'
            : ' لطفاً کمی بعد دوباره تلاش کنید.';
        return GatewayException(
          code: GatewayErrorCode.rateLimited,
          statusCode: statusCode,
          rawDetail: detail,
          retryAfter: retryAfter,
          isRetryable: true,
          messageFa: 'محدودیت تعداد درخواست در لحظه فعال شده است.$waitNote',
        );
      case 500:
      case 502:
      case 503:
        return GatewayException(
          code: GatewayErrorCode.upstreamError,
          statusCode: statusCode,
          rawDetail: detail,
          isRetryable: true,
          messageFa: detail.isNotEmpty
              ? 'سرویس هوش مصنوعی با خطای موقت مواجه شد ($detail). می‌توانید دوباره تلاش کنید.'
              : 'سرویس هوش مصنوعی موقتاً در دسترس نیست. لطفاً دوباره تلاش کنید.',
        );
      default:
        return GatewayException(
          code: GatewayErrorCode.unknown,
          statusCode: statusCode,
          rawDetail: detail,
          isRetryable: statusCode >= 500,
          messageFa: 'خطای غیرمنتظره از سرور (کد $statusCode).',
        );
    }
  }

  static GatewayException fromDio(DioException error, {String? bodyOverride}) {
    if (error.type == DioExceptionType.cancel) {
      return const GatewayException(
        code: GatewayErrorCode.cancelled,
        messageFa: 'تولید پاسخ متوقف شد.',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const GatewayException(
        code: GatewayErrorCode.timeout,
        isRetryable: true,
        messageFa:
            'مهلت زمانی برقراری ارتباط با سرور به پایان رسید. اتصال اینترنت گوشی خود را بررسی کنید و دوباره تلاش کنید.',
      );
    }

    final response = error.response;
    if (response != null && response.statusCode != null) {
      final rawText = bodyOverride ?? _coerceResponseBody(response.data);
      return fromHttpStatus(
        statusCode: response.statusCode!,
        rawBody: rawText,
        retryAfterHeader: response.headers.value('retry-after'),
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return const GatewayException(
        code: GatewayErrorCode.networkError,
        isRetryable: true,
        messageFa:
            'برقراری ارتباط با سرور موقتاً ممکن نیست. اتصال اینترنت را بررسی کرده و دوباره تلاش کنید.',
      );
    }

    return GatewayException(
      code: GatewayErrorCode.networkError,
      rawDetail: error.message,
      isRetryable: true,
      messageFa: 'خطا در ارتباط شبکه با سرور. لطفاً دوباره تلاش کنید.',
    );
  }

  static String extractMessage(String? rawBody) {
    if (rawBody == null) return '';
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final err = decoded['error'];
          if (err is Map<String, dynamic>) {
            final msg = err['message']?.toString().trim();
            if (msg != null && msg.isNotEmpty) return msg;
          }
          final msg = decoded['message']?.toString().trim();
          if (msg != null && msg.isNotEmpty) return msg;
        }
      } catch (_) {
        // Fallback to trimmed raw body below
      }
    }
    return trimmed.length > 220 ? '${trimmed.substring(0, 220)}…' : trimmed;
  }

  static Duration? parseRetryAfter(String? header) {
    if (header == null) return null;
    final trimmed = header.trim();
    if (trimmed.isEmpty) return null;
    final seconds = int.tryParse(trimmed);
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  static String? _coerceResponseBody(Object? data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is List<int>) {
      return utf8.decode(data, allowMalformed: true);
    }
    if (data is Map) {
      try {
        return jsonEncode(data);
      } catch (_) {
        return data.toString();
      }
    }
    return data.toString();
  }
}
