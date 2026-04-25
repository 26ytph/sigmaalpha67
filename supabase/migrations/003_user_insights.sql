-- ============================================================
-- 003_user_insights.sql
-- ============================================================
-- 用途：每位使用者一份 AI 整理過的「問題定位 + 屬性」彙總，
--      由後端定期讀對話歷史 + Profile + Persona，丟給 Gemini 整理出來，
--      供諮詢師快速接手。
--
-- 一個 user 一份 row（rolling profile，不是每段對話一份）。
-- 在 Supabase Dashboard → SQL Editor 整段貼上即可。
-- 全部 idempotent。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) user_insights table
-- ------------------------------------------------------------
create table if not exists public.user_insights (
  user_id              uuid primary key
                        references auth.users(id) on delete cascade,

  -- 一段話的問題定位（給諮詢師看的「這個人到底卡在哪」）
  problem_positioning  text not null default '',

  -- 問題類別 tag（職涯探索 / 履歷協助 / 面試準備 / 創業諮詢 / 心理支持 / ...）
  categories           text[] not null default '{}',

  -- 情緒輪廓（焦慮、想釐清、有動能、信心不足...）
  emotion_profile      text not null default '',

  -- 使用者具體提到的事（公司、產業、技能、deadline）
  specific_concerns    text[] not null default '{}',

  -- 已嘗試過的事（投了哪些履歷、上過什麼課、試過哪些方法）
  tried_approaches     text[] not null default '{}',

  -- 卡關點（無回音、不知道怎麼開始、家人壓力...）
  blockers             text[] not null default '{}',

  -- 推薦諮詢師切入點（一上來談什麼最有效）
  recommended_topics   text[] not null default '{}',

  -- 諮詢優先級：低 / 中 / 中高 / 高
  priority             text not null default '中'
                        check (priority in ('低','中','中高','高')),

  -- 額外標籤（給 dashboard 篩選用：應屆生、轉職、家裡反對、技能轉換...）
  tags                 text[] not null default '{}',

  -- AI 完整摘要（給 counselor 看一段更完整的描述）
  raw_summary          text not null default '',

  -- 這次分析用了幾則訊息
  message_count        integer not null default 0,

  -- AI provider 名（gemini-2.5-flash / fallback / heuristic）
  generated_by         text not null default '',

  -- 諮詢師寫的備註（手動 override）
  counselor_note       text not null default '',

  generated_at         timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

drop trigger if exists user_insights_touch on public.user_insights;
create trigger user_insights_touch before update on public.user_insights
  for each row execute function public.touch_updated_at();

create index if not exists user_insights_priority_idx
  on public.user_insights(priority, generated_at desc);

-- ------------------------------------------------------------
-- 2) RLS：使用者讀自己的；諮詢師讀全部
-- ------------------------------------------------------------
alter table public.user_insights enable row level security;

drop policy if exists user_insights_self_read on public.user_insights;
create policy user_insights_self_read on public.user_insights
  for select using (
    auth.uid() = user_id
    or coalesce(public.is_counselor(), false)
  );

-- 一般使用者不能直接寫入這張表（資料應該由 backend 用 service role 寫）；
-- 諮詢師可以更新 counselor_note。
drop policy if exists user_insights_counselor_update on public.user_insights;
create policy user_insights_counselor_update on public.user_insights
  for update using (coalesce(public.is_counselor(), false));

-- ------------------------------------------------------------
-- 3) Grants — authenticated 可以讀；UPDATE 只給 counselor（用 RLS 守）
-- ------------------------------------------------------------
grant select on public.user_insights to authenticated;
grant update on public.user_insights to authenticated;

-- ------------------------------------------------------------
-- 4) reload PostgREST schema cache
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
