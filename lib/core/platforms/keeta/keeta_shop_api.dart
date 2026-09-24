import '../common/platform_utils.dart';
import 'keeta_client.dart';
import 'keeta_endpoints.dart';
import 'keeta_response.dart';
import 'keeta_types.dart';

/// Keeta Store API: profile, contact, business hours, open/suspend.
///
/// Orders are only accepted when status is 3 (operating) **and** the time
/// is inside business hours.
class KeetaShopApi {
  const KeetaShopApi(this._client);

  final KeetaClient _client;

  static final RegExp _imageUrl = RegExp(
    r'^https?://\S+\.(?:jpe?g|png|webp)$',
    caseSensitive: false,
  );
  static final RegExp _phone = RegExp(r'^\d{1,4}-\d{4,15}$');

  /// Name, images, address + lat/lng, categories, phones, status, hours.
  Future<Map<String, dynamic>> details(int shopId) async => (await _client.send(
    KeetaEndpoints.shopDetails,
    params: {'shopId': shopId},
  )).dataMap;

  /// Min 900×900px, max 5MB. Goes through manual review (not instant);
  /// rejected while a previous image is still pending review.
  Future<KeetaResponse> updateProfileImage({
    required int shopId,
    required String pictureUrl,
  }) {
    checkArgument(
      _imageUrl.hasMatch(pictureUrl),
      'pictureUrl',
      'must be an http(s) URL ending in .jpg, .jpeg, .png or .webp',
      pictureUrl,
    );
    return _client.send(
      KeetaEndpoints.updateShopPicture,
      params: {'shopId': shopId, 'pictureUrl': pictureUrl},
    );
  }

  /// 1–3 numbers formatted `countryCode-number`, e.g. `966-501234567`.
  Future<KeetaResponse> updateContactPhones({
    required int shopId,
    required List<String> phones,
  }) {
    checkArgument(
      phones.isNotEmpty && phones.length <= 3,
      'phones',
      'must contain 1 to 3 numbers',
      phones,
    );
    for (final phone in phones) {
      checkArgument(
        _phone.hasMatch(phone),
        'phones',
        'must look like 966-501234567',
        phone,
      );
    }
    return _client.send(
      KeetaEndpoints.updateShopContact,
      params: {'shopId': shopId, 'phones': phones},
    );
  }

  Future<Object?> businessHours(int shopId) async => (await _client.send(
    KeetaEndpoints.businessHours,
    params: {'shopId': shopId},
  )).data;

  /// Replaces the weekly schedule. Use [KeetaTimeRange.closed] for a
  /// closed day; ranges within a day must not overlap.
  Future<KeetaResponse> updateBusinessHours({
    required int shopId,
    required Map<KeetaWeekday, List<KeetaTimeRange>> week,
  }) {
    week.forEach(_checkNoOverlap);
    return _client.send(
      KeetaEndpoints.updateBusinessHours,
      params: {
        'shopId': shopId,
        'businessHourOfTheWeek': {
          for (final day in KeetaWeekday.values)
            if (week[day] case final ranges?)
              day.name: [for (final range in ranges) range.toJson()],
        },
      },
    );
  }

  Future<Object?> specialBusinessHours(int shopId) async => (await _client.send(
    KeetaEndpoints.specialBusinessHours,
    params: {'shopId': shopId},
  )).data;

  /// Holiday / event hours; they override the weekly schedule on those dates.
  Future<KeetaResponse> updateSpecialBusinessHours({
    required int shopId,
    required List<KeetaSpecialHours> days,
  }) {
    for (final day in days) {
      checkArgument(
        !day.endDate.isBefore(day.startDate),
        'days',
        'endDate is before startDate',
      );
      _checkNoOverlap(null, day.hours);
    }
    return _client.send(
      KeetaEndpoints.updateSpecialBusinessHours,
      params: {
        'shopId': shopId,
        'specialBusinessHour': [for (final day in days) day.toJson()],
      },
    );
  }

  /// Status → 4: hidden, orders blocked immediately until [reactivate].
  Future<KeetaResponse> suspend(int shopId) =>
      _client.send(KeetaEndpoints.suspendShop, params: {'shopId': shopId});

  /// Status → 3: visible and accepting orders again (within hours).
  Future<KeetaResponse> reactivate(int shopId) =>
      _client.send(KeetaEndpoints.reactivateShop, params: {'shopId': shopId});

  static void _checkNoOverlap(KeetaWeekday? day, List<KeetaTimeRange> ranges) {
    final open = ranges.where((range) => !range.isClosed).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    for (var i = 1; i < open.length; i++) {
      checkArgument(
        open[i].startTime >= open[i - 1].endTime,
        'week',
        '${day?.name ?? 'special hours'}: time ranges overlap',
      );
    }
  }
}
