# LinkedIn OAuth (Stage 2 social verification)
#
# LinkedIn Developer app: https://www.linkedin.com/developers/
# Product: "Sign In with LinkedIn using OpenID Connect"
# Redirect URL must match LINKEDIN_REDIRECT_URI in env.dev.json
#   e.g. http://localhost:8080/auth/linkedin/callback
#
# supabase secrets set LINKEDIN_CLIENT_ID=your_client_id
# supabase secrets set LINKEDIN_CLIENT_SECRET=your_client_secret
# supabase functions deploy linkedin-oauth
#
# Local dev without LinkedIn app: LINKEDIN_MOCK=true in env.dev.json
