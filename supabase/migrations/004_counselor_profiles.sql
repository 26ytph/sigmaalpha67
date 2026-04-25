-- ============================================================
-- 004_counselor_profiles.sql
-- ============================================================
-- 用途：諮詢師端的個人檔案（姓名 / 敘述 / 專長領域）。
--      跟一般使用者的 public.profiles 完全分開，避免污染原本的欄位。
--
-- 一個諮詢師一份 row（user_id 為 PK）。
-- 在 Supabase Dashboard → SQL Editor 整段貼上即可。全部 idempotent。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) counselor_profiles table
-- ------------------------------------------------------------
create table if not exists public.counselor_profiles (
  user_id      uuid primary key
                references auth.users(id) on delete cascade,
  name         text not null default '',
  description  text not null default '',
  expertise    text[] not null default '{}',
  email        text not null default '',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 共用的 updated_at trigger（如果之前的 migration 沒建過就建一次）
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists counselor_profiles_touch on public.counselor_profiles;
create trigger counselor_profiles_touch before update on public.counselor_profiles
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- 2) RLS：每位諮詢師只能讀／寫自己的 row
-- ------------------------------------------------------------
alter table public.counselor_profiles enable row level security;

drop policy if exists counselor_profiles_self_select on public.counselor_profiles;
create policy counselor_profiles_self_select on public.counselor_profiles
  for select using (auth.uid() = user_id);

drop policy if exists counselor_profiles_self_insert on public.counselor_profiles;
create policy counselor_profiles_self_insert on public.counselor_profiles
  for insert with check (auth.uid() = user_id);

drop policy if exists counselor_profiles_self_update on public.counselor_profiles;
create policy counselor_profiles_self_update on public.counselor_profiles
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 3) Grants — authenticated 全 CRUD（被 RLS 守住）
-- ------------------------------------------------------------
grant select, insert, update on public.counselor_profiles to authenticated;

-- ------------------------------------------------------------
-- 4) reload PostgREST schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
