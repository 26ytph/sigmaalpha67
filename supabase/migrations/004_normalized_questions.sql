-- ============================================================
-- 004_normalized_questions.sql
-- ============================================================
-- 用途：把使用者每次提問經 AI 整理後的「正規化問題摘要」存起來，
--      但**只存「不在既有 RAG 知識庫中」的新問題**（去重）。
--      用來給諮詢師看「使用者實際在問哪些 FAQ 還沒覆蓋的問題」。
--
-- 同時：tags 累積在 public.user_insights.tags（不另開表）。
--
-- 在 Supabase Dashboard → SQL Editor 整段貼上即可。Idempotent。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) normalized_questions
-- ------------------------------------------------------------
create table if not exists public.normalized_questions (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid not null
                       references auth.users(id) on delete cascade,
  conversation_id     uuid
                       references public.chat_conversations(id) on delete set null,
  message_id          uuid
                       references public.chat_messages(id) on delete set null,

  -- 使用者實際打的字
  raw_question        text not null,

  -- AI 整理後的「一句話正規化問題」（諮詢師最快瞄一眼的）
  normalized_text     text not null default '',

  -- 結構化欄位 — 跟 chat NormalizedQuestion 對齊
  intents             text[] not null default '{}',
  emotion             text not null default '',
  known_info          text[] not null default '{}',
  missing_info        text[] not null default '{}',
  urgency             text not null default '中'
                       check (urgency in ('低','中','中高','高')),
  -- 給諮詢師看 3–5 句的摘要
  counselor_summary   text not null default '',

  -- 從 AI 抽出的 tag（也會被 append 到 user_insights.tags）
  tags                text[] not null default '{}',

  -- 去重判定
  -- 0.0 = 完全沒命中 KB；1.0 = 跟 KB 高度相似。低於閾值才會被存。
  novelty_score       numeric(4,3) not null default 0,
  closest_kb_title    text not null default '',
  closest_kb_score    numeric(4,3) not null default 0,
  threshold_used      numeric(4,3) not null default 0.5,

  generated_by        text not null default '',
  created_at          timestamptz not null default now()
);

create index if not exists normalized_questions_user_idx
  on public.normalized_questions(user_id, created_at desc);

create index if not exists normalized_questions_urgency_idx
  on public.normalized_questions(urgency, created_at desc);

create index if not exists normalized_questions_intents_gin_idx
  on public.normalized_questions using gin (intents);

create index if not exists normalized_questions_tags_gin_idx
  on public.normalized_questions using gin (tags);

-- ------------------------------------------------------------
-- 2) RLS：使用者讀自己的；諮詢師讀全部
-- ------------------------------------------------------------
alter table public.normalized_questions enable row level security;

drop policy if exists normalized_questions_self_read
  on public.normalized_questions;
create policy normalized_questions_self_read
  on public.normalized_questions
  for select using (
    auth.uid() = user_id or coalesce(public.is_counselor(), false)
  );

-- 一般使用者不能寫；資料應該從 backend service_role 寫入。
-- 諮詢師沒有 update 需求（這張表純記錄）；之後若要加備註可改 schema。

-- ------------------------------------------------------------
-- 3) Grants — authenticated 可讀（被 RLS 守住）
-- ------------------------------------------------------------
grant select on public.normalized_questions to authenticated;

-- ------------------------------------------------------------
-- 4) reload PostgREST schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
