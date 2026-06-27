corporate-document-verify — Dublin ephemeral corporate document OCR (zero-retention)

Deploy:
  supabase functions deploy corporate-document-verify

Secrets (production):
  CORPORATE_VERIFY_SEAL_SECRET — AES key material for verification metadata seal
  CORPORATE_VERIFY_MOCK=true     — local/dev only; skips OCR, uses synthetic pass text

Client env (env.dev.json):
  CORPORATE_VERIFY_MOCK=true

Flow:
  1. Client streams base64 file bytes in JSON (never stored locally on server disk).
  2. Edge function extracts text in RAM via unpdf (PDF) or ASCII sweep (images).
  3. Validates name match, 2026 contract dates, and employer/CRO patterns.
  4. Updates user_trust_profiles (trust_tier=Grand) with encrypted metadata seal.
  5. Purges all buffers before response returns.
