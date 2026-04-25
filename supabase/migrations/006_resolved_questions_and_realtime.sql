-- ============================================================
-- 006_resolved_questions_and_realtime.sql
-- ============================================================
-- 用途：
--   1) 在 normalized_questions 加上「已解決」相關欄位 ——
--      backend 在 KB 命中且 LLM 回覆與 KB 既有答案夠像時，
--      會把該題以 resolved = true 寫入。tags 也會自動補上「已解決」。
--   2) 把 chat_messages 加進 supabase_realtime publication，
--      Flutter 端才能訂閱 INSERT 事件做即時刷新。
--
-- 整段可重跑（idempotent）。在 Supabase Dashboard → SQL Editor 貼上 → Run。
-- ============================================================

-- ------------------------------------------------------------
-- 1) normalized_questions 補欄位
-- ------------------------------------------------------------
alter table public.normalized_questions
  add column if not exists resolved          boolean       not null default false,
  add column if not exists resolved_reason   text          not null default '',
  add column if not exists answer_score      numeric(4,3)  not null default 0,
  add column if not exists closest_kb_answer text          not null default '';

comment on column public.normalized_questions.resolved is
  '若 KB 已有相似問題且 LLM 回答也跟 KB 既有答案夠像（answer_score >= 0.45），';
comment on column public.normalized_questions.answer_score is
  'LLM 回答 vs KB 對應 chunk 文字的相似度（0..1）。';
comment on column public.normalized_questions.closest_kb_answer is
  '最相似 KB chunk 的前 600 字快照（讓諮詢師不用再去翻 KB）。';

-- 諮詢師最常用的查詢：先看「沒解決」的、依時間排序
create index if not exists normalized_questions_resolved_idx
  on public.normalized_questions(resolved, created_at desc);

-- ------------------------------------------------------------
-- 2) （安全）打開 chat_messages 的 realtime
--    publication 已被 supabase 預先建好（supabase_realtime）。
--    重複 ALTER 會 noop，這裡用 DO 區塊判斷一下。
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'chat_messages'
  ) then
    execute 'alter publication supabase_realtime add table public.chat_messages';
  end if;
end $$;

-- ------------------------------------------------------------
-- 3) Realtime 需要 row 上有完整 OLD/NEW —— 對 chat_messages 補保險
--    （Supabase 預設 REPLICA IDENTITY 為 default，多數情況夠用；
--     若想連 update / delete 也能拿到完整 row，可以打開 FULL。
--     這裡選 DEFAULT 不額外開銷，只訂閱 INSERT 已足夠。）
-- ------------------------------------------------------------
-- alter table public.chat_messages replica identity default;

-- ------------------------------------------------------------
-- 4) reload PostgREST schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
