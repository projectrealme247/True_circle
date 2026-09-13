import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/listings_storage_service.dart';
import '../services/trust_service.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';
import '../utils/listing_match_engine.dart';
import '../utils/viewer_profile.dart';
import '../models/applicant_field_keys.dart';
import '../models/marketplace_space.dart';
import '../services/listing_applications_service.dart';
import '../services/listing_contact_service.dart';
import '../services/marketplace_context_notifier.dart';
import '../services/replacement_workflow_service.dart';
import '../services/application_conversation_service.dart';
import '../services/application_service.dart';
import '../utils/seeker_application_pipeline.dart';
import '../utils/shared_space_compatibility_scorer.dart';
import '../utils/applicant_household.dart';
import '../utils/full_rental_applicant_scorer.dart';
import '../utils/numeric_bounds.dart';
import '../widgets/jit_verification_bottom_sheet.dart';
import '../widgets/listing_action_bar.dart';
import '../widgets/listing_detail/pitch_your_story_sheet.dart';
import '../widgets/listing_detail_page_layout.dart';
import '../widgets/listing_detail_tokens.dart';
import '../widgets/report_listing_bottom_sheet.dart';
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
  /// Non-null when the current seeker already applied to this listing.
  String? _applicationStateLabel;

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
    if (!mounted) return;
    _refreshApplicationState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoad) return;
    _startedLoad = true;
    _resolveListing();
  }

  Future<void> _refreshApplicationState() async {
    final session = AuthScreen.currentUserSession;
    if (session == null) {
      if (mounted) setState(() => _applicationStateLabel = null);
      return;
    }
    await applicationService.ensureLoaded();
    await applicationConversationService.ensureLoaded();
    if (!mounted) return;
    final label = SeekerApplicationPipeline.listingDetailStateLabel(
      listingId: widget.listingId,
      userId: AuthService.identityUserId(session),
    );
    if (!mounted) return;
    setState(() => _applicationStateLabel = label);
  }

  Future<void> _resolveListing() async {
    final extra = GoRouter.of(context).state.extra;
    if (extra is Map) {
      if (!mounted) return;
      setState(() {
        _listing = ListingData.normalizeItem(Map<String, dynamic>.from(extra));
        _loading = false;
      });
      await _refreshApplicationState();
      return;
    }

    final stored = await ListingsStorageService.getById(widget.listingId);
    if (!mounted) return;
    setState(() {
      _listing = stored;
      _loading = false;
      _notFound = stored == null;
    });
    await _refreshApplicationState();
  }

  MarketplaceSpace get _listingSpace {
    final listing = _listing;
    if (listing == null) return MarketplaceSpace.fullRental;
    return MarketplaceSpace.fromTowerPropertyType(
      ListingData.propertyType(listing),
    );
  }

  Future<void> _submitApplication(
    Map<String, dynamic> item, {
    required String personalNote,
  }) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) {
      _promptSignIn();
      return;
    }
    if (!TrustService.canContact()) {
      _handleContactHost(
        canContact: false,
        cohort: ViewerProfile.seekerCohortFromSession(session),
        listing: item,
      );
      return;
    }

    final enrichedSession = Map<String, dynamic>.from(session)
      ..[ApplicantFieldKeys.personalIntroduction] = personalNote;

    final isShare = _listingSpace == MarketplaceSpace.sharedSpace;
    final score = isShare
        ? SharedSpaceCompatibilityScorer.calculateCompatibility(
            seekerSession: enrichedSession,
            listing: item,
          )
        : FullRentalApplicantScorer.scoreApplicantGroup(
            household: ApplicantHousehold.fromMap(enrichedSession),
            listing: item,
          ).finalScore;

    await ListingApplicationsService.submit(
      listingId: widget.listingId,
      session: enrichedSession,
      space: _listingSpace,
      compatibilityScore: NumericBounds.clampPercentInt(score),
    );
    await ListingContactService.notifyHost(
      listing: item,
      applicantSession: enrichedSession,
      compatibilityScore: NumericBounds.clampPercentInt(score),
    );
    if (!mounted) return;
    await _refreshApplicationState();
    if (!mounted) return;
    final hostName = ListingData.hostName(item);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Application sent — $hostName will be notified.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF42B72A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _handleApply(Map<String, dynamic> item) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) {
      _promptSignIn();
      return;
    }
    await _submitApplication(item, personalNote: '');
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
        actions: [
          if (!_loading && !_notFound && _listing != null)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: ListingDetailTokens.charcoal,
              ),
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'report') {
                  ReportListingBottomSheet.show(
                    context,
                    listingId: ListingData.id(_listing!),
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'report',
                  child: Text('Report Listing'),
                ),
              ],
            ),
        ],
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
      hasApplied: _applicationStateLabel != null,
      applicationStateLabel: _applicationStateLabel,
      isOwned: ListingActionBar.isOwnedListing(item, userSession),
      displayPrice: ListingDetailCopy.displayPrice(item),
      displayTitle: ListingDetailCopy.displayTitle(item),
      formatHighlightLabel: ListingDetailCopy.highlightLabel,
      listedOnLabel: ListingData.listedOnDisplayLabel(item),
      depositLabel: ListingData.securityDepositLabel(item),
      mediaExtras: _buildMediaExtras(
        ListingData.imageDataUris(item),
        ListingData.videoDataUri(item) != null,
      ),
      matchChips: const [],
      preferenceFitLabels: _preferenceFitLabels(item, userSession),
      onPitch: () => _handlePitch(item),
      onManage: () => context.push('/listing/${widget.listingId}/manage'),
      onStartReplacement: () => _handleStartReplacement(item),
      onEdit: () => context.push('/add-listing', extra: item),
    );
  }

  void _handlePitch(Map<String, dynamic> item) {
    if (_applicationStateLabel != null) return;
    final session = AuthScreen.currentUserSession;
    if (session == null) {
      _showSignInBottomSheet();
      return;
    }
    if (!TrustService.canContact()) {
      _handleContactHost(
        canContact: false,
        cohort: ViewerProfile.seekerCohortFromSession(session),
        listing: item,
      );
      return;
    }

    PitchYourStorySheet.show(
      context,
      hostName: ListingData.hostName(item),
      space: _listingSpace,
      session: session,
      onSubmit: (note) => _submitApplication(item, personalNote: note),
    );
  }

  List<String> _preferenceFitLabels(
    Map<String, dynamic> item,
    Map<String, dynamic>? userSession,
  ) {
    if (userSession == null) return const [];
    final viewer = ViewerProfile.fromSession(userSession);

    if (_listingSpace == MarketplaceSpace.fullRental) {
      return ListingMatchEngine.independentPlacePreferenceExplanations(
        item,
        viewer,
        viewerSession: userSession,
        maxReasons: 3,
      );
    }

    if (_listingSpace == MarketplaceSpace.sharedSpace) {
      return ListingMatchEngine.sharedLivingPreferenceExplanations(
        item,
        viewer,
        viewerSession: userSession,
        maxReasons: 3,
      );
    }

    return const [];
  }


  List<Widget> _buildMediaExtras(List<String> images, bool hasVideo) {
    return [
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

  void _handleContactHost({
    required bool canContact,
    required SeekerCohort cohort,
    Map<String, dynamic>? listing,
  }) {
    if (canContact && listing != null) {
      _handleApply(listing);
      return;
    }

    // Professionals / families: LinkedIn OR employment methods → JIT sheet.
    if (cohort.needsJitSocialGate) {
      JitVerificationBottomSheet.show(
        context,
        cohort: cohort,
        onVerified: () {
          if (!mounted) return;
          setState(() {});
          final item = _listing;
          if (TrustService.canContact() && item != null) {
            _handleApply(item);
          }
        },
      );
      return;
    }

    // Students: university email OR pre-arrival declaration (not LinkedIn).
    _showStudentContactGate();
  }

  void _showStudentContactGate() {
    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;

    _showLegacyVerificationSheet(
      body: lightTrust
          ? 'Choose how you want to verify so you can contact this host.'
          : 'To protect both tenants and hosts, TrueCircle requires '
              'verification before you can contact a host.',
      ctaLabel: 'Start verification',
      nextVerification: '/verify/id',
      showStudentPathChoices: lightTrust,
    );
  }

  void _showLegacyVerificationSheet({
    required String body,
    required String ctaLabel,
    required String nextVerification,
    required bool showStudentPathChoices,
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
            if (showStudentPathChoices) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/verify/id/university-email');
                  },
                  style: AppButtonStyles.primaryFilled,
                  child: const Text('I have a university email'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/verify/pre-arrival');
                  },
                  child: const Text("I don't have a university email yet"),
                ),
              ),
            ] else ...[
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
          ],
        ),
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
        onBooked: (date, timeSlot, note) async {
          Navigator.pop(ctx);
          final session = AuthScreen.currentUserSession;
          if (session != null) {
            await ListingContactService.notifyHost(
              listing: item,
              applicantSession: session,
              compatibilityScore: 0,
              kind: ListingContactEvent.viewingRequest,
              viewingSlot: '${_formatDate(date)} at $timeSlot',
              viewingNote: note,
            );
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Viewing requested for ${_formatDate(date)} at $timeSlot — host notified.',
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

  /// Uniform title case for highlight matrix labels (preserves short transit acronyms).
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
    const acronyms = {'dart', 'luas', 'ucd', 'bhk', 'ber'};
    if (acronyms.contains(lower)) return lower.toUpperCase();
    if (word.length == 1) return word.toUpperCase();
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }

  static String displayPrice(Map<String, dynamic> listing) {
    final label = ListingData.priceDisplayLabel(listing);
    if (label == 'Rent not set') return label;

    final raw = ListingData.price(listing);
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
