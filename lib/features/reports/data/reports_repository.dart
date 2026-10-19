import '../../../core/network/api_client.dart';
import 'report_models.dart';

/// One request per screen: the backend answers from small summary tables,
/// so there is nothing to page, combine or cache on this side.
class ReportsRepository {
  const ReportsRepository(this._api);

  final ApiClient _api;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<ReportOverview> overview({
    required String dongleNumber,
    required DateTime from,
    required DateTime to,
    String? platform,
  }) async {
    final data = await _api.get(
      '/api/reports/overview',
      query: {
        'dongleNumber': dongleNumber,
        'from': _day(from),
        'to': _day(to),
        'platform': ?platform,
      },
    );
    return ReportOverview.fromJson(data);
  }
}
