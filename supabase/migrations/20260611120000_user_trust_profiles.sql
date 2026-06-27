-- Server-side trust profile store (Dublin). Document bytes are never persisted here.
CREATE TABLE IF NOT EXISTS public.user_trust_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT '',
  trust_tier text NOT NULL DEFAULT 'Just Landed',
  trust_stage integer NOT NULL DEFAULT 1,
  employment_verified boolean NOT NULL DEFAULT false,
  verification_track text,
  corporate_verification_seal text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_trust_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own trust profile"
  ON public.user_trust_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

COMMENT ON TABLE public.user_trust_profiles IS
  'Authoritative trust tier flags. Corporate document bytes are processed ephemerally in Edge Functions only.';

COMMENT ON COLUMN public.user_trust_profiles.corporate_verification_seal IS
  'AES-GCM encrypted verification metadata — never contains raw document content.';
