-- Landlord preference for which student verification tracks are accepted on a listing.
-- track_a: enrolled / on-campus path (active university email check)
-- track_b: pre-arrival document path
-- both: accept tenants from either track

DO $$ BEGIN
  CREATE TYPE public.student_track_preference AS ENUM (
    'track_a',
    'track_b',
    'both'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS tenant_track_preference public.student_track_preference
  NOT NULL DEFAULT 'both';

COMMENT ON COLUMN public.listings.tenant_track_preference IS
  'Landlord acceptance: track_a (on-campus / enrolled), track_b (pre-arrival documents), or both.';
