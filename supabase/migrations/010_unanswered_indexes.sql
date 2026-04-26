-- ============================================================
-- 010_unanswered_indexes.sql
-- ============================================================
-- 用途：諮詢師後台會在「個案列表」「主題卡」上顯示「未回題數」徽章。
--      backend 是用兩段 query + JS aggregate 算出來的（ListAllUsersForCounselor /
--      listUserTopics），不需要新欄位。但量大後可加索引讓 JSONB 查詢快一些。
--
-- 整段可重跑（idempotent）。Supabase Dashboard → SQL Editor 貼上 → Run。
-- ============================================================

-- ------------------------------------------------------------
-- 1) chat_messages 中諮詢師回覆的 normalized.reply_to_message_id 查詢加速
-- ------------------------------------------------------------
-- 現有：chat_messages_by_counselor_idx (conversation_id, created_at desc)
-- 現補：JSONB key 取出來建索引，回覆比對「哪些 user_msg 已被回」會快一個量級。
create index if not exists chat_messages_reply_to_msg_idx
  on public.chat_messages (((normalized->>'reply_to_message_id')))
  where by_counselor = true
    and (normalized->>'reply_to_message_id') is not null;

-- ------------------------------------------------------------
-- 2) normalized_questions.message_id 索引（給 IN (...) lookup 用）
-- ------------------------------------------------------------
create index if not exists normalized_questions_message_idx
  on public.normalized_questions (message_id)
  where message_id is not null;

-- ------------------------------------------------------------
-- 3) （選用）用 view 把「per user 未回題數」一次算出來。
--      程式內目前用 JS 聚合，這個 view 留給未來想做 dashboard / analytics
--      時用 — backend 不依賴它，沒 view 也能跑。
-- ------------------------------------------------------------
create or replace view public.v_unanswered_per_user as
with answered as (
  select distinct (cm.normalized->>'reply_to_message_id') as message_id
    from public.chat_messages cm
   where cm.by_counselor = true
     and (cm.normalized->>'reply_to_message_id') is not null
)
select
  qt.user_id,
  count(*) filter (where a.message_id is null) as unanswered_count
  from public.question_topics qt
  join public.normalized_questions nq on nq.topic_id = qt.id
  left join answered a on a.message_id = nq.message_id
 where qt.status = 'pending'
   and nq.message_id is not null
 group by qt.user_id;

comment on view public.v_unanswered_per_user is
  '每個 user 在 pending 主題下的未回題數。給諮詢師端徽章 / dashboard 用。';

-- 給 authenticated 讀（被 RLS 守住）
grant select on public.v_unanswered_per_user to authenticated;

-- ------------------------------------------------------------
-- 4) reload PostgREST schema
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
