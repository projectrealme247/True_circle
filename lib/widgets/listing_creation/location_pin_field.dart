import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/nominatim_forward.dart';
import 'listing_creation_primitives.dart';

/// Interactive map widget for placing a location pin.
///
/// User taps the map to drop a pin; the pin coordinates are passed to
/// [onPinPlaced] which drives proximity resolution. Optionally pans to
/// a searched address without using that address for geocoding.
class LocationPinField extends StatefulWidget {
  const LocationPinField({
    super.key,
    this.initialLat,
    this.initialLon,
    this.pinLat,
    this.pinLon,
    required this.onPinPlaced,
    this.enabled = true,
  });

  final double? initialLat;
  final double? initialLon;
  final double? pinLat;
  final double? pinLon;
  final void Function(double lat, double lon) onPinPlaced;
  final bool enabled;

  @override
  State<LocationPinField> createState() => _LocationPinFieldState();
}

class _LocationPinFieldState extends State<LocationPinField> {
  static const _dublinCenter = LatLng(53.349805, -6.26031);
  static const _defaultZoom = 11.5;

  late final MapController _mapController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;
  bool _pinConfirmed = false;
  String? _confirmedLabel;
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.pinLat != null && widget.pinLon != null) {
      _pin = LatLng(widget.pinLat!, widget.pinLon!);
    }
  }

  @override
  void didUpdateWidget(LocationPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinLat != oldWidget.pinLat ||
        widget.pinLon != oldWidget.pinLon) {
      if (widget.pinLat != null && widget.pinLon != null) {
        final newPin = LatLng(widget.pinLat!, widget.pinLon!);
        if (_pin != newPin) {
          setState(() => _pin = newPin);
          _mapController.move(newPin, 15.0);
        }
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.enabled) return;
    setState(() {
      _pin = point;
      _pinConfirmed = true;
      _confirmedLabel = null;
    });
    widget.onPinPlaced(point.latitude, point.longitude);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final results = await NominatimForward.searchAddress(query.trim());
        if (!mounted) return;
        if (results.isNotEmpty) {
          final first = results.first;
          final target = LatLng(first.lat, first.lon);
          _mapController.move(target, 15.0);
          setState(() {
            _pin = target;
            _searching = false;
            _pinConfirmed = true;
            _confirmedLabel = first.displayLabel;
          });
          widget.onPinPlaced(first.lat, first.lon);
        } else {
          setState(() => _searching = false);
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _pin ??
        (widget.initialLat != null && widget.initialLon != null
            ? LatLng(widget.initialLat!, widget.initialLon!)
            : _dublinCenter);
    final zoom = _pin != null ? 15.0 : _defaultZoom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: listingFieldHeight,
          child: TextFormField(
            controller: _searchController,
            enabled: widget.enabled,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onFieldSubmitted: _onSearchChanged,
            style: listingFieldValueStyle,
            decoration: listingInlineInputDecoration(
              hint: 'Search address to centre map...',
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
            ).copyWith(
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _pinConfirmed
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Color(0xFF16A34A),
                          ),
                        )
                      : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                onTap: _onMapTap,
                interactionOptions: InteractionOptions(
                  flags: widget.enabled
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.truecircle.app',
                ),
                if (_pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          size: 40,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_pin != null && _pinConfirmed) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _confirmedLabel != null
                        ? 'Pin placed — $_confirmedLabel'
                        : 'Pin placed at ${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF15803D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ] else if (_pin != null) ...[
          const SizedBox(height: 8),
          Text(
            'Pin: ${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Tap the map to place your property pin',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }
}
