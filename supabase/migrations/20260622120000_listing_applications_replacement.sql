-- Listing applications and lease replacement workflows (Dublin two-space architecture)

create table if not exists public.listing_applications (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  applicant_user_id uuid not null references auth.users(id) on delete cascade,
  space text not null check (space in ('full_rental', 'shared_space')),
  status text not null default 'submitted'
    check (status in ('submitted', 'viewed', 'shortlisted', 'declined')),
  compatibility_score int not null default 0
    check (compatibility_score >= 0 and compatibility_score <= 100),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists listing_applications_listing_id_idx
  on public.listing_applications (listing_id);

create index if not exists listing_applications_applicant_user_id_idx
  on public.listing_applications (applicant_user_id);

create table if not exists public.replacement_workflows (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  outgoing_tenant_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'matched', 'completed', 'cancelled')),
  move_out_date date,
  progress jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists replacement_workflows_listing_id_idx
  on public.replacement_workflows (listing_id);

create index if not exists replacement_workflows_outgoing_tenant_id_idx
  on public.replacement_workflows (outgoing_tenant_id);
