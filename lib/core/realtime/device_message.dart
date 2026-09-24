import '../platforms/keeta/keeta_webhook.dart';

/// One payload the backend queued for this device and handed over on
/// `GET /poll/{deviceId}`.
final class DeviceMessage {
  const DeviceMessage({
    required this.payload,
    required this.receivedAt,
    this.keeta,
  });

  /// Builds a message from the `data` field of a `200` poll response.
  /// Returns null for empty payloads (Keeta heartbeats forwarded as `{}`).
  static DeviceMessage? fromPollData(Object? data, DateTime receivedAt) {
    var payload = data;
    // Results forwarded by executeApiAndSendWebhook arrive as
    // `{ timestamp, result }`.
    if (payload is Map &&
        payload.length == 2 &&
        payload.containsKey('timestamp') &&
        payload.containsKey('result')) {
      payload = payload['result'];
    }
    if (payload == null || (payload is Map && payload.isEmpty)) return null;

    return DeviceMessage(
      payload: payload,
      receivedAt: receivedAt,
      keeta: payload is Map<String, dynamic> ? KeetaWebhook.tryParse(payload) : null,
    );
  }

  /// The queued data, as the backend sent it.
  final Object? payload;

  final DateTime receivedAt;

  /// Set when the payload is a Keeta webhook push (new order, cancel,
  /// refund, delivery update…).
  final KeetaWebhook? keeta;

  /// Identity for dropping redeliveries: Keeta retries a push up to 3 times.
  String? get dedupeKey {
    final id = keeta?.messageId;
    return id == null ? null : 'keeta:$id';
  }
}
