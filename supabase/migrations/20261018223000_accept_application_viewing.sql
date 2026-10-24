-- Applicant may accept a viewing invitation without full UPDATE on listing_applications.

CREATE OR REPLACE FUNCTION public.accept_application_viewing(p_application_id uuid)
RETURNS public.listing_applications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec public.listing_applications%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO rec
  FROM public.listing_applications
  WHERE id = p_application_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'application not found';
  END IF;

  IF rec.applicant_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not applicant';
  END IF;

  IF rec.status IS DISTINCT FROM 'viewing_invitation_sent' THEN
    RAISE EXCEPTION 'invalid status for accept';
  END IF;

  UPDATE public.listing_applications
  SET
    status = 'viewing_scheduled',
    updated_at = now()
  WHERE id = p_application_id
  RETURNING * INTO rec;

  RETURN rec;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_application_viewing(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_application_viewing(uuid) TO authenticated;

COMMENT ON FUNCTION public.accept_application_viewing(uuid) IS
  'Applicant-only: viewing_invitation_sent → viewing_scheduled.';
