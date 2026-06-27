import 'applicant_session_sync.dart';
import 'profile_data.dart';

class ApplicantHousehold {
  const ApplicantHousehold({
    required this.coApplicants,
    required this.commuteProfiles,
    this.hasGuarantor = false,
    this.hasHapVoucher = false,
    this.hapContribution = 0,
  });

  final List<Map<String, dynamic>> coApplicants;
  final List<Map<String, dynamic>> commuteProfiles;
  final bool hasGuarantor;
  final bool hasHapVoucher;
  final double hapContribution;

  double get pooledNetIncome {
    var total = 0.0;
    for (final applicant in coApplicants) {
      final raw = applicant['net_monthly_income'];
      total += raw is num
          ? raw.toDouble()
          : double.tryParse(ProfileData.text(raw)) ?? 0;
    }
    if (hasHapVoucher) total += hapContribution;
    return total;
  }

  factory ApplicantHousehold.fromMap(Map<String, dynamic> session) {
    final enriched = ApplicantSessionSync.enrich(session);
    final coApplicants = [
      for (final item in (enriched['co_applicants'] as List? ?? const []))
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    final commuteProfiles = [
      for (final item in (enriched['commute_profiles'] as List? ?? const []))
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    final hapRaw = session['hap_voucher_contribution'];
    return ApplicantHousehold(
      coApplicants: coApplicants,
      commuteProfiles: commuteProfiles,
      hasGuarantor: session['has_guarantor'] == true,
      hasHapVoucher: session['has_hap_voucher'] == true,
      hapContribution: hapRaw is num
          ? hapRaw.toDouble()
          : double.tryParse(ProfileData.text(hapRaw)) ?? 0,
    );
  }
}
