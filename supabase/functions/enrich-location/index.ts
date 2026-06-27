import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
  listing_id?: string;
  latitude?: number;
  longitude?: number;
}

type TransitMode = "luas_green" | "luas_red" | "dart" | "bus_hf";

interface TransitNode {
  id: string;
  name: string;
  lat: number;
  lng: number;
  mode: TransitMode;
}

/** Strict walking envelope for Path B macro-tagging (~12 min at 5 km/h). */
const STRICT_WALK_THRESHOLD_KM = 1.0;
const WALKING_KMH = 5;

const TRANSIT_NODES: TransitNode[] = [
  { id: "luas_green_cherrywood", name: "Cherrywood", lat: 53.2445, lng: -6.1458, mode: "luas_green" },
  { id: "luas_green_sandyford", name: "Sandyford", lat: 53.2775, lng: -6.2040, mode: "luas_green" },
  { id: "luas_green_dundrum", name: "Dundrum", lat: 53.2890, lng: -6.2430, mode: "luas_green" },
  { id: "luas_green_beechwood", name: "Beechwood", lat: 53.3015, lng: -6.2520, mode: "luas_green" },
  { id: "luas_green_ranelagh", name: "Ranelagh", lat: 53.3260, lng: -6.2550, mode: "luas_green" },
  { id: "luas_green_st_stephens_green", name: "St. Stephen's Green", lat: 53.3382, lng: -6.2591, mode: "luas_green" },
  { id: "luas_green_grand_canal_dock", name: "Grand Canal Dock", lat: 53.3419, lng: -6.2373, mode: "luas_green" },
  { id: "luas_red_heuston", name: "Heuston", lat: 53.3465, lng: -6.2925, mode: "luas_red" },
  { id: "luas_red_abbey_street", name: "Abbey Street", lat: 53.3485, lng: -6.2580, mode: "luas_red" },
  { id: "luas_red_connolly", name: "Connolly", lat: 53.3510, lng: -6.2495, mode: "luas_red" },
  { id: "dart_grand_canal_dock", name: "Grand Canal Dock (DART)", lat: 53.3386, lng: -6.2386, mode: "dart" },
  { id: "dart_pearse", name: "Pearse", lat: 53.3433, lng: -6.2483, mode: "dart" },
  { id: "dart_tara_street", name: "Tara Street", lat: 53.3471, lng: -6.2561, mode: "dart" },
  { id: "dart_connolly", name: "Connolly (DART)", lat: 53.3510, lng: -6.2495, mode: "dart" },
  { id: "dart_blackrock", name: "Blackrock", lat: 53.3015, lng: -6.1785, mode: "dart" },
  { id: "dart_dun_laoghaire", name: "Dun Laoghaire", lat: 53.2944, lng: -6.1330, mode: "dart" },
  { id: "bus_hf_rathmines", name: "Rathmines (46A corridor)", lat: 53.3205, lng: -6.2660, mode: "bus_hf" },
  { id: "bus_hf_drumcondra", name: "Drumcondra (H3 corridor)", lat: 53.3630, lng: -6.2580, mode: "bus_hf" },
  { id: "bus_hf_blanchardstown", name: "Blanchardstown Centre", lat: 53.3935, lng: -6.3765, mode: "bus_hf" },
];

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function walkingMinutes(km: number): number {
  return Math.max(1, Math.round((km / WALKING_KMH) * 60));
}

function transitTypeLabel(mode: TransitMode): string {
  switch (mode) {
    case "luas_green":
      return "Luas Green Line";
    case "luas_red":
      return "Luas Red Line";
    case "dart":
      return "DART";
    default:
      return "Dublin Bus High-Frequency";
  }
}

function nearestTransitNode(latitude: number, longitude: number): {
  node: TransitNode;
  distanceKm: number;
} {
  let best = TRANSIT_NODES[0];
  let bestKm = Number.POSITIVE_INFINITY;
  for (const node of TRANSIT_NODES) {
    const km = haversineKm(latitude, longitude, node.lat, node.lng);
    if (km < bestKm) {
      bestKm = km;
      best = node;
    }
  }
  return { node: best, distanceKm: bestKm };
}

