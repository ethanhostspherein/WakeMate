-- =============================================================================
-- WakeMate Master Supabase Database Setup & Verification Migration Script
-- Run this complete script in your Supabase SQL Editor.
-- Safe & idempotent: handles existing tables/columns/policies/functions cleanly.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TRIPS TABLE (User Recent Trips & History Sync)
-- -----------------------------------------------------------------------------
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

-- Ensure family notification columns exist if table was created previously
alter table public.trips 
  add column if not exists notify_family boolean default false,
  add column if not exists family_contact_name text,
  add column if not exists family_contact_phone text,
  add column if not exists family_channel text;

-- Enable Row Level Security (RLS)
alter table public.trips enable row level security;

-- Drop policy if exists to ensure clean idempotent creation
do $$ begin
  drop policy if exists "owner manage trips" on public.trips;
exception when others then null;
end $$;

create policy "owner manage trips" on public.trips
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Create index for fast user trip history queries
create index if not exists trips_user_id_created_at_idx
  on public.trips (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 2. CONTACTS TABLE (Family Contacts Sync)
-- -----------------------------------------------------------------------------
create table if not exists public.contacts (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text not null,
  channel text not null default 'whatsapp',
  created_at timestamptz not null default now()
);

-- Enable Row Level Security (RLS)
alter table public.contacts enable row level security;

-- Drop policy if exists to ensure clean idempotent creation
do $$ begin
  drop policy if exists "owner manage contacts" on public.contacts;
exception when others then null;
end $$;

create policy "owner manage contacts" on public.contacts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 3. TRIP SHARES TABLE (Live ETA Share Links)
-- -----------------------------------------------------------------------------
create table if not exists public.trip_shares (
  share_token uuid primary key default gen_random_uuid(),
  trip_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  dest_lat double precision not null,
  dest_lng double precision not null,
  dest_name text,
  current_lat double precision,
  current_lng double precision,
  eta_minutes integer,
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Enable Row Level Security (RLS)
alter table public.trip_shares enable row level security;

-- Drop policy if exists to ensure clean idempotent creation
do $$ begin
  drop policy if exists "owner manage shares" on public.trip_shares;
exception when others then null;
end $$;

create policy "owner manage shares" on public.trip_shares
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 4. RPC FUNCTION & PERMISSIONS FOR ANONYMOUS SHARE LINK VIEWING
-- -----------------------------------------------------------------------------
create or replace function public.get_trip_share(token uuid)
returns table (
  dest_lat double precision,
  dest_lng double precision,
  dest_name text,
  current_lat double precision,
  current_lng double precision,
  eta_minutes integer,
  updated_at timestamptz,
  expires_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select dest_lat, dest_lng, dest_name, current_lat, current_lng,
         eta_minutes, updated_at, expires_at
  from public.trip_shares
  where share_token = token and expires_at > now();
$$;

-- Grant execution permission to anonymous web visitors
grant execute on function public.get_trip_share(uuid) to anon;

-- =============================================================================
-- Verification Complete: Output status message
-- =============================================================================
select 'WakeMate Supabase Schema Setup Completed Successfully!' as status;
