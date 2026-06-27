import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../services/listings_storage_service.dart';
import '../services/profile_storage_service.dart';
import '../services/trust_service.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import '../utils/viewer_profile.dart';
import '../widgets/gamified_form_wizard.dart';
import '../widgets/listing_media_picker.dart';
import 'auth_screen.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  static const _pageCount = 2;
  static const _dublinCenterLat = 53.349805;
  static const _dublinCenterLon = -6.26031;
  static const _dublinFallbackLabel = 'Dublin, Ireland';

  static const _bedroomOptions = ['1', '2', '3', '4', '5+'];
  static const _bathroomOptions = ['1', '2', '3+'];

  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _type;
  bool _saving = false;
  bool _locationFromProfile = false;
  bool _fetchingLocation = false;

  List<String> _images = [];
  String? _video;
  String? _occupantType;
  String? _bachelorPreference;
  String? _studentType;
  bool _prioritizeLanguageCombinations = false;
  final Set<String> _lifestylePreferences = {};
  String? _preferredTenantOccupant;
  String? _preferredTenantFood;
  bool _smokingAllowed = false;
  bool _drinkingAllowed = false;
  bool _quietHours = false;
  String? _scheduleType;

  String? _bedrooms;
  String? _bathrooms;
  String? _furnishing;
  String? _roomType;
  int _currentOccupants = 0;

  List<String> get _enabledPropertyTypes => MarketConfig.current.enabledTowers;

  @override
  void initState() {
    super.initState();
    _type = _enabledPropertyTypes.first;
    _locationController.text = MarketConfig.current.defaultProfileLocation;
    _prefillLocationFromProfile();
  }

  Future<void> _prefillLocationFromProfile() async {
    final session = AuthScreen.currentUserSession;
    final profile = session ?? await ProfileStorageService.load();
    if (!mounted) return;
    if (profile == null) return;

    final city = ProfileData.text(profile['detected_city']);
    final area = ProfileData.text(profile['current_area']);
    final candidate = area.isNotEmpty ? area : city;
    if (candidate.isEmpty || !candidate.toLowerCase().contains('dublin')) {
      return;
    }

    if (_locationController.text.trim().isEmpty ||
        _locationController.text == MarketConfig.current.defaultProfileLocation) {
      _locationController.text = candidate;
      setState(() => _locationFromProfile = true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pageCount) return;
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  bool _validatePage1() {
    final title = _titleController.text.trim();
    final price = _priceController.text.trim();
    final location = _locationController.text.trim();

    if (title.length < 3) {
      _showMessage('Enter a title (at least 3 characters).');
      return false;
    }
    if (price.isEmpty) {
      _showMessage('Enter a price (e.g. €1,200 / month).');
      return false;
    }
    if (!RegExp(r'^\d+').hasMatch(price) && !price.startsWith('€')) {
      _showMessage('Price should start with a number or €.');
      return false;
    }
    if (location.length < 2) {
      _showMessage('Enter a Dublin area or district.');
      return false;
    }
    if (_type.isEmpty) {
      _showMessage('Select a property type.');
      return false;
    }
    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      _showMessage('Add a description (at least 10 characters).');
      return false;
    }
    return true;
  }

  bool _validatePage2() {
    if (!_validatePage1()) return false;

    final description = _descriptionController.text.trim();
    final errors = ListingData.validateListingForm(
      title: _titleController.text.trim(),
      price: _priceController.text.trim(),
      location: _locationController.text.trim(),
      type: _type,
      description: description,
    );
    if (errors.isNotEmpty) {
      _showMessage(errors.values.first);
      return false;
    }
    return true;
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _priceController.clear();
    _descriptionController.clear();
    setState(() {
      _type = _enabledPropertyTypes.first;
      _currentPage = 0;
      _images = [];
      _video = null;
      _occupantType = null;
      _bachelorPreference = null;
      _studentType = null;
      _prioritizeLanguageCombinations = false;
      _lifestylePreferences.clear();
      _preferredTenantOccupant = null;
      _preferredTenantFood = null;
      _smokingAllowed = false;
      _drinkingAllowed = false;
      _quietHours = false;
      _scheduleType = null;
      _bedrooms = null;
      _bathrooms = null;
      _furnishing = null;
      _roomType = null;
      _currentOccupants = 0;
      _locationController.text = MarketConfig.current.defaultProfileLocation;
      _locationFromProfile = false;
    });
    _pageController.jumpToPage(0);
  }

  bool _isWithinDublinBounds(double lat, double lon) =>
      lat >= 53.20 && lat <= 53.45 && lon >= -6.50 && lon <= -6.00;

  Future<String> _resolveDublinLabel(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        for (final part in [p.locality, p.subLocality, p.administrativeArea]) {
          if (part != null &&
              part.trim().isNotEmpty &&
              !parts.contains(part.trim())) {
            parts.add(part.trim());
          }
        }
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Fall through to static Dublin label.
    }
    return _dublinFallbackLabel;
  }

  Future<void> _applyDublinFallback({String? reason}) async {
    final label = await _resolveDublinLabel(_dublinCenterLat, _dublinCenterLon);
    if (!mounted) return;
    setState(() {
      _locationFromProfile = false;
      _locationController.text = label;
    });
    if (reason != null) {
      _showMessage(reason);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_fetchingLocation || _saving) return;
    setState(() => _fetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _applyDublinFallback(
          reason: 'Location services are off — pinned to Dublin city centre.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _applyDublinFallback(
          reason: 'Location permission denied — using Dublin city centre.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!_isWithinDublinBounds(position.latitude, position.longitude)) {
        await _applyDublinFallback(
          reason:
              'Your location is outside Dublin — we pinned the listing to Dublin city centre.',
        );
        return;
      }

      final label = await _resolveDublinLabel(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _locationFromProfile = false;
        _locationController.text = label;
      });
    } catch (_) {
      await _applyDublinFallback(
        reason: 'Could not read GPS — using Dublin city centre instead.',
      );
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _onPublishPressed() async {
    if (_saving) return;
    if (!_validatePage2()) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _showMaximizeMatchPotentialDialog();
  }

  Future<void> _showMaximizeMatchPotentialDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Maximize Your Match Potential (Optional)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222222),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add photos or a short video so high-signal applicants '
                      'recognise your space instantly. You can skip and publish now.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListingMediaPicker(
                      images: _images,
                      video: _video,
                      enabled: !_saving,
                      onMessage: _showMessage,
                      onImagesChanged: (next) => setState(() => _images = next),
                      onVideoChanged: (v) => setState(() => _video = v),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              Navigator.pop(dialogContext);
                              await _save();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Publish listing',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              Navigator.pop(dialogContext);
                              await _save();
                            },
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validatePage2()) return;

    setState(() => _saving = true);

    try {
      final profile =
          AuthScreen.currentUserSession ?? await ProfileStorageService.load();
      final host = ListingData.hostFieldsFromProfile(profile);

      final title = _titleController.text.trim();
      final price = _priceController.text.trim();
      final location = _locationController.text.trim();
      final description = _descriptionController.text.trim();

      final payload = <String, dynamic>{
        'title': title,
        'price': price,
        'location': location,
        'type': _type,
        'description': description,
        'hostName': host['hostName']!,
        'hostCity': host['hostCity']!.isNotEmpty
            ? host['hostCity']!
            : 'Dublin',
        'hostLanguage': host['hostLanguage']!,
        'hostMotherTongue': host['hostMotherTongue']!,
        'hostFoodPreference': host['hostFoodPreference']!,
        'market': MarketConfig.current.id.name,
        if (profile != null)
          'spoken_languages':
              ProfileData.languageList(profile['spoken_languages']),
        if (_images.isNotEmpty) 'images': _images,
        if (_video != null) 'video': _video,
        if (_occupantType != null) 'occupantType': _occupantType,
        if (_occupantType == 'Bachelors' && _bachelorPreference != null)
          'bachelorPreference': _bachelorPreference,
        if (_occupantType == 'Students' && _studentType != null)
          'studentType': _studentType,
        if (_prioritizeLanguageCombinations)
          'openToSameLanguage': 'Yes',
        if (_lifestylePreferences.isNotEmpty)
          'lifestylePreferences': _lifestylePreferences.toList(),
        if (_preferredTenantOccupant != null)
          'preferred_tenant_occupant': _preferredTenantOccupant,
        if (_preferredTenantFood != null)
          'preferred_tenant_food': _preferredTenantFood,
        'smoking_allowed': _smokingAllowed,
        'drinking_allowed': _drinkingAllowed,
        'quiet_hours': _quietHours,
        if (_scheduleType != null) 'schedule_type': _scheduleType,
        if (_bedrooms != null) 'bedrooms': _bedrooms,
        if (_bathrooms != null) 'bathrooms': _bathrooms,
        if (_furnishing != null) 'furnishing': _furnishing,
        if (_roomType != null) 'room_type': _roomType,
        if (_currentOccupants > 0) 'current_occupants': _currentOccupants,
        'latitude': _dublinCenterLat,
        'longitude': _dublinCenterLon,
      };

      final stamped = TrustService.stampListingTrust(payload);
      final saved = await ListingsStorageService.addListing(stamped);

      if (!mounted) return;

      _clearForm();

      final stage = TrustService.currentStage();
      if (stage.level < TrustStage.idVerified.level) {
        await _showUpgradeNudge(stage);
        if (!mounted) return;
      }

      context.go(
        '/?refresh=${saved['id']}',
        extra: {'listingAdded': saved},
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not save listing. Try again.');
      setState(() => _saving = false);
    }
  }

  Future<void> _showUpgradeNudge(TrustStage current) async {
    final isCasual = current == TrustStage.casual;
    final boostPct = isCasual ? '29%' : '11%';
    final nextLabel = isCasual ? 'Verified Pro' : 'ID Verified';
    final nextRoute = isCasual ? '/verify/social' : '/verify/id';
    final nextIcon = isCasual
        ? Icons.workspace_premium_rounded
        : Icons.verified_user_rounded;
    final nextColor = isCasual
        ? const Color(0xFF7C3AED)
        : const Color(0xFF16A34A);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 40),
            const SizedBox(height: 12),
            const Text(
              'Your listing is live!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1E21),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upgrade to $nextLabel to rank $boostPct higher',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF606770),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(nextRoute);
                },
                icon: Icon(nextIcon, size: 20),
                label: Text('Upgrade to $nextLabel'),
                style: FilledButton.styleFrom(
                  backgroundColor: nextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Maybe later',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _saving ? null : () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text(
          'Add Listing',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF222222),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GamifiedFormProgress(current: _currentPage, total: 2),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: _pageHeight(context),
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          children: [
                            _buildPage1(),
                            _buildPage2(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildNavBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _pageHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return (screenH * 0.62).clamp(420.0, 720.0);
  }

  Widget _buildNavBar() {
    return GamifiedFormNavBar(
      enabled: !_saving,
      isSubmitting: _saving,
      showBack: _currentPage > 0,
      showNext: _currentPage == 0,
      showSubmit: _currentPage == 1,
      nextLabel: 'Enable Smart-Matching Engine →',
      submitLabel: 'Publish listing',
      onBack: () => _goToPage(_currentPage - 1),
      onNext: () {
        if (_validatePage1()) _goToPage(1);
      },
      onSubmit: _onPublishPressed,
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GamifiedFormPageHeader(
            title: 'The Bare Minimum',
            subtitle:
                'Title, price, Dublin location, room setup, and a short description.',
          ),
          const SizedBox(height: 24),
          _field(
            controller: _titleController,
            label: 'Title',
            hint: 'Bright double room near Luas',
            validator: (v) {
              if ((v ?? '').trim().length < 3) {
                return 'Enter a title (at least 3 characters).';
              }
              return null;
            },
          ),
          _field(
            controller: _priceController,
            label: 'Price',
            hint: '€1,200 / month',
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'Enter a price (e.g. €1,200 / month).';
              if (!RegExp(r'^(\d+|€)').hasMatch(text)) {
                return 'Price should start with a number or €.';
              }
              return null;
            },
          ),
          _locationSection(),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Property type',
              border: OutlineInputBorder(),
            ),
            items: _enabledPropertyTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _type = v ?? _type),
            validator: (v) =>
                v == null || v.isEmpty ? 'Select a property type.' : null,
          ),
          const SizedBox(height: 14),
          _towerSpecificFields(),
          _field(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Short details about the property in Dublin',
            maxLines: 4,
            validator: (v) {
              if ((v ?? '').trim().length < 10) {
                return 'Add a description (at least 10 characters).';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GamifiedFormPageHeader(
            title: 'Enable Smart-Matching Engine',
            subtitle:
                'Let TrueCircle rank and bubble up high-signal applicants automatically.',
          ),
          const SizedBox(height: 24),
          _coreMatchFieldsSection(),
        ],
      ),
    );
  }

  Widget _towerSpecificFields() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: switch (_type) {
        'Share' => _shareFields(),
        _ => _rentFields(),
      },
    );
  }

  Widget _rentFields() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Property details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bedrooms,
                      decoration: InputDecoration(
                        labelText: 'Bedrooms',
                        hintText: 'Select bedrooms',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _bedroomOptions
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged:
                          _saving ? null : (v) => setState(() => _bedrooms = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bathrooms,
                      decoration: InputDecoration(
                        labelText: 'Bathrooms',
                        hintText: 'Select bathrooms',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _bathroomOptions
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged:
                          _saving ? null : (v) => setState(() => _bathrooms = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _furnishing,
                decoration: InputDecoration(
                  labelText: 'Furnishing',
                  hintText: 'Select furnishing',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: ListingData.furnishingOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _furnishing = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareFields() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Space details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _roomType,
                decoration: InputDecoration(
                  labelText: 'Room type',
                  hintText: 'Select room type',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: ListingData.roomTypeOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _roomType = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Current occupants', style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  IconButton(
                    onPressed: _saving || _currentOccupants <= 0
                        ? null
                        : () => setState(() => _currentOccupants--),
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                  ),
                  Text(
                    '$_currentOccupants',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving || _currentOccupants >= 6
                        ? null
                        : () => setState(() => _currentOccupants++),
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _locationController,
            enabled: !_saving,
            onChanged: (_) {
              if (_locationFromProfile) {
                setState(() => _locationFromProfile = false);
              }
            },
            validator: (v) {
              if ((v ?? '').trim().length < 2) {
                return 'Enter a Dublin area or district.';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Dublin 8 (Portobello)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (_locationFromProfile && _locationController.text.trim().isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 2),
              child: Text(
                'Auto-filled from your Dublin profile',
                style: TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving || _fetchingLocation ? null : _useCurrentLocation,
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined, size: 18),
              label: Text(
                _fetchingLocation ? 'Detecting…' : 'Use current location',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coreMatchFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ideal Match Preference',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 16),
        _occupantPreferencesSection(),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SwitchListTile(
            title: const Text(
              'Prioritize Spoken Language Combinations?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
            subtitle: const Text(
              'Matches applicants sharing overlapping combinations of your household languages.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            value: _prioritizeLanguageCombinations,
            onChanged: _saving
                ? null
                : (v) => setState(() => _prioritizeLanguageCombinations = v),
            activeThumbColor: AppColors.accent,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Lifestyle preferences',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ListingData.lifestyleOptions.map((option) {
            final selected = _lifestylePreferences.contains(option);
            return FilterChip(
              label: Text(option),
              selected: selected,
              onSelected: _saving
                  ? null
                  : (on) {
                      setState(() {
                        if (on) {
                          _lifestylePreferences.add(option);
                        } else {
                          _lifestylePreferences.remove(option);
                        }
                      });
                    },
              selectedColor: AppColors.accentLight,
              checkmarkColor: AppColors.accent,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.accent : const Color(0xFF4B5563),
              ),
              side: BorderSide(
                color: selected ? AppColors.accent : const Color(0xFFE5E7EB),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _occupantPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _optionalRadioGroup(
          groupValue: _occupantType,
          options: ListingData.occupantTypes,
          onChanged: (value) {
            setState(() {
              _occupantType = value;
              if (value != 'Bachelors') _bachelorPreference = null;
              if (value != 'Students') _studentType = null;
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _occupantType == 'Bachelors'
              ? _conditionalPreferenceBlock(
                  title: 'Preferred occupants',
                  groupValue: _bachelorPreference,
                  options: ListingData.bachelorPreferences,
                  onChanged: (v) => setState(() => _bachelorPreference = v),
                )
              : const SizedBox(width: double.infinity),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _occupantType == 'Students'
              ? _conditionalPreferenceBlock(
                  title: 'Student background',
                  groupValue: _studentType,
                  options: ListingData.studentTypes,
                  onChanged: (v) => setState(() => _studentType = v),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _conditionalPreferenceBlock({
    required String title,
    required String? groupValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1E21),
                  ),
                ),
              ),
              _optionalRadioGroup(
                groupValue: groupValue,
                options: options,
                onChanged: onChanged,
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionalRadioGroup({
    required String? groupValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool dense = false,
  }) {
    return Column(
      children: [
        RadioListTile<String?>(
          title: const Text('Not specified'),
          value: null,
          groupValue: groupValue,
          dense: dense,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.accent,
          onChanged: _saving ? null : onChanged,
        ),
        ...options.map(
          (option) => RadioListTile<String?>(
            title: Text(option),
            value: option,
            groupValue: groupValue,
            dense: dense,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.accent,
            onChanged: _saving ? null : onChanged,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        enabled: !_saving,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
