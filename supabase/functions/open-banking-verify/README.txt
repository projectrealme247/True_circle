open-banking-verify — Dublin AIS read-once trust verification (Option B)

Deploy:
  supabase functions deploy open-banking-verify

Secrets:
  OPEN_BANKING_CLIENT_ID / OPEN_BANKING_CLIENT_SECRET — TrueLayer or GoCardless style
  OPEN_BANKING_API_BASE — default https://api.truelayer-sandbox.com
  OPEN_BANKING_TOKEN_URL — default https://auth.truelayer-sandbox.com/connect/token
  OPEN_BANKING_SEAL_SECRET — AES metadata seal key
  OPEN_BANKING_MOCK=true — dev only

Client env:
  OPEN_BANKING_MOCK=true
  OPEN_BANKING_REDIRECT_URI=http://localhost:8080/auth/open-banking/callback

Data minimization:
  - Only account_holder_name + liquidity slice are read from AIS
  - Access tokens revoked immediately after evaluation
  - No IBANs, transaction arrays, or tokens stored in Postgres
