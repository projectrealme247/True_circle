-- Phase C Step 3: applicant status matrix, timestamps, and host/applicant RLS.

ALTER TABLE public.listing_applications
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.listing_applications
SET status = 'pending'
WHERE status = 'submitted';

UPDATE public.listing_applications
SET status = 'viewing_scheduled'
WHERE status = 'viewed';

UPDATE public.listing_applications
SET status = 'accepted'
WHERE status = 'shortlisted';

ALTER TABLE public.listing_applications
  DROP CONSTRAINT IF EXISTS listing_applications_status_check;

ALTER TABLE public.listing_applications
  ADD CONSTRAINT listing_applications_status_check
  CHECK (
    status IN (
      'pending',
      'viewing_scheduled',
      'accepted',
      'declined'
    )
  );

ALTER TABLE public.listing_applications
  ALTER COLUMN status SET DEFAULT 'pending';

CREATE UNIQUE INDEX IF NOT EXISTS listing_applications_listing_applicant_uidx
  ON public.listing_applications (listing_id, applicant_user_id);

ALTER TABLE public.listing_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Applicants insert own applications"
  ON public.listing_applications;
CREATE POLICY "Applicants insert own applications"
  ON public.listing_applications
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = applicant_user_id);

DROP POLICY IF EXISTS "Applicants read own applications"
  ON public.listing_applications;
CREATE POLICY "Applicants read own applications"
  ON public.listing_applications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = applicant_user_id);

DROP POLICY IF EXISTS "Listing owners read applications"
  ON public.listing_applications;
CREATE POLICY "Listing owners read applications"
  ON public.listing_applications
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.listings l
      WHERE l.id = listing_applications.listing_id
        AND l.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Listing owners update application status"
  ON public.listing_applications;
CREATE POLICY "Listing owners update application status"
  ON public.listing_applications
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.listings l
      WHERE l.id = listing_applications.listing_id
        AND l.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.listings l
      WHERE l.id = listing_applications.listing_id
        AND l.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Listing owners read applicant trust profiles"
  ON public.user_trust_profiles;
CREATE POLICY "Listing owners read applicant trust profiles"
  ON public.user_trust_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.listing_applications la
      JOIN public.listings l ON l.id = la.listing_id
      WHERE la.applicant_user_id = user_trust_profiles.user_id
        AND l.user_id = auth.uid()
    )
  );

COMMENT ON COLUMN public.listing_applications.status IS
  'Host workflow: pending | viewing_scheduled | accepted | declined';
