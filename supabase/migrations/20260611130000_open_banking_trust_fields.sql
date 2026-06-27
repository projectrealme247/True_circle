-- Open Banking AIS trust flags (tokens and transaction arrays are never stored).
ALTER TABLE public.user_trust_profiles
  ADD COLUMN IF NOT EXISTS financial_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS open_banking_verification_seal text;

COMMENT ON COLUMN public.user_trust_profiles.financial_verified IS
  'True when read-once AIS identity + liquidity checks passed via Open Banking Track.';

COMMENT ON COLUMN public.user_trust_profiles.open_banking_verification_seal IS
  'AES-GCM encrypted compliance metadata — no account numbers or access tokens.';
