# CircleKey Supabase — university email OTP
#
# 1. Link project:  supabase link --project-ref YOUR_REF
# 2. Migrate:      supabase db push
# 3. Set secrets:
#      supabase secrets set RESEND_API_KEY=re_xxx
#      supabase secrets set OTP_FROM_EMAIL="CircleKey <verify@yourdomain.com>"
#      supabase secrets set UNIVERSITY_OTP_SECRET=$(openssl rand -hex 32)
# 4. Deploy:       supabase functions deploy university-email-otp
#
# Local dev without Resend: set UNI_OTP_MOCK=true in env.dev.json

[functions.university-email-otp]
verify_jwt = true
