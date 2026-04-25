-- ============================================================
-- 005_counselor_membership_and_realtime.sql
-- ============================================================
-- 用途：
--   1. 確保 public.counselors 表 + public.is_counselor() function 存在。
--      這兩個是 002_chat_history.sql / 003_user_insights.sql 的 RLS 政策
--      會用到的，但之前的 migration 沒有把它們的定義寫進來。
--
--   2. 把 chat_messages / chat_conversations 加進 Supabase Realtime
--      publication，讓諮詢師端可以訂閱即時更新（user 寫一句、諮詢師
--      頁面瞬間跳出來）。
--
--   3. 加一條 RLS：諮詢師可以 select / insert / update chat_conversations
--      （不只 chat_messages），這樣 RT 訂閱新對話也收得到。
--
-- 全部 idempotent，重跑安全。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) public.counselors 名單
-- ------------------------------------------------------------
create table if not exists public.counselors (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.counselors enable row level security;

-- 諮詢師自己可以讀自己那筆（不必，但比較不會跌坑）
drop policy if exists counselors_self_select on public.counselors;
create policy counselors_self_select on public.counselors
  for select using (auth.uid() = user_id);

-- 真正的寫入只透過 service role（backend 註冊端）；不開放 anon / authenticated 寫
grant select on public.counselors to authenticated;

-- ------------------------------------------------------------
-- 2) is_counselor() — 002 / 003 政策依賴的判斷函式
-- ------------------------------------------------------------
create or replace function public.is_counselor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.counselors c
    where c.user_id = auth.uid()
      and c.active = true
  );
$$;

grant execute on function public.is_counselor() to authenticated, anon;

-- ------------------------------------------------------------
-- 3) chat_conversations：諮詢師也要能 select（RT 才看得到新對話）
-- ------------------------------------------------------------
drop policy if exists chat_conversations_self_all on public.chat_conversations;
create policy chat_conversations_self_all on public.chat_conversations
  for all using (
    auth.uid() = user_id
    or coalesce(public.is_counselor(), false)
  ) with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 4) Realtime publication — 加上 chat_messages / chat_conversations
--    既有的 supabase_realtime publication 在每個 Supabase project 都有。
--    add table 是 idempotent-ish：重複加會報錯，所以包在 do block 吃掉。
-- ------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.chat_messages;
  exception when duplicate_object then
    -- 已經在 publication 內，略過
    null;
  end;
  begin
    alter publication supabase_realtime add table public.chat_conversations;
  exception when duplicate_object then
    null;
  end;
end $$;

-- ------------------------------------------------------------
-- 5) reload PostgREST schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
