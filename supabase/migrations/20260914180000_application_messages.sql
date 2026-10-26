-- P0 remote messaging: application thread messages + last-read cursors.

ALTER TABLE public.listing_applications
  ADD COLUMN IF NOT EXISTS applicant_last_read_at timestamptz,
  ADD COLUMN IF NOT EXISTS host_last_read_at timestamptz;

CREATE TABLE IF NOT EXISTS public.application_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.listing_applications(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_role text NOT NULL CHECK (sender_role IN ('applicant', 'host')),
  body text NOT NULL CHECK (char_length(body) > 0 AND char_length(body) <= 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS application_messages_application_created_idx
  ON public.application_messages (application_id, created_at);

ALTER TABLE public.application_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants read application messages"
  ON public.application_messages;
CREATE POLICY "Participants read application messages"
  ON public.application_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.listing_applications la
      WHERE la.id = application_messages.application_id
        AND la.applicant_user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.listing_applications la
      JOIN public.listings l ON l.id = la.listing_id
      WHERE la.id = application_messages.application_id
        AND l.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Participants insert own application messages"
  ON public.application_messages;
CREATE POLICY "Participants insert own application messages"
  ON public.application_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_user_id
    AND (
      (
        sender_role = 'applicant'
        AND EXISTS (
          SELECT 1
          FROM public.listing_applications la
          WHERE la.id = application_messages.application_id
            AND la.applicant_user_id = auth.uid()
        )
      )
      OR (
        sender_role = 'host'
        AND EXISTS (
          SELECT 1
          FROM public.listing_applications la
          JOIN public.listings l ON l.id = la.listing_id
          WHERE la.id = application_messages.application_id
            AND l.user_id = auth.uid()
        )
      )
    )
  );

-- Applicants must not UPDATE listing_applications (status). Read cursors only.
CREATE OR REPLACE FUNCTION public.mark_application_thread_read(p_application_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec public.listing_applications%ROWTYPE;
  is_host boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO rec
  FROM public.listing_applications
  WHERE id = p_application_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF rec.applicant_user_id = auth.uid() THEN
    UPDATE public.listing_applications
    SET applicant_last_read_at = now()
    WHERE id = p_application_id;
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.listings l
    WHERE l.id = rec.listing_id
      AND l.user_id = auth.uid()
  ) INTO is_host;

  IF is_host THEN
    UPDATE public.listing_applications
    SET host_last_read_at = now()
    WHERE id = p_application_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_application_thread_read(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_application_thread_read(uuid) TO authenticated;

COMMENT ON TABLE public.application_messages IS
  'Plain-text messages for one listing application thread.';
COMMENT ON FUNCTION public.mark_application_thread_read(uuid) IS
  'Sets applicant_last_read_at or host_last_read_at for the authenticated participant.';
