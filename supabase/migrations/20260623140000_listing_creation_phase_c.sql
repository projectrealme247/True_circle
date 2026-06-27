-- Phase C Step 2: Eircode-first geospatial + marketplace category columns.

CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS eircode text,
  ADD COLUMN IF NOT EXISTS location_geom geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS marketplace_category text
    CHECK (
      marketplace_category IS NULL
      OR marketplace_category IN ('independent_places', 'shared_living')
    ),
  ADD COLUMN IF NOT EXISTS beds_count integer
    CHECK (beds_count IS NULL OR beds_count >= 1),
  ADD COLUMN IF NOT EXISTS rtb_status text
    CHECK (
      rtb_status IS NULL
      OR rtb_status IN ('registered', 'not_registered', 'not_provided')
    ),
  ADD COLUMN IF NOT EXISTS rtb_registered boolean,
  ADD COLUMN IF NOT EXISTS parking_available boolean,
  ADD COLUMN IF NOT EXISTS household_dynamic text,
  ADD COLUMN IF NOT EXISTS kitchen_culture text
    CHECK (
      kitchen_culture IS NULL
      OR kitchen_culture IN ('veg_friendly', 'non_veg_friendly', 'open')
    );

CREATE INDEX IF NOT EXISTS listings_location_geom_idx
  ON public.listings USING GIST (location_geom);

CREATE INDEX IF NOT EXISTS listings_marketplace_category_idx
  ON public.listings (marketplace_category);

COMMENT ON COLUMN public.listings.eircode IS
  'Validated Irish Eircode — primary geospatial input for Dublin listings.';
COMMENT ON COLUMN public.listings.location_geom IS
  'PostGIS geography point (EPSG:4326) derived from Eircode geocoding.';
COMMENT ON COLUMN public.listings.marketplace_category IS
  'Option 2 tower: independent_places | shared_living';
COMMENT ON COLUMN public.listings.kitchen_culture IS
  'Shared-living kitchen culture — not kitchen utility timing.';
