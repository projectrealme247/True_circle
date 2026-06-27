Deploy:
  supabase functions deploy enrich-location --no-verify-jwt

Secrets (optional for Google Places; Dublin node graph fallback otherwise):
  supabase secrets set GOOGLE_PLACES_API_KEY=your_key

Request body:
  { "latitude": 53.338, "longitude": -6.259 }
  Optional: "listing_id" to persist proximity_data on an existing row.

Response when tagged:
  { "ok": true, "tagged": true, "proximity_data": {
      "transit_type": "Luas Green Line",
      "walk_minutes": 8,
      "nearest_stop_name": "St. Stephen's Green",
      ...
    }}

The INSERT trigger in 20260601120001_listings_enrich_location_trigger.sql
calls this function when latitude/longitude are present on new listings.
