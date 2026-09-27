-- Migration: Add family notification fields to public.trips table
-- Run this script in your Supabase SQL Editor if you already created the public.trips table earlier.

alter table public.trips 
  add column if not exists notify_family boolean default false,
  add column if not exists family_contact_name text,
  add column if not exists family_contact_phone text,
  add column if not exists family_channel text;