/** PostGIS-style proximity cross-check against Dublin rapid transit nodes. */
function extractTransitProximity(
  latitude: number,
  longitude: number,
): Record<string, unknown> | null {
  const { node, distanceKm } = nearestTransitNode(latitude, longitude);
  if (distanceKm > STRICT_WALK_THRESHOLD_KM) return null;

  const walkMinutes = walkingMinutes(distanceKm);
  const transitType = transitTypeLabel(node.mode);

  return {
    transit_type: transitType,
    walk_minutes: walkMinutes,
    nearest_stop_name: node.name,
    nearest_stop_id: node.id,
    nearest_transit_name: node.name,
    nearest_transit_minutes: walkMinutes,
    luas_line: transitType,
    luas_minutes: walkMinutes,
    transit_headline: `${walkMinutes}-min walk to ${node.name}`,
    has_direct_luas: node.mode !== "bus_hf",
    source: "path_b_postgis",
    latitude,
    longitude,
  };
}

async function fetchGoogleTransit(
  latitude: number,
  longitude: number,
): Promise<Record<string, unknown> | null> {
  const apiKey = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!apiKey) return null;

  const url = new URL(
    "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
  );
  url.searchParams.set("location", `${latitude},${longitude}`);
  url.searchParams.set("rankby", "distance");
  url.searchParams.set("type", "transit_station");
  url.searchParams.set("key", apiKey);

  const response = await fetch(url);
  if (!response.ok) return null;

  const data = await response.json();
  const results = Array.isArray(data.results) ? data.results : [];
  if (results.length === 0) return null;

  const luas = results.find((place: { name?: string }) =>
    /luas|green\s*line|tram/i.test(place.name ?? "")
  );
  const station = luas ?? results[0];
  const name = String(station.name ?? "Luas");
  const location = station.geometry?.location;
  let minutes = 8;

  if (location?.lat != null && location?.lng != null) {
    const km = haversineKm(latitude, longitude, location.lat, location.lng);
    minutes = walkingMinutes(km);
    if (km > STRICT_WALK_THRESHOLD_KM) return null;
  }

  const line = /luas.*green|green\s*line/i.test(name)
    ? "Luas Green Line"
    : /luas.*red|red\s*line/i.test(name)
    ? "Luas Red Line"
    : /luas|tram/i.test(name)
    ? "Luas"
    : "Dublin Bus High-Frequency";

  return {
    transit_type: line,
    walk_minutes: minutes,
    luas_line: line,
    nearest_transit_name: name,
    luas_minutes: minutes,
    nearest_transit_minutes: minutes,
    transit_headline: `${minutes}-min walk to ${name}`,
    has_direct_luas: /luas|green|tram/i.test(name),
    source: "google_places",
    latitude,
    longitude,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as RequestBody;
    const listingId = body.listing_id?.trim();
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return jsonResponse({ error: "latitude and longitude are required." }, 400);
    }

    const proximity =
      extractTransitProximity(latitude, longitude) ??
      (await fetchGoogleTransit(latitude, longitude));

    if (!proximity) {
      return jsonResponse({
        ok: true,
        tagged: false,
        message: "No rapid transit stop within walking threshold.",
        latitude,
        longitude,
      });
    }

    if (!listingId) {
      return jsonResponse({ ok: true, tagged: true, proximity_data: proximity });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return jsonResponse({ error: "Supabase service configuration missing." }, 500);
    }

    const client = createClient(supabaseUrl, serviceKey);
    const { error } = await client
      .from("listings")
      .update({
        proximity_data: proximity,
        updated_at: new Date().toISOString(),
      })
      .eq("id", listingId);

    if (error) {
      return jsonResponse({ error: error.message }, 500);
    }

    return jsonResponse({ ok: true, tagged: true, proximity_data: proximity });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return jsonResponse({ error: message }, 500);
  }
});
