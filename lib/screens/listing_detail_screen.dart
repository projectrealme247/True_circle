import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/listings_storage_service.dart';
import '../services/trust_service.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';
import '../utils/trust_status_copy.dart';
import '../utils/viewer_profile.dart';
import '../utils/listing_media.dart';
import '../models/marketplace_space.dart';
import '../services/listing_applications_service.dart';
import '../services/marketplace_context_notifier.dart';
import '../services/replacement_workflow_service.dart';
import '../utils/shared_space_compatibility_scorer.dart';
import '../utils/applicant_household.dart';
import '../utils/full_rental_applicant_scorer.dart';
import '../utils/numeric_bounds.dart';
import '../widgets/jit_verification_bottom_sheet.dart';
import '../widgets/listing_action_bar.dart';
import '../widgets/listing_detail_page_layout.dart';
import '../widgets/listing_detail_tokens.dart';
import 'auth_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  bool _notFound = false;
  bool _startedLoad = false;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    authSessionNotifier.addListener(_onAuthSessionChanged);
  }

  @override
  void dispose() {
    authSessionNotifier.removeListener(_onAuthSessionChanged);
    super.dispose();
  }

  void _onAuthSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoad) return;
    _startedLoad = true;
    _resolveListing();
  }

  Future<void> _resolveListing() async {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map) {
      if (!mounted) return;
      setState(() {
        _listing = ListingData.normalizeItem(Map<String, dynamic>.from(extra));
        _loading = false;
      });
      return;
    }

    final stored = await ListingsStorageService.getById(widget.listingId);
    if (!mounted) return;
    final session = AuthScreen.currentUserSession;
    var hasApplied = false;
    if (stored != null && session != null) {
      hasApplied = await ListingApplicationsService.hasApplied(
        listingId: widget.listingId,
        applicantUserId: session['supabase_user_id']?.toString() ?? '',
      );
    }
    if (!mounted) return;
    setState(() {
      _listing = stored;
      _loading = false;
      _notFound = stored == null;
      _hasApplied = hasApplied;
    });
  }

  MarketplaceSpace get _listingSpace {
    final listing = _listing;
    if (listing == null) return MarketplaceSpace.fullRental;
    return MarketplaceSpace.fromTowerPropertyType(
      ListingData.propertyType(listing),
    );
  }

  Future<void> _handleApply(Map<String, dynamic> item) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) {
      _promptSignIn();
      return;
    }
    if (!TrustService.canContact()) {
      _handleContactHost(
        canContact: false,
        stage: TrustService.currentStage(),
        cohort: ViewerProfile.seekerCohortFromSession(session),
      );
      return;
    }

    final isShare = _listingSpace == MarketplaceSpace.sharedSpace;
    final score = isShare
        ? SharedSpaceCompatibilityScorer.calculateCompatibility(
            seekerSession: session,
            listing: item,
          )
        : FullRentalApplicantScorer.scoreApplicantGroup(
            household: ApplicantHousehold.fromMap(session),
            listing: item,
          ).finalScore;

    await ListingApplicationsService.submit(
      listingId: widget.listingId,
      session: session,
      space: _listingSpace,
      compatibilityScore: NumericBounds.clampPercentInt(score),
    );
    if (!mounted) return;
    setState(() => _hasApplied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application submitted')),
    );
  }

  Future<void> _handleStartReplacement(Map<String, dynamic> item) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) {
      _promptSignIn();
      return;
    }
    final workflow = await ReplacementWorkflowService.startDraft(
      listingId: widget.listingId,
      session: session,
    );
    await marketplaceContextNotifier.refresh();
    if (!mounted) return;
    context.push('/replacement/${workflow.id}');
  }

  @override
  Widget build(BuildContext context) {
    final userSession = AuthScreen.currentUserSession;

    return Scaffold(
      backgroundColor: ListingDetailTokens.canvas,
      appBar: AppBar(
        backgroundColor: ListingDetailTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ListingDetailTokens.charcoal),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text(
          'Listing details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: ListingDetailTokens.charcoal,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _notFound
              ? _buildNotFound()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildUnifiedLayout(
                      item: _listing!,
                      userSession: userSession,
                      viewportWidth: constraints.maxWidth,
                    );
                  },
                ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF8D949E)),
            const SizedBox(height: 16),
            const Text(
              'Listing not found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              style: AppButtonStyles.primaryFilled,
              child: const Text('Back to marketplace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedLayout({
    required Map<String, dynamic> item,
    required Map<String, dynamic>? userSession,
    required double viewportWidth,
  }) {
    return ListingDetailPageLayout(
      item: item,
      userSession: userSession,
      space: _listingSpace,
      hasApplied: _hasApplied,
      isOwned: ListingActionBar.isOwnedListing(item, userSession),
      displayPrice: ListingDetailCopy.displayPrice(item),
      displayTitle: ListingDetailCopy.displayTitle(item),
      formatHighlightLabel: ListingDetailCopy.highlightLabel,
      depositLabel: ListingData.securityDepositLabel(item),
      mediaExtras: _buildMediaExtras(
        ListingData.imageDataUris(item),
        ListingData.videoDataUri(item) != null,
      ),
      matchChips: _buildMatchChips(item, userSession),
      onPitch: () => _handlePitch(item),
      onRequestViewing: () => _showScheduleViewing(item),
      onManage: () => context.push('/listing/${widget.listingId}/manage'),
      onStartReplacement: () => _handleStartReplacement(item),
    );
  }

  void _handlePitch(Map<String, dynamic> item) {
    if (AuthScreen.currentUserSession == null) {
      _showSignInBottomSheet();
      return;
    }
    _handleApply(item);
  }

  List<Widget> _buildMatchChips(
    Map<String, dynamic> item,
    Map<String, dynamic>? userSession,
  ) {
    if (userSession == null) return [];
    final match = ListingData.compareWithProfile(item, userSession);
    if (!match.hasAny) return [];
    return [
      if (match.sameLocality) _matchChip('Same city'),
      if (match.sameMotherTongue) _matchChip('Same language'),
      if (match.dietMatch) _matchChip('Same food preference'),
    ];
  }


  List<Widget> _buildMediaExtras(List<String> images, bool hasVideo) {
    return [
      if (images.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final bytes = ListingMedia.decodeDataUri(images[index]);
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFFE5E7EB)),
                ),
              );
            },
          ),
        ),
      ],
      if (hasVideo) ...[
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.videocam_outlined, size: 18, color: AppColors.accent),
            SizedBox(width: 6),
            Text(
              'Video attached by host',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  void _showSignInBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_outline, size: 44, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Sign in to pitch your story',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ListingDetailTokens.charcoal,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hosts respond to complete profiles with a personal introduction.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/profile/edit');
                },
                style: AppButtonStyles.primaryFilled,
                child: const Text('Continue to sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptSignIn() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Please sign in to proceed.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Sign in',
            textColor: Colors.white,
            onPressed: () => context.go('/profile/edit'),
          ),
        ),
      );
  }

  String _contactGateMessage(TrustStage stage, {required SeekerCohort cohort}) {
    if (TrustStatusCopy.usesLegacyCasualLabel(stage)) {
      return TrustStatusCopy.justLandedBrowsing;
    }

    if (cohort == SeekerCohort.workingProfessional) {
      if (stage.level < TrustStage.socialVerified.level) {
        return 'Verify employment with LinkedIn or upload a corporate letter '
            'to contact hosts.';
      }
      return 'You are verified at ${stage.label}.';
    }
    if (cohort == SeekerCohort.arrivingFamily) {
      if (stage.level < TrustStage.socialVerified.level) {
        return 'Confirm rental budget capability to contact hosts.';
      }
      return 'You are verified at ${stage.label}.';
    }

    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;
    if (lightTrust) {
      if (stage.level < TrustStage.socialVerified.level) {
        return 'Social verification is required before you can contact hosts. '
            '${TrustStatusCopy.justLandedBrowsing}';
      }
      return 'Contact requires university email verification (Track A) or '
          'pre-arrival invite + offer letter (Track B).';
    }
    return 'ID verification is required to contact hosts. '
        'Complete verification to connect with premium hosts instantly.';
  }

  void _handleContactHost({
    required bool canContact,
    required TrustStage stage,
    required SeekerCohort cohort,
  }) {
    if (canContact) {
      _showContactConfirmation();
      return;
    }

    if (cohort.needsJitSocialGate &&
        stage.level < TrustStage.socialVerified.level) {
      JitVerificationBottomSheet.show(
        context,
        cohort: cohort,
        onVerified: () {
          if (!mounted) return;
          setState(() {});
          if (TrustService.canContact()) {
            _showContactConfirmation();
          }
        },
      );
      return;
    }

    if (cohort == SeekerCohort.student) {
      _showStudentContactGate(stage);
      return;
    }

    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;

    String nextVerification;
    String ctaLabel;
    String body;

    if (stage.level < TrustStage.socialVerified.level) {
      nextVerification = '/verify/social';
      ctaLabel = 'Start Social Verification';
      body = lightTrust
          ? 'Complete Stage 2 social verification first, then choose '
              'university email or pre-arrival contact verification.'
          : 'To protect both tenants and hosts, TrueCircle requires '
              'social verification before ID verification.';
    } else if (lightTrust) {
      nextVerification = '/verify/id';
      ctaLabel = 'Choose verification path';
      body = 'You can verify with your college email (Community Verified) '
          'or as a pre-arrival student with an invite code and offer letter.';
    } else {
      nextVerification = '/verify/id';
      ctaLabel = 'Start ID Verification';
      body = 'To protect both tenants and hosts, TrueCircle requires '
          'ID verification before you can contact a host.';
    }

    _showLegacyVerificationSheet(
      body: body,
      ctaLabel: ctaLabel,
      nextVerification: nextVerification,
      lightTrust: lightTrust,
      stage: stage,
    );
  }

  void _showStudentContactGate(TrustStage stage) {
    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;

    late final String body;
    late final String ctaLabel;
    late final String nextVerification;

    if (stage.level < TrustStage.socialVerified.level) {
      nextVerification = '/verify/social';
      ctaLabel = 'Start Social Verification';
      body = lightTrust
          ? 'Complete Stage 2 social verification first, then choose '
              'university email or pre-arrival contact verification.'
          : 'To protect both tenants and hosts, TrueCircle requires '
              'social verification before ID verification.';
    } else if (lightTrust) {
      nextVerification = '/verify/id';
      ctaLabel = 'Choose verification path';
      body = 'You can verify with your college email (Community Verified) '
          'or as a pre-arrival student with an invite code and offer letter.';
    } else {
      nextVerification = '/verify/id';
      ctaLabel = 'Start ID Verification';
      body = 'To protect both tenants and hosts, TrueCircle requires '
          'ID verification before you can contact a host.';
    }

    _showLegacyVerificationSheet(
      body: body,
      ctaLabel: ctaLabel,
      nextVerification: nextVerification,
      lightTrust: lightTrust,
      stage: stage,
    );
  }

  void _showLegacyVerificationSheet({
    required String body,
    required String ctaLabel,
    required String nextVerification,
    required bool lightTrust,
    required TrustStage stage,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_rounded, size: 48, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Verification required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
            ),
            if (lightTrust && stage.level >= TrustStage.socialVerified.level) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/verify/pre-arrival');
                  },
                  child: const Text('Pre-arrival: invite + letter'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/verify/id/university-email');
                  },
                  child: const Text('I have a college email'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(nextVerification);
                },
                style: AppButtonStyles.primaryFilled,
                child: Text(
                  ctaLabel,
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactConfirmation() {
    final hostName = ListingData.hostName(_listing!);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Contact request sent to $hostName. They will be notified.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF42B72A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _showScheduleViewing(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ScheduleViewingSheet(
        listing: item,
        onBooked: (date, timeSlot, note) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Viewing requested for ${_formatDate(date)} at $timeSlot.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                backgroundColor: const Color(0xFF42B72A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  Widget _matchChip(String label) {
    const accent = AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class ListingDetailCopy {
  ListingDetailCopy._();

  /// Segment-aware title for detail hero (e.g. "1 Bed · Dublin 4 · Sea Proximity").
  static String displayTitle(Map<String, dynamic> listing) {
    final raw = ListingData.title(listing).trim();
    if (raw.isEmpty) return raw;
    return raw
        .split(RegExp(r'\s*·\s*'))
        .where((part) => part.isNotEmpty)
        .map(highlightLabel)
        .join(' · ');
  }

  /// Uniform title case for highlight matrix labels (preserves short acronyms like RTB).
  static String highlightLabel(String value) {
    if (value.trim().isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(_titleCaseToken)
        .join(' ');
  }

  static String _titleCaseToken(String word) {
    if (word.isEmpty) return word;
    if (RegExp(r'^[A-Z]{2,5}$').hasMatch(word)) return word;
    if (RegExp(r'^\d+$').hasMatch(word)) return word;
    final lower = word.toLowerCase();
    const acronyms = {'rtb', 'dart', 'luas', 'ucd', 'bhk'};
    if (acronyms.contains(lower)) return lower.toUpperCase();
    if (word.length == 1) return word.toUpperCase();
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }

  static String displayPrice(Map<String, dynamic> listing) {
    final raw = ListingData.price(listing);
    if (raw == 'Price on request') return raw;

    final amount = ListingData.listingPriceAmount(listing);
    final symbol = MarketConfig.current.currencySymbol;
    final periodMatch = RegExp(r'/(\w+)$').firstMatch(raw);
    final period = periodMatch != null ? '/${periodMatch.group(1)!}' : '';

    if (amount != null) {
      return '$symbol${_formatAmount(amount)}$period';
    }

    final trimmed = raw.trim();
    if (trimmed.startsWith(symbol) || trimmed.startsWith('₹')) return trimmed;
    return '$symbol$trimmed';
  }

  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Bottom sheet for scheduling a property viewing appointment.
class _ScheduleViewingSheet extends StatefulWidget {
  const _ScheduleViewingSheet({
    required this.listing,
    required this.onBooked,
  });

  final Map<String, dynamic> listing;
  final void Function(DateTime date, String timeSlot, String note) onBooked;

  @override
  State<_ScheduleViewingSheet> createState() => _ScheduleViewingSheetState();
}

class _ScheduleViewingSheetState extends State<_ScheduleViewingSheet> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final _noteController = TextEditingController();
  late DateTime _focusedMonth;

  static const _weekdayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  static const _timeSlots = [
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
    '6:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    final first = _firstBookable;
    _focusedMonth = DateTime(first.year, first.month);
  }

  DateTime get _firstBookable {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  DateTime get _lastBookable => _firstBookable.add(const Duration(days: 13));

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isBookable(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final first = DateTime(
      _firstBookable.year,
      _firstBookable.month,
      _firstBookable.day,
    );
    final last = DateTime(
      _lastBookable.year,
      _lastBookable.month,
      _lastBookable.day,
    );
    return !day.isBefore(first) && !day.isAfter(last);
  }

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  String _monthYearLabel(DateTime month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  bool get _canGoPrevMonth {
    final prevMonthEnd = DateTime(_focusedMonth.year, _focusedMonth.month, 0);
    final first = DateTime(
      _firstBookable.year,
      _firstBookable.month,
      _firstBookable.day,
    );
    return !prevMonthEnd.isBefore(first);
  }

  bool get _canGoNextMonth {
    final nextMonthStart = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    final last = DateTime(
      _lastBookable.year,
      _lastBookable.month,
      _lastBookable.day,
    );
    return !nextMonthStart.isAfter(last);
  }

  Widget _buildCalendarGrid() {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7;
    final daysInMonth = _daysInMonth(_focusedMonth);
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _canGoPrevMonth ? () => _shiftMonth(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 22),
              color: const Color(0xFF6B7280),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                _monthYearLabel(_focusedMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1E21),
                ),
              ),
            ),
            IconButton(
              onPressed: _canGoNextMonth ? () => _shiftMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 22),
              color: const Color(0xFF6B7280),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in _weekdayHeaders)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 40,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) {
              return const SizedBox.shrink();
            }

            final day = index - leadingBlanks + 1;
            if (day > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
            final bookable = _isBookable(date);
            final isSelected =
                _selectedDate != null && _isSameDay(_selectedDate!, date);

            return Center(
              child: GestureDetector(
                onTap: bookable
                    ? () => setState(() => _selectedDate = date)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? HomeMarketplaceTheme.primary
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : bookable
                              ? const Color(0xFF1C1E21)
                              : const Color(0xFFD1D5DB),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostName = ListingData.hostName(widget.listing);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 24, color: HomeMarketplaceTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Schedule a viewing${hostName.isNotEmpty ? ' with $hostName' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1E21),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Pick a date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            _buildCalendarGrid(),
            const SizedBox(height: 20),
            const Text(
              'Pick a time',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((slot) {
                final isSelected = _selectedTimeSlot == slot;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTimeSlot = slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      slot,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add a note (optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. I will bring my family along',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _selectedDate != null && _selectedTimeSlot != null
                    ? () => widget.onBooked(
                          _selectedDate!,
                          _selectedTimeSlot!,
                          _noteController.text.trim(),
                        )
                    : null,
                style: AppButtonStyles.primaryFilled,
                child: Text(
                  'Request Viewing',
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
