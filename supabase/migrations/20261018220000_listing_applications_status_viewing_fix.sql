-- P0 remote applications: align status CHECK with Dart lifecycle + viewing fields.

ALTER TABLE public.listing_applications
  ADD COLUMN IF NOT EXISTS viewing_date text,
  ADD COLUMN IF NOT EXISTS viewing_time text,
  ADD COLUMN IF NOT EXISTS viewing_location text;

ALTER TABLE public.listing_applications
  DROP CONSTRAINT IF EXISTS listing_applications_status_check;

ALTER TABLE public.listing_applications
  ADD CONSTRAINT listing_applications_status_check
  CHECK (
    status IN (
      'pending',
      'viewing_invitation_sent',
      'viewing_scheduled',
      'accepted',
      'declined'
    )
  );

COMMENT ON COLUMN public.listing_applications.status IS
  'Host workflow: pending | viewing_invitation_sent | viewing_scheduled | accepted | declined';

COMMENT ON COLUMN public.listing_applications.viewing_date IS
  'Host viewing invitation date label (display string).';

COMMENT ON COLUMN public.listing_applications.viewing_time IS
  'Host viewing invitation time label (display string).';

COMMENT ON COLUMN public.listing_applications.viewing_location IS
  'Host viewing invitation location label (display string).';
