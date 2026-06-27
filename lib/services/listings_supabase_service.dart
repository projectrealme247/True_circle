import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/listing_data.dart';
import '../utils/student_track_preference.dart';
import 'auth_service.dart';

/// Persists listings to Supabase `public.listings` with local shape round-trip.
abstract final class ListingsSupabaseService {
  static const _table = 'listings';

  static bool get canWrite => AuthService.isAuthenticated;

  /// Inserts a listing row; returns app-shaped map or null when skipped/failed.
  static Future<Map<String, dynamic>?> tryInsertListing(
    Map<String, dynamic> local,
  ) async {
    if (!canWrite) return null;

    try {
      final row = _toSupabaseRow(local);
      final response = await AuthService.client
          .from(_table)
          .insert(row)
          .select()
          .single();

      return _fromSupabaseRow(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      debugPrint('ListingsSupabaseService insert failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ListingsSupabaseService insert error: $e');
      return null;
    }
  }

  /// Updates an owned listing row; returns app-shaped map or null when skipped/failed.
  static Future<Map<String, dynamic>?> tryUpdateListing(
    String listingId,
    Map<String, dynamic> local,
  ) async {
    if (!canWrite || listingId.trim().isEmpty) return null;

    try {
      final row = _toSupabaseRow(local);
      final response = await AuthService.client
          .from(_table)
          .update(row)
          .eq('id', listingId)
          .select()
          .single();

      return _fromSupabaseRow(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      debugPrint('ListingsSupabaseService update failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ListingsSupabaseService update error: $e');
      return null;
    }
  }

  static Map<String, dynamic> _toSupabaseRow(Map<String, dynamic> local) {
    final userId = AuthService.currentUser?.id;
    final listingType =
        ListingData.text(local['listing_type']).isNotEmpty
            ? ListingData.text(local['listing_type'])
            : ListingData.propertyType(local);

    final lifestyle = local['lifestyle_flags'];
    final languages = local['languages_spoken'];

    final metadata = <String, dynamic>{
      if (local['type'] != null) 'type': local['type'],
      if (local['intent_type'] != null) 'intent_type': local['intent_type'],
      if (local['hostName'] != null) 'hostName': local['hostName'],
      if (local['hostCity'] != null) 'hostCity': local['hostCity'],
      if (local['hostLanguage'] != null) 'hostLanguage': local['hostLanguage'],
      if (local['hostMotherTongue'] != null)
        'hostMotherTongue': local['hostMotherTongue'],
      if (local['hostFoodPreference'] != null)
        'hostFoodPreference': local['hostFoodPreference'],
      if (local['foodPreference'] != null) 'foodPreference': local['foodPreference'],
      if (local['occupantType'] != null) 'occupantType': local['occupantType'],
      if (local['bachelorPreference'] != null)
        'bachelorPreference': local['bachelorPreference'],
      if (local['studentType'] != null) 'studentType': local['studentType'],
      if (local['preferred_tenant_occupant'] != null)
        'preferred_tenant_occupant': local['preferred_tenant_occupant'],
      if (local['preferred_tenant_food'] != null)
        'preferred_tenant_food': local['preferred_tenant_food'],
      if (local['room_type'] != null) 'room_type': local['room_type'],
      if (local['property_category'] != null)
        'property_category': local['property_category'],
      if (local['property_structure'] != null)
        'property_structure': local['property_structure'],
      if (local['share_room_kind'] != null) 'share_room_kind': local['share_room_kind'],
      if (local['layout_token'] != null) 'layout_token': local['layout_token'],
      if (local['coverImageUrl'] != null) 'coverImageUrl': local['coverImageUrl'],
      if (local['images'] is List) 'images': local['images'],
      if (local['video'] != null) 'video': local['video'],
      if (local['spoken_languages'] is List)
        'spoken_languages': local['spoken_languages'],
      if (local['host_trust_stage'] != null)
        'host_trust_stage': local['host_trust_stage'],
      if (local['host_trust_multiplier'] != null)
        'host_trust_multiplier': local['host_trust_multiplier'],
    };

    return {
      if (userId != null) 'user_id': userId,
      'title': ListingData.title(local),
      'price': ListingData.price(local),
      'location': ListingData.location(local),
      'description': ListingData.description(local),
      'listing_type': listingType,
      'property_type': ListingData.text(local['property_type']).isNotEmpty
          ? ListingData.text(local['property_type'])
          : ListingData.text(
              local['property_structure'] ?? local['property_category'],
            ),
      if (ListingData.parkingType(local).isNotEmpty)
        'parking_type': ListingData.parkingType(local),
      if (lifestyle is List && lifestyle.isNotEmpty)
        'lifestyle_flags': lifestyle,
      if (languages is List && languages.isNotEmpty)
        'languages_spoken': languages,
      if (local['latitude'] is num) 'latitude': (local['latitude'] as num).toDouble(),
      if (local['longitude'] is num) 'longitude': (local['longitude'] as num).toDouble(),
      if (local['proximity_data'] != null) 'proximity_data': local['proximity_data'],
      if (ListingData.text(local['room_configuration']).isNotEmpty)
        'room_configuration': ListingData.text(local['room_configuration']),
      if (ListingData.furnishing(local).isNotEmpty)
        'furnishing': ListingData.furnishing(local),
      if (ListingData.bhk(local).isNotEmpty) 'bhk': ListingData.bhk(local),
      if (ListingData.bedrooms(local).isNotEmpty)
        'bedrooms': ListingData.bedrooms(local),
      if (ListingData.currentOccupants(local) > 0)
        'current_occupants': ListingData.currentOccupants(local),
      'host_name': ListingData.hostName(local),
      'host_city': ListingData.hostCity(local),
      'host_language': ListingData.hostLanguage(local),
      'host_mother_tongue': ListingData.hostMotherTongue(local),
      'host_food_preference': ListingData.hostFoodPreference(local),
      'tenant_track_preference':
          ListingData.tenantTrackPreference(local).dbValue,
      'metadata': metadata,
    };
  }

  static Map<String, dynamic> _fromSupabaseRow(Map<String, dynamic> row) {
    final metadata = row['metadata'];
    final meta = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};

    final lifestyle = row['lifestyle_flags'];
    final languages = row['languages_spoken'];

    return {
      'id': row['id']?.toString() ?? meta['id'],
      'title': row['title'],
      'price': row['price'],
      'location': row['location'],
      'description': row['description'],
      'type': row['listing_type'] ?? meta['type'] ?? 'Rent',
      'listing_type': row['listing_type'],
      'property_type': row['property_type'],
      if (row['parking_type'] != null) 'parking_type': row['parking_type'],
      if (lifestyle is List) 'lifestyle_flags': lifestyle,
      if (languages is List) 'languages_spoken': languages,
      if (row['latitude'] != null) 'latitude': row['latitude'],
      if (row['longitude'] != null) 'longitude': row['longitude'],
      if (row['proximity_data'] != null) 'proximity_data': row['proximity_data'],
      if (row['room_configuration'] != null)
        'room_configuration': row['room_configuration'],
      if (row['furnishing'] != null) 'furnishing': row['furnishing'],
      if (row['bhk'] != null) 'bhk': row['bhk'],
      if (row['bedrooms'] != null) 'bedrooms': row['bedrooms'],
      if (row['current_occupants'] != null)
        'current_occupants': row['current_occupants'],
      'hostName': row['host_name'] ?? meta['hostName'],
      'hostCity': row['host_city'] ?? meta['hostCity'],
      'hostLanguage': row['host_language'] ?? meta['hostLanguage'],
      'hostMotherTongue': row['host_mother_tongue'] ?? meta['hostMotherTongue'],
      'hostFoodPreference':
          row['host_food_preference'] ?? meta['hostFoodPreference'],
      'tenant_track_preference':
          StudentTrackPreference.fromDbValue(row['tenant_track_preference'])
              .dbValue,
      if (meta['foodPreference'] != null) 'foodPreference': meta['foodPreference'],
      ...meta,
    };
  }
}
