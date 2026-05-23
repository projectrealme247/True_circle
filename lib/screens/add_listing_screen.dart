import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../services/listings_storage_service.dart';
import '../services/profile_storage_service.dart';
import '../services/trust_service.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import '../utils/viewer_profile.dart';
import '../widgets/listing_media_picker.dart';
import 'auth_screen.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = ListingData.propertyTypes.first;
  bool _saving = false;
  bool _locationFromProfile = false;
  bool _fetchingLocation = false;

  List<String> _images = [];
  String? _video;
  String? _occupantType;
  String? _bachelorPreference;
  String? _studentType;
  String? _openToSameLanguage;
  final Set<String> _lifestylePreferences = {};
  String? _preferredTenantOccupant;
  String? _preferredTenantFood;
  bool _smokingAllowed = false;
  bool _drinkingAllowed = false;
  bool _quietHours = false;
  String? _scheduleType;

  // Tower-specific fields
  String? _bhk;
  String? _furnishing;
  String? _propertyCategory;
  String? _possessionStatus;
  String? _roomType;
  int _currentOccupants = 0;

  @override
  void initState() {
    super.initState();
    _prefillLocationFromProfile();
  }

  Future<void> _prefillLocationFromProfile() async {
    final session = AuthScreen.currentUserSession;
    final profile = session ?? await ProfileStorageService.load();
    if (!mounted) return;
    if (profile == null) return;

    final city = ProfileData.text(profile['detected_city']);
    if (city.isEmpty) return;

    if (_locationController.text.trim().isEmpty) {
      _locationController.text = city;
      setState(() => _locationFromProfile = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _priceController.clear();
    _descriptionController.clear();
    setState(() {
      _type = ListingData.propertyTypes.first;
      _images = [];
      _video = null;
      _occupantType = null;
      _bachelorPreference = null;
      _studentType = null;
      _openToSameLanguage = null;
      _lifestylePreferences.clear();
      _preferredTenantOccupant = null;
      _preferredTenantFood = null;
      _smokingAllowed = false;
      _drinkingAllowed = false;
      _quietHours = false;
      _scheduleType = null;
      _bhk = null;
      _furnishing = null;
      _propertyCategory = null;
      _possessionStatus = null;
      _roomType = null;
      _currentOccupants = 0;
    });
    _prefillLocationFromProfile();
  }

  Future<void> _useCurrentLocation() async {
    if (_fetchingLocation || _saving) return;
    setState(() => _fetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Turn on location services to use this.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      final parts = <String>[];
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        for (final part in [p.locality, p.subAdministrativeArea, p.administrativeArea]) {
          if (part != null && part.trim().isNotEmpty && !parts.contains(part.trim())) {
            parts.add(part.trim());
          }
        }
      }

      setState(() {
        _locationFromProfile = false;
        _locationController.text = parts.isNotEmpty
            ? parts.join(', ')
            : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      _showMessage('Could not detect your location. Try again.');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleController.text.trim();
    final price = _priceController.text.trim();
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();

    final errors = ListingData.validateListingForm(
      title: title,
      price: price,
      location: location,
      type: _type,
      description: description,
    );

    if (errors.isNotEmpty) {
      _showMessage(errors.values.first);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final profile =
          AuthScreen.currentUserSession ?? await ProfileStorageService.load();
      final host = ListingData.hostFieldsFromProfile(profile);

      final payload = <String, dynamic>{
        'title': title,
        'price': price,
        'location': location,
        'type': _type,
        'description': description,
        'hostName': host['hostName']!,
        'hostCity': host['hostCity']!,
        'hostLanguage': host['hostLanguage']!,
        'hostMotherTongue': host['hostMotherTongue']!,
        'hostFoodPreference': host['hostFoodPreference']!,
        if (profile != null)
          'spoken_languages': ProfileData.languageList(profile['spoken_languages']),
        if (_images.isNotEmpty) 'images': _images,
        if (_video != null) 'video': _video,
        if (_occupantType != null) 'occupantType': _occupantType,
        if (_occupantType == 'Bachelors' && _bachelorPreference != null)
          'bachelorPreference': _bachelorPreference,
        if (_occupantType == 'Students' && _studentType != null)
          'studentType': _studentType,
        if (_openToSameLanguage != null) 'openToSameLanguage': _openToSameLanguage,
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
        if (_bhk != null) 'bhk': _bhk,
        if (_furnishing != null) 'furnishing': _furnishing,
        if (_propertyCategory != null) 'property_category': _propertyCategory,
        if (_possessionStatus != null) 'possession_status': _possessionStatus,
        if (_roomType != null) 'room_type': _roomType,
        if (_currentOccupants > 0) 'current_occupants': _currentOccupants,
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
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _saving ? null : () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text(
          'Add Listing',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'List your property',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1E21),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Only title, price, location, type, and description are required.',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ListingMediaPicker(
                        images: _images,
                        video: _video,
                        enabled: !_saving,
                        onMessage: _showMessage,
                        onImagesChanged: (next) => setState(() => _images = next),
                        onVideoChanged: (v) => setState(() => _video = v),
                      ),
                      const SizedBox(height: 20),
                      _field(
                        controller: _titleController,
                        label: 'Title',
                        hint: 'Cozy studio near metro',
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
                        hint: '2500/day',
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return 'Enter a price (e.g. 2500/day).';
                          if (!RegExp(r'^\d+').hasMatch(text)) {
                            return 'Price should start with a number.';
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
                        items: ListingData.propertyTypes
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
                        hint: 'Short details about the property',
                        maxLines: 4,
                        validator: (v) {
                          if ((v ?? '').trim().length < 10) {
                            return 'Add a description (at least 10 characters).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _trustSignalsSection(),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save listing',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                      ),
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

  Widget _towerSpecificFields() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: switch (_type) {
        'Rent' => _rentFields(),
        'Buy' => _buyFields(),
        'Share' => _shareFields(),
        _ => const SizedBox(width: double.infinity),
      },
    );
  }

  Widget _rentFields() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _bhk,
                decoration: InputDecoration(
                  labelText: 'BHK',
                  hintText: 'Select BHK',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ListingData.bhkOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _bhk = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _furnishing,
                decoration: InputDecoration(
                  labelText: 'Furnishing',
                  hintText: 'Select furnishing',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buyFields() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _propertyCategory,
                decoration: InputDecoration(
                  labelText: 'Property category',
                  hintText: 'Select category',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ListingData.propertyCategoryOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _propertyCategory = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _possessionStatus,
                decoration: InputDecoration(
                  labelText: 'Possession status',
                  hintText: 'Select status',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ListingData.possessionStatusOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _possessionStatus = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareFields() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _roomType,
                decoration: InputDecoration(
                  labelText: 'Room type',
                  hintText: 'Select room type',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              if ((v ?? '').trim().length < 2) return 'Enter a location.';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Hyderabad, Telangana',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_locationFromProfile && _locationController.text.trim().isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 2),
              child: Text(
                'Auto-filled from your profile',
                style: TextStyle(fontSize: 12, color: Color(0xFF0EA5E9)),
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
              label: Text(_fetchingLocation ? 'Detecting…' : 'Use current location'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustSignalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        const Text(
          'Trust signals',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1E21),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional — this helps find better matches',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        _occupantPreferencesSection(),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _openToSameLanguage,
          decoration: const InputDecoration(
            labelText: 'Open to same language',
            hintText: 'Optional',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem<String>(child: Text('Not specified')),
            DropdownMenuItem(value: 'Yes', child: Text('Yes')),
            DropdownMenuItem(value: 'No', child: Text('No')),
          ],
          onChanged: _saving
              ? null
              : (v) => setState(() {
                    _openToSameLanguage =
                        v == null || v == 'Not specified' ? null : v;
                  }),
        ),
        const SizedBox(height: 8),
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
              selectedColor: const Color(0xFFE7F0FF),
              checkmarkColor: const Color(0xFF0EA5E9),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF0EA5E9) : const Color(0xFF4B5563),
              ),
              side: BorderSide(
                color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFE5E7EB),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 14),
        const Text(
          'Tenant preferences',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1E21),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Who would you prefer as a tenant? Used for mutual matching.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _preferredTenantOccupant,
          decoration: InputDecoration(
            labelText: 'Preferred tenant type',
            hintText: 'Any',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem<String>(child: Text('Any')),
            DropdownMenuItem(value: 'Family', child: Text('Family')),
            DropdownMenuItem(value: 'Working Professionals', child: Text('Working Professionals')),
            DropdownMenuItem(value: 'Students', child: Text('Students')),
          ],
          onChanged: _saving ? null : (v) => setState(() => _preferredTenantOccupant = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _preferredTenantFood,
          decoration: InputDecoration(
            labelText: 'Preferred food preference',
            hintText: 'Any',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem<String>(child: Text('Any')),
            DropdownMenuItem(value: 'Pure Veg', child: Text('Pure Veg')),
            DropdownMenuItem(value: 'Non-Veg', child: Text('Non-Veg')),
          ],
          onChanged: _saving ? null : (v) => setState(() => _preferredTenantFood = v),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          title: const Text('Smoking allowed', style: TextStyle(fontSize: 14)),
          value: _smokingAllowed,
          onChanged: _saving ? null : (v) => setState(() => _smokingAllowed = v),
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0EA5E9),
        ),
        SwitchListTile(
          title: const Text('Drinking allowed', style: TextStyle(fontSize: 14)),
          value: _drinkingAllowed,
          onChanged: _saving ? null : (v) => setState(() => _drinkingAllowed = v),
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0EA5E9),
        ),
        SwitchListTile(
          title: const Text('Quiet hours preferred', style: TextStyle(fontSize: 14)),
          value: _quietHours,
          onChanged: _saving ? null : (v) => setState(() => _quietHours = v),
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0EA5E9),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _scheduleType,
          decoration: InputDecoration(
            labelText: 'Schedule type',
            hintText: 'Flexible',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem<String>(child: Text('Flexible')),
            DropdownMenuItem(value: 'Day shift', child: Text('Day shift')),
            DropdownMenuItem(value: 'Night shift', child: Text('Night shift')),
          ],
          onChanged: _saving ? null : (v) => setState(() => _scheduleType = v),
        ),
      ],
    );
  }

  Widget _occupantPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Occupant preferences',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional — helps describe who the space suits',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 8),
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
          activeColor: const Color(0xFF0EA5E9),
          onChanged: _saving ? null : onChanged,
        ),
        ...options.map(
          (option) => RadioListTile<String?>(
            title: Text(option),
            value: option,
            groupValue: groupValue,
            dense: dense,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF0EA5E9),
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
