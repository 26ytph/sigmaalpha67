-- ============================================================
-- 009_question_topics.sql
-- ============================================================
-- 用途：把同一個使用者「相同 / 類似主題、AI 沒能直接解決」的問題群組成一個
--       Topic，讓諮詢師端不再看 raw 對話流，而是看一個個 Topic 卡：
--
--       Topic 卡 ──┐
--                  ├─ Q1（user 訊息 + AI 暫時回覆）
--                  ├─ Q2（user 訊息 + AI 暫時回覆）
--                  └─ ...
--
--       諮詢師對整個 Topic 一次回覆 + 一次按「問題解決」，
--       AI 才會把整個 Topic 整理進 counselor_faqs（不含 AI 暫時回覆），
--       下次同主題能直接由 RAG 命中。
--
-- 前置條件：004（normalized_questions）、008（counselor_faqs）已 run。
-- Idempotent。在 Supabase Dashboard → SQL Editor 整段貼上 → Run。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) question_topics
-- ------------------------------------------------------------
create table if not exists public.question_topics (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null
                    references auth.users(id) on delete cascade,
  -- AI 短標題（2-12 字），ex: 履歷格式問題、轉職焦慮、創業申請補助
  title           text not null default '',
  -- AI 長一點的脈絡摘要，給諮詢師 review 用
  summary         text not null default '',
  -- 把所有成員問題的文字串接起來（給未來新進問題做相似度比對；不用回顯 UI）
  centroid_text   text not null default '',
  status          text not null default 'pending'
                    check (status in ('pending', 'resolved')),
  resolved_by     uuid
                    references auth.users(id) on delete set null,
  resolved_at     timestamptz,
  -- 解決後 push 進 KB 的 counselor_faqs.id（建立鏈結，後續想 audit 可回查）
  kb_source_id    text,
  question_count  integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists question_topics_user_status_idx
  on public.question_topics(user_id, status, updated_at desc);

create index if not exists question_topics_status_idx
  on public.question_topics(status, updated_at desc);

comment on table public.question_topics is
  '同一使用者、類似主題且 AI 沒解決的問題群組。諮詢師端針對 Topic 整批回覆 + 標解決。';

-- ------------------------------------------------------------
-- 2) normalized_questions 加 topic_id FK
-- ------------------------------------------------------------
alter table public.normalized_questions
  add column if not exists topic_id uuid
    references public.question_topics(id) on delete set null;

create index if not exists normalized_questions_topic_idx
  on public.normalized_questions(topic_id);

-- ------------------------------------------------------------
-- 3) RLS：諮詢師 read 全部、user 只 read 自己的；寫只走 service_role。
-- ------------------------------------------------------------
alter table public.question_topics enable row level security;

drop policy if exists question_topics_self_read on public.question_topics;
create policy question_topics_self_read on public.question_topics
  for select using (
    auth.uid() = user_id
    or coalesce(public.is_counselor(), false)
  );

grant select on public.question_topics to authenticated;

-- ------------------------------------------------------------
-- 4) reload PostgREST schema
-- ------------------------------------------------------------
notify pgrst, 'reload schema';

-- ============================================================
-- （選用）資料庫小幅整理 — 如不需要可整段跳過。
-- ============================================================
-- 4a) chat_messages.normalized JSONB 已被 by_counselor / asked_handoff 取代，
--     若你確認沒有外部讀取者再跑下面這行。預設留空。
-- alter table public.chat_messages drop column if exists normalized;

-- 4b) normalized_questions.closest_kb_answer 字串大、實務上幾乎不被讀，
--     若你想瘦身可改存 hash 或直接 drop。預設留空。
-- alter table public.normalized_questions drop column if exists closest_kb_answer;
