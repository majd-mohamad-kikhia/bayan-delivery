import 'merchants_strings.dart';

final class MerchantsStringsEn extends MerchantsStrings {
  const MerchantsStringsEn();

  // ── Keeta shops panel ──────────────────────────────────────────────────
  @override
  String get keetaShops => 'Keeta Shops';
  @override
  String get keetaShopsSubtitle => 'Branches · hours · emergency status';
  @override
  String get noAuthorizedShops => 'No authorized shops found';
  @override
  String get branch => 'Branch';
  @override
  String get branchStatus => 'Branch status';
  @override
  String get emergencyClose => 'Emergency Close';
  @override
  String get reopen => 'Reopen';
  @override
  String get businessHoursLocal => 'Business hours (local time)';
  @override
  String get loadingHours => 'Loading hours…';
  @override
  String shopFallbackName(int id) => 'Shop $id';

  // ── Shop availability ──────────────────────────────────────────────────
  @override
  String get available => 'AVAILABLE';
  @override
  String get unavailable => 'UNAVAILABLE';

  // ── Emergency status dialog ────────────────────────────────────────────
  @override
  String get confirmStatus => 'Confirm status';
  @override
  String get emergencyCloseTitle => 'Emergency Close?';
  @override
  String get reopenBranchTitle => 'Reopen Branch?';
  @override
  String emergencyCloseBody(String shopName) =>
      'Close "$shopName" immediately on Keeta. Use this only for unplanned closures — not for scheduled hours.';
  @override
  String reopenBranchBody(String shopName) =>
      'Set "$shopName" back to AVAILABLE on Keeta.';
  @override
  String get closeNow => 'Close Now';
  @override
  String get thisBranch => 'shop';

  // ── Business hours ─────────────────────────────────────────────────────
  @override
  String get noWeeklyHours => 'No weekly hours configured';
  @override
  String get closedAllDay => 'Closed';
  @override
  String get listSeparator => ', ';
  @override
  String get monday => 'Monday';
  @override
  String get tuesday => 'Tuesday';
  @override
  String get wednesday => 'Wednesday';
  @override
  String get thursday => 'Thursday';
  @override
  String get friday => 'Friday';
  @override
  String get saturday => 'Saturday';
  @override
  String get sunday => 'Sunday';

  // ── HungerStation outlet panel ─────────────────────────────────────────
  @override
  String get hsOutlet => 'HungerStation Outlet';
  @override
  String get hsOutletSubtitle => 'Open / close vendor status';
  @override
  String get updateStatus => 'Update status';
  @override
  String get reopenOpen => 'Reopen (OPEN)';
  @override
  String get closeForToday => 'Close for today';
  @override
  String get closeUntil => 'Close until…';
  @override
  String get closedReasonTitle => 'Closed reason';
  @override
  String get vendorStatus => 'Vendor status';
  @override
  String vendorIdLabel(String id) => 'Vendor: $id';
  @override
  String chainIdLabel(String id) => 'Chain: $id';
  @override
  String closedReasonLabel(String reason) => 'Reason: $reason';
  @override
  String closedUntilLabel(String until) => 'Until: $until';

  // ── HungerStation vendor statuses ──────────────────────────────────────
  @override
  String get statusOpen => 'OPEN';
  @override
  String get statusClosedToday => 'CLOSED TODAY';
  @override
  String get statusClosedUntil => 'CLOSED UNTIL';
  @override
  String get statusClosed => 'CLOSED';
  @override
  String get statusCheckin => 'CHECK-IN';

  // ── HungerStation closed reasons ───────────────────────────────────────
  @override
  String get reasonTooBusyNoDrivers => 'Too busy — no drivers';
  @override
  String get reasonTooBusyKitchen => 'Too busy — kitchen';
  @override
  String get reasonMenuUpdates => 'Menu updates';
  @override
  String get reasonTechnicalProblem => 'Technical problem';
  @override
  String get reasonClosed => 'Closed';
  @override
  String get reasonOther => 'Other';
  @override
  String get reasonBadWeather => 'Bad weather';
  @override
  String get reasonHoliday => 'Holiday / special day';
}
