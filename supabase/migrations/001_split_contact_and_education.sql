-- ============================================================
-- 001_split_contact_and_education.sql
-- ============================================================
-- 用途：把舊版 schema 的 profiles 表升級成新版：
--   1. contact (text) → email (text) + phone (text)
--   2. education_items (text[]) → education_items (jsonb)，
--      內容變成 [{school, department, grade}, ...]
--
-- 在 Supabase Dashboard → SQL Editor 整段貼上跑一次即可。
-- 全部 idempotent — 已經跑過就會跳過。
-- ============================================================

-- 1) 新增 email / phone 欄位（先給空字串 default 以免現有資料卡住 not null）
alter table public.profiles
  add column if not exists email text not null default '',
  add column if not exists phone text not null default '';

-- 2) 把舊資料的 contact 搬進 email（best-effort：當 email 還是空時才搬）
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'profiles'
      and column_name  = 'contact'
  ) then
    update public.profiles
       set email = contact
     where email = ''
       and contact is not null
       and contact <> '';
  end if;
end $$;

-- 3) 刪掉舊的 contact 欄位
alter table public.profiles
  drop column if exists contact;

-- 4) education_items：text[] → jsonb
--    舊資料每筆字串會被解析為 {"school":..., "department":..., "grade":...}
do $$
declare
  col_type text;
begin
  select data_type into col_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name   = 'profiles'
    and column_name  = 'education_items';

  if col_type = 'ARRAY' then
    -- 開一個臨時 jsonb 欄位
    alter table public.profiles
      add column if not exists education_items_new jsonb not null default '[]'::jsonb;

    -- 把每一筆 text 拆成 {school, department, grade}
    update public.profiles
       set education_items_new = coalesce(
         (
           select jsonb_agg(
             jsonb_build_object(
               'school',     coalesce(parts[1], ''),
               'department', coalesce(parts[2], ''),
               'grade',      coalesce(array_to_string(parts[3:array_length(parts,1)], ' '), '')
             )
           )
           from (
             select regexp_split_to_array(item, E'[\\s・·\\|/，,]+') as parts
             from unnest(education_items) as item
             where item is not null and item <> ''
           ) s
         ),
         '[]'::jsonb
       );

    alter table public.profiles drop column education_items;
    alter table public.profiles
      rename column education_items_new to education_items;
  end if;
end $$;

-- 5) 提示 PostgREST 重新 load schema cache（Supabase 通常自己會抓，
--    但跑完後 30 秒內仍 cache miss 就強制 reload）
notify pgrst, 'reload schema';
