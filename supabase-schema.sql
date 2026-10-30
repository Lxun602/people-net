-- ============================================================
-- LX集 · 生活工作台 —— Supabase 数据库结构（补丁版）
-- 用法：Supabase 后台 → SQL Editor → 全选粘贴 → Run
-- 说明：可重复执行。6 张业务表已存在，本脚本只做"补全"，不删任何数据。
-- ============================================================

-- ------------------------------------------------------------
-- 1. 待买清单：数量改为文本，才能存 "2 盒" 这种带单位的写法
-- ------------------------------------------------------------
alter table public.shopping_items
  alter column "数量" type text using "数量"::text;

-- ------------------------------------------------------------
-- 2. 习惯打卡：同一天 + 同一个习惯 只允许一行（页面用 upsert 更新）
-- ------------------------------------------------------------
alter table public.habit_logs drop constraint if exists habit_logs_date_name_key;
alter table public.habit_logs add constraint habit_logs_date_name_key unique ("日期", "习惯");

-- ------------------------------------------------------------
-- 3. 设置表：存预算、外观、自定义习惯、周计划（跨设备同步用）
--    只有一行，id = 'default'
-- ------------------------------------------------------------
create table if not exists public.app_settings (
  id          text primary key,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.app_settings enable row level security;

drop policy if exists "anon_all_app_settings" on public.app_settings;
create policy "anon_all_app_settings"
  on public.app_settings
  for all
  to anon
  using (true)
  with check (true);

grant select, insert, update, delete on public.app_settings to anon;

-- ------------------------------------------------------------
-- 4. 常用查询字段加索引
-- ------------------------------------------------------------
create index if not exists money_records_date_idx    on public.money_records ("日期");
create index if not exists schedules_date_idx        on public.schedules ("日期");
create index if not exists habit_logs_date_idx       on public.habit_logs ("日期");
create index if not exists fitness_logs_date_idx     on public.fitness_logs ("日期");

-- ------------------------------------------------------------
-- 5. 自检：应该列出 7 张表
-- ------------------------------------------------------------
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
