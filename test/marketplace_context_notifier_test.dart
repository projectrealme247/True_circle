import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/marketplace_context_notifier.dart';
import 'package:true_circle/services/replacement_workflow_service.dart';
import 'package:true_circle/services/user_session_store.dart';
import 'package:true_circle/utils/applicant_household.dart';
import 'package:true_circle/utils/full_rental_applicant_scorer.dart';
import 'package:true_circle/utils/numeric_bounds.dart';
import 'package:true_circle/utils/numeric_bounds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('MarketplaceContextNotifier', () {
    test('defaults to browsing workflow', () async {
      UserSessionStore.current = null;
      await marketplaceContextNotifier.refresh();
      expect(
        marketplaceContextNotifier.activeWorkflows,
        contains(MarketplaceWorkflow.browsing),
      );
    });

    test('lastActiveSpace is null until explicit gateway selection', () async {
      UserSessionStore.current = {
        'email': 'seeker@example.com',
        'preferred_property_type': 'Share',
      };
      await marketplaceContextNotifier.refresh();
      expect(marketplaceContextNotifier.lastActiveSpace, isNull);

      await marketplaceContextNotifier.setActiveSpace(
        MarketplaceSpace.sharedSpace,
      );
      expect(
        marketplaceContextNotifier.lastActiveSpace,
        MarketplaceSpace.sharedSpace,
      );
      expect(
        marketplaceContextNotifier.activeSpace,
        MarketplaceSpace.sharedSpace,
      );
    });
  });

  group('FullRentalApplicantScorer', () {
    test('clamps checklist score to 0-100', () {
      final score = FullRentalApplicantScorer.scoreApplicantGroup(
        household: ApplicantHousehold.fromMap({
          'net_monthly_income': 100000,
          'trust_tier': 'Grand',
          'employment_verified': true,
        }),
        listing: {
          'type': 'Rent',
          'listing_type': 'Rent',
          'price': '€1200/month',
        },
      );
      expect(score.finalScore, inInclusiveRange(0, 100));
      expect(score.finalScore, NumericBounds.clampPercentInt(score.finalScore));
    });
  });

  group('ReplacementWorkflowService', () {
    test('creates draft workflow with four steps', () async {
      final workflow = await ReplacementWorkflowService.startDraft(
        listingId: 'listing-test',
        session: {'supabase_user_id': 'tenant-1'},
      );
      expect(workflow.status, 'draft');
      expect(workflow.totalSteps, 4);
    });
  });
}
