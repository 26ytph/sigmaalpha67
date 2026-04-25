-- ============================================================
-- 002_chat_history.sql
-- ============================================================
-- 用途：確保 chat_conversations / chat_messages 兩張表存在、欄位正確、
--      RLS 與 grants 都有套上。可重複跑（idempotent）。
--
-- 在 Supabase Dashboard → SQL Editor 整段貼上 → Run。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) chat_conversations
-- ------------------------------------------------------------
create table if not exists public.chat_conversations (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  mode        text not null default 'career'
              check (mode in ('career','startup')),
  created_at  timestamptz not null default now()
);

create index if not exists chat_conversations_user_idx
  on public.chat_conversations(user_id, created_at desc);

-- ------------------------------------------------------------
-- 2) chat_messages
-- ------------------------------------------------------------
create table if not exists public.chat_messages (
  id              uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null
                   references public.chat_conversations(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  sender          text not null check (sender in ('user','assistant')),
  content         text not null,
  normalized      jsonb,
  asked_handoff   boolean not null default false,
  created_at      timestamptz not null default now()
);

create index if not exists chat_messages_conv_time_idx
  on public.chat_messages(conversation_id, created_at);

create index if not exists chat_messages_user_idx
  on public.chat_messages(user_id, created_at desc);

-- ------------------------------------------------------------
-- 3) RLS policies — 自己只看得到自己的對話；諮詢師可以看 case
-- ------------------------------------------------------------
alter table public.chat_conversations enable row level security;
drop policy if exists chat_conversations_self_all on public.chat_conversations;
create policy chat_conversations_self_all on public.chat_conversations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.chat_messages enable row level security;
drop policy if exists chat_messages_owner_select on public.chat_messages;
create policy chat_messages_owner_select on public.chat_messages
  for select using (
    auth.uid() = user_id
    or coalesce(public.is_counselor(), false)
  );

drop policy if exists chat_messages_owner_write on public.chat_messages;
create policy chat_messages_owner_write on public.chat_messages
  for insert with check (auth.uid() = user_id);

drop policy if exists chat_messages_owner_update on public.chat_messages;
create policy chat_messages_owner_update on public.chat_messages
  for update using (auth.uid() = user_id);

drop policy if exists chat_messages_owner_delete on public.chat_messages;
create policy chat_messages_owner_delete on public.chat_messages
  for delete using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 4) Grants — authenticated 全 CRUD（被 RLS 守住）
-- ------------------------------------------------------------
grant select, insert, update, delete
  on public.chat_conversations, public.chat_messages
  to authenticated;

-- ------------------------------------------------------------
-- 5) （安全備援）以前如果用 newId('c_xxxx') 試插過 chat_*，
--    那些 row 會因為 id 不是合法 uuid 而塞不進來。
--    這裡不做任何 delete / migration —— 若你想清空舊資料：
--      truncate public.chat_messages, public.chat_conversations;
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 6) 通知 PostgREST 重新 load schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
