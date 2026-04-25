-- ============================================================
-- 007_chat_by_counselor.sql
-- ============================================================
-- 用途：
--   1) chat_messages 加上 `by_counselor boolean` 欄位 ——
--      諮詢師透過 PUT /api/counselor/cases/{caseId}/reply 回覆時，
--      backend 會把回覆寫進 chat_messages 並把這個欄位設為 true，
--      Flutter 端 realtime 收到後就能渲染「諮詢師回覆」徽章。
--   2) 確認 chat_messages 已加進 supabase_realtime publication
--      （006 已經做過；這裡再 idempotent 跑一次當保險）。
--   3) 提供一段 SELECT 讓你 Run 完之後可以「自我檢查」publication 是否生效。
--
-- 整段可重跑（idempotent）。在 Supabase Dashboard → SQL Editor 貼上 → Run。
-- ============================================================

-- ------------------------------------------------------------
-- 1) chat_messages.by_counselor
-- ------------------------------------------------------------
alter table public.chat_messages
  add column if not exists by_counselor boolean not null default false;

comment on column public.chat_messages.by_counselor is
  'true 代表這則 sender=assistant 的訊息其實是真人諮詢師回覆（透過 case reply）。';

create index if not exists chat_messages_by_counselor_idx
  on public.chat_messages(conversation_id, created_at desc)
  where by_counselor = true;

-- ------------------------------------------------------------
-- 2) （保險）確認 chat_messages 在 supabase_realtime publication 裡
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
-- 3) 自我檢查 — Run 完之後手動跑這段，應該都要出現一行
--    （Dashboard 會把 SELECT 結果列出來）
-- ------------------------------------------------------------
-- select schemaname, tablename
--   from pg_publication_tables
--  where pubname = 'supabase_realtime'
--    and schemaname = 'public'
--    and tablename = 'chat_messages';
--
-- select column_name, data_type
--   from information_schema.columns
--  where table_schema = 'public'
--    and table_name   = 'chat_messages'
--    and column_name  = 'by_counselor';

-- ------------------------------------------------------------
-- 4) reload PostgREST schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
