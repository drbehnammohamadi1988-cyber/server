import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_ai/core/network/gateway_error.dart';
import 'package:orbi_ai/core/utils/thinking_parser.dart';
import 'package:orbi_ai/features/gateway/data/gateway_repository.dart';
import 'package:orbi_ai/features/gateway/domain/gateway_models.dart';

void main() {
  group('GatewayRepository parsing & error mapping', () {
    test('parses GatewayModel capability inference from /v1/models items', () {
      final m1 = GatewayModel.fromJson({'id': 'gpt-4o-mini', 'object': 'model'});
      final m2 = GatewayModel.fromJson({
        'id': 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
        'object': 'model',
      });
      final m3 = GatewayModel.fromJson({'id': 'o4-mini', 'object': 'model'});

      expect(m1.displayName, 'gpt-4o-mini');
      expect(m1.supportsVision, isTrue);
      expect(m1.isFast, isTrue);

      expect(m2.displayName, 'Llama-3.3-70B-Instruct-Turbo');
      expect(m2.isCoding, isTrue);

      expect(m3.supportsReasoning, isTrue);

      final mLive = GatewayModel.fromJson({
        'id': 'gpt-6-luna',
        'object': 'model',
        'name': 'GPT-6 Luna',
        'owned_by': 'OpenAI',
        'capabilities': {'vision': true, 'reasoning': true},
      });
      expect(mLive.displayName, 'GPT-6 Luna');
      expect(mLive.supportsVision, isTrue);
      expect(mLive.supportsReasoning, isTrue);
      expect(mLive.isFast, isTrue);
    });

    test('parses streaming SSE JSON payloads including delta, reasoning, usage, and [DONE]', () {
      final contentChunk = GatewayRepository.parseSsePayload(
        '{"choices":[{"delta":{"content":"سلام"}}]}',
      );
      expect(contentChunk, isNotNull);
      expect(contentChunk!.contentDelta, 'سلام');
      expect(contentChunk.isDone, isFalse);

      final reasoningChunk = GatewayRepository.parseSsePayload(
        '{"choices":[{"delta":{"reasoning_content":"تحلیل اولیه"}}]}',
      );
      expect(reasoningChunk!.reasoningDelta, 'تحلیل اولیه');

      final usageChunk = GatewayRepository.parseSsePayload(
        '{"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":34}}',
      );
      expect(usageChunk!.promptTokens, 12);
      expect(usageChunk.completionTokens, 34);

      final doneChunk = GatewayRepository.parseSsePayload('[DONE]');
      expect(doneChunk!.isDone, isTrue);
    });

    test('throws GatewayException on inline SSE error chunk', () {
      expect(
        () => GatewayRepository.parseSsePayload(
          '{"error":{"message":"upstream rate limited"}}',
        ),
        throwsA(isA<GatewayException>()),
      );
    });

    test('maps plain-text and JSON gateway HTTP errors cleanly', () {
      final e400 = GatewayErrorMapper.fromHttpStatus(
        statusCode: 400,
        rawBody: 'messages array must not be empty',
      );
      expect(e400.code, GatewayErrorCode.invalidArgument);
      expect(e400.messageFa, contains('messages array must not be empty'));

      final e401 = GatewayErrorMapper.fromHttpStatus(
        statusCode: 401,
        rawBody: '{"error":{"message":"invalid API key"}}',
      );
      expect(e401.code, GatewayErrorCode.unauthenticated);
      expect(e401.isRetryable, isFalse);

      final e429 = GatewayErrorMapper.fromHttpStatus(
        statusCode: 429,
        retryAfterHeader: '15',
      );
      expect(e429.code, GatewayErrorCode.rateLimited);
      expect(e429.retryAfter, const Duration(seconds: 15));
      expect(e429.isRetryable, isTrue);

      final e502 = GatewayErrorMapper.fromHttpStatus(
        statusCode: 502,
        rawBody: 'provider error: webchat.chat: upstream_error',
      );
      expect(e502.code, GatewayErrorCode.upstreamError);
      expect(e502.isRetryable, isTrue);

      final cancelled = GatewayErrorMapper.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          type: DioExceptionType.cancel,
        ),
      );
      expect(cancelled.isCancelled, isTrue);
    });
  });

  group('ThinkingParser', () {
    test('extracts open and closed <think> tags cleanly', () {
      final streamingOpen = ThinkingParser.parse('<think>در حال بررسی مرحله اول');
      expect(streamingOpen.isThinkingOpen, isTrue);
      expect(streamingOpen.thinkingContent, 'در حال بررسی مرحله اول');
      expect(streamingOpen.visibleContent, isEmpty);

      final completed = ThinkingParser.parse(
        '<think>استدلال گام به گام</think>\n\nپاسخ نهایی به فارسی',
      );
      expect(completed.isThinkingOpen, isFalse);
      expect(completed.thinkingContent, 'استدلال گام به گام');
      expect(completed.visibleContent, 'پاسخ نهایی به فارسی');
    });
  });
}
