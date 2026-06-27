-- Listings table with infrastructure fields for Dublin marketplace intelligence.

CREATE TABLE IF NOT EXISTS public.listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  title text NOT NULL,
  price text NOT NULL,
  location text NOT NULL,
  description text NOT NULL DEFAULT '',
  listing_type text NOT NULL DEFAULT 'Rent' CHECK (listing_type IN ('Rent', 'Share', 'Buy')),
  property_type text,
  parking_type text,
  lifestyle_flags text[] NOT NULL DEFAULT '{}',
  languages_spoken text[] NOT NULL DEFAULT '{}',
  latitude double precision,
  longitude double precision,
  proximity_data jsonb,
  room_configuration text,
  furnishing text,
  bhk text,
  bedrooms text,
  current_occupants integer,
  host_name text,
  host_city text,
  host_language text,
  host_mother_tongue text,
  host_food_preference text,
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS listing_type text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS parking_type text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS lifestyle_flags text[] DEFAULT '{}';
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS languages_spoken text[] DEFAULT '{}';
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS proximity_data jsonb;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS property_type text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS room_configuration text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}';

CREATE INDEX IF NOT EXISTS listings_listing_type_idx ON public.listings (listing_type);
CREATE INDEX IF NOT EXISTS listings_user_id_idx ON public.listings (user_id);
CREATE INDEX IF NOT EXISTS listings_geo_idx ON public.listings (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS listings_select_public ON public.listings;
CREATE POLICY listings_select_public
  ON public.listings
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS listings_insert_authenticated ON public.listings;
CREATE POLICY listings_insert_authenticated
  ON public.listings
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS listings_update_owner ON public.listings;
CREATE POLICY listings_update_owner
  ON public.listings
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMENT ON COLUMN public.listings.parking_type IS
  'no_parking | free_dedicated_parking | paid_on_street_parking';
COMMENT ON COLUMN public.listings.proximity_data IS
  'Transit / commute enrichment JSON from enrich-location edge function';
