import 'dart:convert';

import 'keeta_types.dart';

/// A Keeta webhook push as forwarded by the backend.
///
/// The real payload is the `message` field — a JSON **string** — so it is
/// decoded a second time here; `orderViewId` lives inside it.
final class KeetaWebhook {
  const KeetaWebhook({
    required this.eventId,
    required this.message,
    this.messageId,
    this.shopId,
    this.appId,
    this.timestamp,
  });

  /// Returns null for Keeta's empty heartbeat packets.
  static KeetaWebhook? tryParse(Map<String, dynamic> json) {
    final eventId = json['eventId'];
    if (eventId is! num) return null;

    final rawMessage = json['message'];
    Map<String, dynamic> message = const {};
    if (rawMessage is Map<String, dynamic>) {
      message = rawMessage;
    } else if (rawMessage is String && rawMessage.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMessage);
        if (decoded is Map<String, dynamic>) message = decoded;
      } on FormatException {
        // Malformed inner message: keep the envelope, leave message empty.
      }
    }

    return KeetaWebhook(
      eventId: eventId.toInt(),
      message: message,
      messageId: json['messageId']?.toString(),
      shopId: (json['shopId'] as num?)?.toInt(),
      appId: (json['appId'] as num?)?.toInt(),
      timestamp: (json['timestamp'] as num?)?.toInt(),
    );
  }

  final int eventId;

  /// Decoded inner payload (`orderViewId`, `status`, `opTime`, …).
  final Map<String, dynamic> message;

  /// Unique per delivery — Keeta retries up to 3 times, so dedupe on this.
  final String? messageId;
  final int? shopId;
  final int? appId;

  /// Unix seconds.
  final int? timestamp;

  KeetaWebhookEvent? get event => KeetaWebhookEvent.fromId(eventId);

  int? get orderViewId => (message['orderViewId'] as num?)?.toInt();
}
