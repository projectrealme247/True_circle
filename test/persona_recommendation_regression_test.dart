import "package:flutter_test/flutter_test.dart";
import "package:true_circle/config/market/dublin_commuter_hubs.dart";
import "package:true_circle/data/market_listings_seed.dart";
import "package:true_circle/models/seeker_onboarding_enums.dart";
import "package:true_circle/services/commute_scoring_service.dart";
import "package:true_circle/utils/district_commute_snapshot.dart";
import "package:true_circle/utils/district_inventory_stats.dart";
import "package:true_circle/utils/district_recommendation_ranker.dart";
import "package:true_circle/utils/listing_data.dart";

void main() {
  test("persona regression suite identical commute inputs", () {
    final listings = ListingData.normalizeList(MarketListingsSeed.items);
    final inventory = DistrictInventorySnapshot.build(listings);
    final commute = DistrictCommuteSnapshot.build(
      destinationHub: DublinCommuterHubs.tcd,
      transportMode: CommuteMethod.publicTransportWalking,
      maxTravelMinutes: 60,
    );

    List<DistrictRecommendation> rankFor(SeekerPersona persona) {
      return DistrictRecommendationRanker.rank(
        request: DistrictRecommendationRequest(
          persona: persona,
          budgetMax: 1500,
          destinationHub: DublinCommuterHubs.tcd,
          transportMode: CommuteMethod.publicTransportWalking,
          maxTravelMinutes: 60,
        ),
        inventory: inventory,
        commute: commute,
      );
    }

    void dump(String label, List<DistrictRecommendation> ranked) {
      // ignore: avoid_print
      print("=== $label (n=${ranked.length}) ===");
      for (final r in ranked.take(5)) {
        // ignore: avoid_print
        print(
          "${r.districtKey}\t"
          "final=${r.finalScore.toStringAsFixed(2)}\t"
          "c=${r.commuteScore.toStringAsFixed(2)}\t"
          "a=${r.affordabilityScore.toStringAsFixed(2)}\t"
          "i=${r.inventoryScore.toStringAsFixed(2)}\t"
          "p=${r.personaScore.toStringAsFixed(2)}\t"
          "${r.estimatedMinutes}m",
        );
      }
    }

    final student = rankFor(SeekerPersona.student);
    final professional = rankFor(SeekerPersona.professional);
    final family = rankFor(SeekerPersona.family);

    dump("STUDENT", student);
    dump("PROFESSIONAL", professional);
    dump("FAMILY", family);

    List<String> keys(List<DistrictRecommendation> r) =>
        [for (final x in r.take(5)) x.districtKey];

    final sKeys = keys(student);
    final pKeys = keys(professional);
    final fKeys = keys(family);

    // ignore: avoid_print
    print("TOP5 student=$sKeys");
    // ignore: avoid_print
    print("TOP5 professional=$pKeys");
    // ignore: avoid_print
    print("TOP5 family=$fKeys");

    expect(sKeys, isNot(equals(pKeys)),
        reason: "Student top-5 must differ from Professional");
    expect(sKeys, isNot(equals(fKeys)),
        reason: "Student top-5 must differ from Family");
    expect(pKeys, isNot(equals(fKeys)),
        reason: "Professional top-5 must differ from Family");

    // Near-identical collapse: same order AND final scores within 0.5
    bool nearIdentical(
      List<DistrictRecommendation> a,
      List<DistrictRecommendation> b,
    ) {
      final n = a.length < 5 ? a.length : 5;
      if (b.length < n) return false;
      for (var i = 0; i < n; i++) {
        if (a[i].districtKey != b[i].districtKey) return false;
        if ((a[i].finalScore - b[i].finalScore).abs() > 0.5) return false;
      }
      return n > 0;
    }

    final collapseFlags = <String>[];
    if (nearIdentical(student, professional)) {
      collapseFlags.add("Student≈Professional");
    }
    if (nearIdentical(student, family)) {
      collapseFlags.add("Student≈Family");
    }
    if (nearIdentical(professional, family)) {
      collapseFlags.add("Professional≈Family");
    }
    // ignore: avoid_print
    print(collapseFlags.isEmpty
        ? "COLLAPSE: none"
        : "COLLAPSE: ${collapseFlags.join(", ")}");

    expect(collapseFlags, isEmpty);
  });
}
