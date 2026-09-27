-- Recent trips (UserTripsService). Run in the Supabase SQL editor.
--
-- App is local-first: SharedPreferences is the source of truth, this table
-- is a best-effort mirror synced from user_trips_service.dart. Missing this
-- table is why every write there has been failing silently (caught and
-- dropped) — sync only starts working once this migration is run.

create table if not exists public.trips (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  destination_name text not null,
  destination_lat double precision not null,
  destination_lng double precision not null,
  alarm_distance_km double precision not null,
  sound_id text not null,
  mode text not null,
  pnr text,
  trigger_type text not null,
  trigger_minutes integer,
  status text not null,
  notify_family boolean default false,
  family_contact_name text,
  family_contact_phone text,
  family_channel text,
  distance_travelled_km double precision,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.trips enable row level security;

create policy "owner manage trips" on public.trips
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists trips_user_id_created_at_idx
  on public.trips (user_id, created_at desc);
