import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/listings_storage_service.dart';
import '../services/trust_service.dart';
import '../utils/listing_data.dart';
import '../utils/viewer_profile.dart';
import '../utils/listing_media.dart';
import '../widgets/listing_cover_image.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoad) return;
    _startedLoad = true;
    _resolveListing();
  }

  Future<void> _resolveListing() async {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      if (!mounted) return;
      setState(() {
        _listing = ListingData.normalizeItem(extra);
        _loading = false;
      });
      return;
    }

    final stored = await ListingsStorageService.getById(widget.listingId);
    if (!mounted) return;
    setState(() {
      _listing = stored;
      _loading = false;
      _notFound = stored == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userSession = AuthScreen.currentUserSession;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text(
          'Listing details',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            )
          : _notFound
              ? _buildNotFound()
              : _buildContent(_listing!, userSession),
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
              style: FilledButton.styleFrom(backgroundColor: Color(0xFF0EA5E9)),
              child: const Text('Back to marketplace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> item, Map<String, dynamic>? userSession) {
    final title = ListingData.title(item);
    final price = ListingData.price(item);
    final location = ListingData.location(item);
    final propertyType = ListingData.propertyType(item);
    final description = ListingData.description(item);
    final hostName = ListingData.hostName(item);
    final hostCity = ListingData.hostCity(item);
    final hostLanguage = ListingData.hostLanguage(item);
    final images = ListingData.imageDataUris(item);
    final hasVideo = ListingData.videoDataUri(item) != null;
    final occupant = ListingData.occupantType(item);
    final occupantSub = ListingData.occupantSubPreferenceDetail(item);
    final openLang = ListingData.openToSameLanguage(item);
    final lifestyle = ListingData.lifestylePreferences(item);

    final match = ListingData.compareWithProfile(item, userSession);

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListingCoverImage(
                listing: item,
                height: 180,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
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
                    Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF0EA5E9)),
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
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE4E6EB)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1E21),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF42B72A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Hosted by',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hostName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1E21),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _detailRow('Host city', hostCity.isEmpty ? 'Not provided' : hostCity),
                      _detailRow(
                        'Languages',
                        hostLanguage.isEmpty ? 'Not provided' : hostLanguage,
                      ),
                      _detailRow('Location', location.isEmpty ? 'Not provided' : location),
                      _detailRow('Property type', propertyType),
                      if (occupant.isNotEmpty)
                        _detailRow('Occupant type', occupant),
                      if (occupant == 'Bachelors' && occupantSub.isNotEmpty)
                        _detailRow('Preferred occupants', occupantSub),
                      if (occupant == 'Students' && occupantSub.isNotEmpty)
                        _detailRow('Student background', occupantSub),
                      if (openLang.isNotEmpty)
                        _detailRow('Open to same language', openLang),
                      if (lifestyle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Lifestyle',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: lifestyle
                              .map(
                                (label) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description.isEmpty ? 'No description provided.' : description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFF1C1E21),
                        ),
                      ),
                      if (userSession != null) ...[
                        const SizedBox(height: 16),
                        if (match.hasAny)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (match.sameLocality)
                                _matchChip('Same city', Colors.blue),
                              if (match.sameMotherTongue)
                                _matchChip('Same language', Colors.orange),
                              if (match.dietMatch)
                                _matchChip('Same food preference', Colors.green),
                            ],
                          )
                        else
                          const Text(
                            'No profile matches for this listing yet.',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionButtons(item, userSession),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> item, Map<String, dynamic>? userSession) {
    final isSignedIn = userSession != null;
    final canContact = TrustService.canContact();
    final stage = TrustService.currentStage();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E6EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Interested in this property?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1E21),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: isSignedIn
                    ? () => _handleContactHost(canContact, stage)
                    : () => _promptSignIn(),
                style: FilledButton.styleFrom(
                  backgroundColor: canContact
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  canContact ? Icons.chat_rounded : Icons.shield_outlined,
                  size: 20,
                ),
                label: Text(
                  canContact ? 'Contact Host' : 'Verify to Contact Host',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (isSignedIn && !canContact) ...[
              const SizedBox(height: 8),
              Text(
                'ID verification (Stage 3) required to contact hosts. '
                'You are currently at ${stage.label}.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: isSignedIn
                    ? () => _showScheduleViewing(item)
                    : () => _promptSignIn(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF97316),
                  side: const BorderSide(color: Color(0xFFF97316)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 20),
                label: const Text(
                  'Schedule a Viewing',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
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

  void _promptSignIn() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Please sign in to proceed.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF0EA5E9),
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

  void _handleContactHost(bool canContact, TrustStage stage) {
    if (canContact) {
      _showContactConfirmation();
      return;
    }
    final nextVerification = stage.level < 2 ? '/verify/social' : '/verify/id';
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
            const Icon(Icons.verified_user_rounded, size: 48, color: Color(0xFF0EA5E9)),
            const SizedBox(height: 16),
            const Text(
              'Verification required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'To protect both tenants and hosts, CircleKey requires '
              'ID verification before you can contact a host.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(nextVerification);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  stage.level < 2 ? 'Start Social Verification' : 'Start ID Verification',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

  Widget _matchChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF1C1E21),
              ),
            ),
          ),
        ],
      ),
    );
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

  List<DateTime> get _availableDates {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return List.generate(14, (i) => tomorrow.add(Duration(days: i)));
  }

  String _dayLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[date.month - 1];
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
                const Icon(Icons.calendar_month_rounded, size: 24, color: Color(0xFFF97316)),
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
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableDates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = _availableDates[index];
                  final isSelected = _selectedDate != null &&
                      _selectedDate!.day == date.day &&
                      _selectedDate!.month == date.month;
                  final isWeekend = date.weekday >= 6;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF97316)
                            : isWeekend
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFF97316)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dayLabel(date),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : const Color(0xFF1C1E21),
                            ),
                          ),
                          Text(
                            _monthLabel(date),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
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
                          ? const Color(0xFF0EA5E9)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0EA5E9)
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
                  borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
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
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  disabledBackgroundColor: const Color(0xFFF97316).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Request Viewing',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
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
