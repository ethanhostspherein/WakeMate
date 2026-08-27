-- Family contacts (FamilyContactsService). Run in the Supabase SQL editor.
--
-- Same local-first pattern as trips.sql — SharedPreferences is the source of
-- truth, this table is a best-effort mirror. Missing table = every sync
-- write silently fails.

create table if not exists public.contacts (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text not null,
  channel text not null default 'whatsapp',
  created_at timestamptz not null default now()
);

alter table public.contacts enable row level security;

create policy "owner manage contacts" on public.contacts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
