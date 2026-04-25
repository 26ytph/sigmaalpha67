-- ============================================================
-- 008_counselor_faqs.sql
-- ============================================================
-- 用途：把諮詢師回答過的 Q&A 持久化到 Supabase。
--
--   背景：先前 counselor reply 路徑只把 Q&A 推到 in-memory KB
--         （rag.ts 的 store.knowledgeSources / chunks）。
--         Next.js serverless cold start 或重啟就會掉，下次同樣的問題
--         RAG 又找不到，使用者會聽到 AI 說「不太清楚」。
--
--   解法：開一張 public.counselor_faqs，counselor reply 時 upsert，
--         chat route 在每次 RAG 之前用短 TTL 把這張表載入 in-memory KB。
--
-- Idempotent。在 Supabase Dashboard → SQL Editor 整段貼上 → Run。
-- ============================================================

create table if not exists public.counselor_faqs (
  id          text primary key,
  question    text not null,
  answer      text not null,
  tags        text[] not null default '{}',
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists counselor_faqs_updated_idx
  on public.counselor_faqs(updated_at desc);

create index if not exists counselor_faqs_tags_gin_idx
  on public.counselor_faqs using gin(tags);

comment on table public.counselor_faqs is
  '諮詢師回過的問答；chat route 啟動時載入 in-memory KB，後續 RAG 自動可命中。';
comment on column public.counselor_faqs.id is
  '穩定 key（例如 case_faq_<caseId> 或 case_faq_msg_<msgId>）。同題重送會 update。';

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.counselor_faqs enable row level security;

-- 所有登入使用者都能讀（chat 路徑要把 FAQ 灌進 RAG，user 端也會間接「讀到」內容）。
drop policy if exists counselor_faqs_read on public.counselor_faqs;
create policy counselor_faqs_read on public.counselor_faqs
  for select using (true);

-- 寫入只走 service_role（backend）。不開 insert / update / delete 給 authenticated。

grant select on public.counselor_faqs to authenticated;

-- ------------------------------------------------------------
-- reload PostgREST schema
-- ------------------------------------------------------------
notify pgrst, 'reload schema';
