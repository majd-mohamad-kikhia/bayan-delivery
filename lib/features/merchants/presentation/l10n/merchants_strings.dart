import 'package:flutter/widgets.dart';

import '../../../../core/localization/locale_context.dart';
import 'merchants_strings_ar.dart';
import 'merchants_strings_en.dart';

/// Text for the merchants feature (Keeta shops + HungerStation outlet).
abstract class MerchantsStrings {
  const MerchantsStrings();

  // ── Keeta shops panel ──────────────────────────────────────────────────
  String get keetaShops;
  String get keetaShopsSubtitle;
  String get noAuthorizedShops;
  String get branch;
  String get branchStatus;
  String get emergencyClose;
  String get reopen;
  String get businessHoursLocal;
  String get loadingHours;
  String shopFallbackName(int id);

  // ── Shop availability ──────────────────────────────────────────────────
  String get available;
  String get unavailable;

  // ── Emergency status dialog ────────────────────────────────────────────
  String get confirmStatus;
  String get emergencyCloseTitle;
  String get reopenBranchTitle;
  String emergencyCloseBody(String shopName);
  String reopenBranchBody(String shopName);
  String get closeNow;
  String get thisBranch;

  // ── Business hours ─────────────────────────────────────────────────────
  String get noWeeklyHours;
  String get closedAllDay;
  String get listSeparator;
  String get monday;
  String get tuesday;
  String get wednesday;
  String get thursday;
  String get friday;
  String get saturday;
  String get sunday;

  String weekday(String rawDay) => switch (rawDay.toUpperCase()) {
        'MONDAY' => monday,
        'TUESDAY' => tuesday,
        'WEDNESDAY' => wednesday,
        'THURSDAY' => thursday,
        'FRIDAY' => friday,
        'SATURDAY' => saturday,
        'SUNDAY' => sunday,
        _ => rawDay,
      };

  // ── HungerStation outlet panel ─────────────────────────────────────────
  String get hsOutlet;
  String get hsOutletSubtitle;
  String get updateStatus;
  String get reopenOpen;
  String get closeForToday;
  String get closeUntil;
  String get closedReasonTitle;
  String get closedReasonSubtitle;
  String get vendorStatus;
  String vendorIdLabel(String id);
  String chainIdLabel(String id);
  String closedReasonLabel(String reason);
  String closedUntilLabel(String until);

  // ── HungerStation close-until picker ───────────────────────────────────
  String get closeUntilTitle;
  String get closeUntilSubtitle;
  String get quickPicks;
  String get pickTime;
  String inMinutes(int minutes);
  String inHours(int hours);
  String get tomorrowMorning;
  String get periodMorning;
  String get periodAfternoon;
  String get periodEvening;
  String get periodNight;
  String reopensAt(String date, String time);
  String reopensIn(int days, int hours, int minutes);
  String get pickFutureTime;
  String get confirmClosure;

  // ── HungerStation vendor statuses ──────────────────────────────────────
  String get statusOpen;
  String get statusClosedToday;
  String get statusClosedUntil;
  String get statusClosed;
  String get statusCheckin;

  String vendorStatusLabel(String raw) => switch (raw.toUpperCase()) {
        'OPEN' => statusOpen,
        'CLOSED_TODAY' => statusClosedToday,
        'CLOSED_UNTIL' => statusClosedUntil,
        'CLOSED' => statusClosed,
        'CHECKIN' => statusCheckin,
        _ => raw,
      };

  // ── HungerStation closed reasons ───────────────────────────────────────
  String get reasonTooBusyNoDrivers;
  String get reasonTooBusyKitchen;
  String get reasonMenuUpdates;
  String get reasonTechnicalProblem;
  String get reasonClosed;
  String get reasonOther;
  String get reasonBadWeather;
  String get reasonHoliday;

  String closedReason(String raw) => switch (raw) {
        'TOO_BUSY_NO_DRIVERS' => reasonTooBusyNoDrivers,
        'TOO_BUSY_KITCHEN' => reasonTooBusyKitchen,
        'UPDATES_IN_MENU' => reasonMenuUpdates,
        'TECHNICAL_PROBLEM' => reasonTechnicalProblem,
        'CLOSED' => reasonClosed,
        'OTHER' => reasonOther,
        'BAD_WEATHER' => reasonBadWeather,
        'HOLIDAY_SPECIAL_DAY' => reasonHoliday,
        _ => raw,
      };
}

extension MerchantsStringsContext on BuildContext {
  MerchantsStrings get merchantsStrings =>
      isArabic ? const MerchantsStringsAr() : const MerchantsStringsEn();
}
