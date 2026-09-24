import '../common/delivery_platform.dart';
import '../common/platform_api_exception.dart';
import '../common/platform_endpoint.dart';
import 'keeta_types.dart';

/// A successful Keeta envelope `{ code: 0, message, data, errorList }`.
///
/// Non-zero codes are thrown as [PlatformApiException] instead. A batch
/// call can still succeed with `message: "Partial Failure"` — check
/// [hasPartialFailure] after batch writes.
final class KeetaResponse {
  const KeetaResponse({
    this.message = '',
    this.data,
    this.errorList = const [],
  });

  factory KeetaResponse.fromRaw(Object? raw, PlatformEndpoint endpoint) {
    final code = raw is Map ? raw['code'] : null;
    if (raw is! Map || code is! num) {
      throw PlatformApiException(
        'Unexpected Keeta response for ${endpoint.id}',
        platform: DeliveryPlatform.keeta,
        kind: PlatformErrorKind.executor,
        endpointId: endpoint.id,
        details: raw,
      );
    }

    final message = raw['message']?.toString() ?? '';
    if (code != 0) {
      throw PlatformApiException(
        message.isEmpty ? 'Keeta error $code' : message,
        platform: DeliveryPlatform.keeta,
        kind: KeetaErrorCodes.kindOf(code.toInt()),
        endpointId: endpoint.id,
        code: code.toInt(),
        details: raw,
      );
    }

    final errors = raw['errorList'];
    return KeetaResponse(
      message: message,
      data: raw['data'],
      errorList: errors is List ? errors : const [],
    );
  }

  /// Combines the chunks of one batched call.
  factory KeetaResponse.merge(List<KeetaResponse> parts) {
    if (parts.isEmpty) return const KeetaResponse(message: 'Success', data: []);
    if (parts.length == 1) return parts.single;

    final data = <Object?>[];
    final errors = <Object?>[];
    for (final part in parts) {
      final chunk = part.data;
      if (chunk is List) {
        data.addAll(chunk);
      } else if (chunk != null) {
        data.add(chunk);
      }
      errors.addAll(part.errorList);
    }
    return KeetaResponse(
      message: errors.isEmpty ? 'Success' : 'Partial Failure',
      data: data,
      errorList: errors,
    );
  }

  final String message;
  final Object? data;
  final List<Object?> errorList;

  bool get hasPartialFailure => errorList.isNotEmpty;

  Map<String, dynamic> get dataMap {
    final value = data;
    return value is Map<String, dynamic> ? value : const {};
  }

  List<Map<String, dynamic>> get dataList {
    final value = data;
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }
}
