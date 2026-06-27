-- TrueCircle staging seed: synthetic applicants for
-- listing_id = mock-listing-dublin-ranelagh-shared.
--
-- Run with Supabase CLI (linked project):
--   supabase db query --linked --file supabase/seed/demo_applicants.sql

begin;

insert into public.user_trust_profiles (
  user_id,
  full_name,
  trust_tier,
  trust_stage,
  identity_trust_tier,
  employment_verified,
  financial_verified
)
values
  ('dublin-mock-user-mark', 'Mark O''Connor', 'Sound', 3, 'Corporate_Ready', true, true),
  ('dublin-mock-user-niamh', 'Niamh Byrne', 'Sound', 3, 'Corporate_Ready', true, true),
  ('dublin-mock-user-luke', 'Luke Gallagher', 'Sound', 3, 'Corporate_Ready', true, true),
  ('dublin-mock-user-chloe', 'Chloe Dubois', 'Grand', 2, 'Education_Verified', false, false),
  ('dublin-mock-user-sofia', 'Sofia Rossi', 'Grand', 2, 'Education_Verified', false, false),
  ('dublin-mock-user-tomasz', 'Tomasz Kowalski', 'Grand', 2, 'Education_Verified', false, false),
  ('dublin-mock-user-aarav', 'Aarav Mehta', 'Just Landed', 1, 'Casual_Browser', false, false),
  ('dublin-mock-user-linh', 'Linh Nguyen', 'Just Landed', 1, 'Casual_Browser', false, false),
  ('dublin-mock-user-samir', 'Samir Khan', 'Just Landed', 1, 'Casual_Browser', false, false)
on conflict (user_id) do nothing;

insert into public.listing_applications (
  id,
  listing_id,
  applicant_user_id,
  status,
  compatibility_score,
  payload
)
values
  (
    'dublin-mock-app-mark',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-mark',
    'pending',
    91,
    '{"full_name":"Mark O''Connor","commute_mode":"luas","commute_summary":"Luas Green Line · Ranelagh → city centre"}'::jsonb
  ),
  (
    'dublin-mock-app-niamh',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-niamh',
    'pending',
    88,
    '{"full_name":"Niamh Byrne","commute_mode":"luas","commute_summary":"Luas Green Line · Ranelagh → Docklands"}'::jsonb
  ),
  (
    'dublin-mock-app-luke',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-luke',
    'pending',
    86,
    '{"full_name":"Luke Gallagher","commute_mode":"luas","commute_summary":"Luas Green Line · Ranelagh → Grand Canal Dock"}'::jsonb
  ),
  (
    'dublin-mock-app-chloe',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-chloe',
    'viewing_scheduled',
    82,
    '{"full_name":"Chloe Dubois","commute_mode":"cycle_bus","commute_summary":"Cycle / 39a bus · Ranelagh → UCD Belfield"}'::jsonb
  ),
  (
    'dublin-mock-app-sofia',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-sofia',
    'viewing_scheduled',
    80,
    '{"full_name":"Sofia Rossi","commute_mode":"luas_walk","commute_summary":"Luas Green Line · Ranelagh → TCD"}'::jsonb
  ),
  (
    'dublin-mock-app-tomasz',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-tomasz',
    'pending',
    78,
    '{"full_name":"Tomasz Kowalski","commute_mode":"bus_luas","commute_summary":"Dublin Bus + Luas · Ranelagh → UCD"}'::jsonb
  ),
  (
    'dublin-mock-app-aarav',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-aarav',
    'pending',
    76,
    '{"full_name":"Aarav Mehta","commute_mode":"walk_luas","commute_summary":"Walk / Luas · Ranelagh → Trinity College Dublin"}'::jsonb
  ),
  (
    'dublin-mock-app-linh',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-linh',
    'pending',
    73,
    '{"full_name":"Linh Nguyen","commute_mode":"walk_transit","commute_summary":"Bus/Luas · Ranelagh → Pearse Street"}'::jsonb
  ),
  (
    'dublin-mock-app-samir',
    'mock-listing-dublin-ranelagh-shared',
    'dublin-mock-user-samir',
    'pending',
    70,
    '{"full_name":"Samir Khan","commute_mode":"bus_walk","commute_summary":"Dublin Bus corridor · Ranelagh → city centre"}'::jsonb
  )
on conflict (id) do nothing;

commit;
