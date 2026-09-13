import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/listing_report.dart';
import 'package:true_circle/services/listing_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ListingReportService.clearForTests();
  });

  group('ListingReport model', () {
    test('round-trips required Phase 1 fields', () {
      final report = ListingReport(
        id: 'lr_1',
        listingId: 'dub-share-01',
        reporterId: 'user-1',
        reason: ListingReportReason.scamOrSuspicious,
        details: 'Looks fake',
        status: 'open',
        createdAt: DateTime.utc(2026, 8, 25, 12),
      );

      final map = report.toMap();
      expect(map['report_type'], 'listing');
      expect(map['listing_id'], 'dub-share-01');
      expect(map['reporter_id'], 'user-1');
      expect(map['reason'], 'scamOrSuspicious');
      expect(map['details'], 'Looks fake');
      expect(map['status'], 'open');
      expect(map['created_at'], isNotEmpty);

      final restored = ListingReport.fromMap(map);
      expect(restored.listingId, report.listingId);
      expect(restored.reason, ListingReportReason.scamOrSuspicious);
      expect(restored.status, 'open');
    });

    test('exposes all six report reasons', () {
      expect(ListingReportReason.values.map((e) => e.label), [
        'Scam or suspicious',
        'Already rented',
        'Duplicate listing',
        'Incorrect information',
        'Inappropriate content',
        'Other',
      ]);
    });
  });

  group('ListingReportService', () {
    test('persists open listing reports for admin queue', () async {
      final report = await ListingReportService.submitListingReport(
        listingId: 'listing-42',
        reason: ListingReportReason.alreadyRented,
        details: 'Host confirmed',
        session: {'supabase_user_id': 'seeker-9'},
      );

      expect(report.reportType, 'listing');
      expect(report.status, 'open');
      expect(report.reporterId, 'seeker-9');

      final open = await ListingReportService.loadOpen();
      expect(open, hasLength(1));
      expect(open.first.listingId, 'listing-42');
      expect(open.first.reason, ListingReportReason.alreadyRented);
    });

    test('uses anonymous reporter when session is missing', () async {
      final report = await ListingReportService.submitListingReport(
        listingId: 'listing-7',
        reason: ListingReportReason.other,
      );
      expect(report.reporterId, 'anonymous');
    });
  });
}
