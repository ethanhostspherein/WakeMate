-- Live ETA share link (Task #9). Run in the Supabase SQL editor.
--
-- Design: capability URL — the share_token UUID is the secret, same model
-- as "anyone with the link" (Google Docs). Anonymous visitors never get
-- direct table SELECT (that would let anyone list every active share by
-- querying the table broadly); instead they can only read a row by calling
-- get_trip_share(token), a SECURITY DEFINER function that filters by exact
-- token match before returning anything.

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

alter table public.trip_shares enable row level security;

-- Owner (the signed-in app user) can create/update/delete their own shares.
-- No policy grants anon direct SELECT — see get_trip_share() below instead.
create policy "owner manage shares" on public.trip_shares
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

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

grant execute on function public.get_trip_share(uuid) to anon;
