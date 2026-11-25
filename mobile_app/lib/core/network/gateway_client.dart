import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import 'gateway_error.dart';

/// Configured HTTP transport for communicating with the `gateway` server.
class GatewayHttpClient {
  GatewayHttpClient({
    required SecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 5),
                validateStatus: (status) => status != null && status < 600,
              ),
            );

  final SecureStorageService _secureStorage;
  final Dio _dio;

  Future<Map<String, String>> _buildHeaders({
    String accept = 'application/json',
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': accept,
    };
    final apiKey = await _secureStorage.readGatewayApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Future<Response<dynamic>> getJson(
    String baseUrl,
    String path, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final normalized = AppConfig.normalizeBaseUrl(baseUrl);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _buildHeaders();
        final response = await _dio.get<dynamic>(
          '$normalized$path',
          cancelToken: cancelToken,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
            receiveTimeout: timeout ?? const Duration(seconds: 20),
          ),
        );
        final code = response.statusCode ?? 0;
        if (code < 200 || code >= 300) {
          throw GatewayErrorMapper.fromHttpStatus(
            statusCode: code,
            rawBody: response.data?.toString(),
            retryAfterHeader: response.headers.value('retry-after'),
          );
        }
        return response;
      } on DioException catch (e) {
        final transient = attempt == 0 &&
            (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout);
        if (transient && !(cancelToken?.isCancelled ?? false)) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw GatewayErrorMapper.fromDio(e);
      }
    }
    throw const GatewayException(
      code: GatewayErrorCode.networkError,
      isRetryable: true,
      messageFa: 'ارتباط با سرور برقرار نشد. لطفاً دوباره تلاش کنید.',
    );
  }

  Future<Response<dynamic>> postJson(
    String baseUrl,
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? extraHeaders,
    CancelToken? cancelToken,
  }) async {
    final normalized = AppConfig.normalizeBaseUrl(baseUrl);
    try {
      final headers = await _buildHeaders(extra: extraHeaders);
      final response = await _dio.post<dynamic>(
        '$normalized$path',
        data: jsonEncode(body),
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw GatewayErrorMapper.fromHttpStatus(
          statusCode: code,
          rawBody: response.data?.toString(),
          retryAfterHeader: response.headers.value('retry-after'),
        );
      }
      return response;
    } on DioException catch (e) {
      throw GatewayErrorMapper.fromDio(e);
    }
  }

  /// Opens a streaming SSE POST request and ensures non-200 bodies are decoded
  /// cleanly before throwing a [GatewayException].
  Future<Response<ResponseBody>> postStream(
    String baseUrl,
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? extraHeaders,
    CancelToken? cancelToken,
  }) async {
    final normalized = AppConfig.normalizeBaseUrl(baseUrl);
    try {
      final headers = await _buildHeaders(
        accept: 'text/event-stream',
        extra: extraHeaders,
      );
      final response = await _dio.post<ResponseBody>(
        '$normalized$path',
        data: jsonEncode(body),
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 6),
        ),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        final errorText = await _readStreamText(response.data);
        throw GatewayErrorMapper.fromHttpStatus(
          statusCode: code,
          rawBody: errorText,
          retryAfterHeader: response.headers.value('retry-after'),
        );
      }
      if (response.data == null) {
        throw const GatewayException(
          code: GatewayErrorCode.upstreamError,
          isRetryable: true,
          messageFa: 'پاسخ استریم از سرور دریافت نشد.',
        );
      }
      return response;
    } on DioException catch (e) {
      String? bodyText;
      final data = e.response?.data;
      if (data is ResponseBody) {
        bodyText = await _readStreamText(data);
      }
      throw GatewayErrorMapper.fromDio(e, bodyOverride: bodyText);
    }
  }

  Future<String> _readStreamText(ResponseBody? body) async {
    if (body == null) return '';
    final bytes = <int>[];
    try {
      await for (final chunk in body.stream.timeout(const Duration(seconds: 5))) {
        bytes.addAll(chunk);
        if (bytes.length > 32 * 1024) break;
      }
    } catch (_) {
      // Ignore partial read failures when summarizing error text
    }
    return utf8.decode(Uint8List.fromList(bytes), allowMalformed: true);
  }
}
