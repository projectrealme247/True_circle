-- OTP storage for Dublin Track A university email verification.
-- Written/read only by the university-email-otp Edge Function (service role).

create table if not exists public.university_email_otps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  email text not null,
  otp_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  send_count int not null default 1,
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint university_email_otps_user_email_key unique (user_id, email)
);

create index if not exists university_email_otps_expires_at_idx
  on public.university_email_otps (expires_at);

alter table public.university_email_otps enable row level security;

-- No client policies — Edge Function uses service role for all access.

comment on table public.university_email_otps is
  'Hashed OTP codes for .ie university email verification (Dublin light trust Track A).';
