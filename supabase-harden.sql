-- ============================================================
-- LX集 · 生活工作台 —— 数据加固补丁
-- 用法：Supabase 后台 → SQL Editor → 全选粘贴 → Run
--
-- 作用：把「任何人拿到链接就能读写全部数据」改成
--      「请求头必须带正确口令才能读写」。
-- 口令不写在代码仓库里，只存在你自己设备的浏览器缓存 / 书签链接里。
-- ============================================================

-- ------------------------------------------------------------
-- 1. 口令校验函数（PostgREST 会把请求头塞进这个 GUC）
--    下面的口令请换成你自己的，改完页面也要用同一个
-- ------------------------------------------------------------
create or replace function public.app_key_ok() returns boolean
  language sql stable
  as $$
    select coalesce(current_setting('request.headers', true)::json ->> 'x-app-key', '')
         = '0ac9bd3f6a9fe6c48c8e5edc122c9bec253205b0';
  $$;

grant execute on function public.app_key_ok() to anon;

-- ------------------------------------------------------------
-- 2. 清掉旧的"放行所有人"策略
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'money_records','schedules','habit_logs',
        'fitness_logs','shopping_items','media_items','app_settings')
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 3. 换成"必须带口令"的策略
-- ------------------------------------------------------------
create policy app_key_rw on public.money_records
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

create policy app_key_rw on public.schedules
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

create policy app_key_rw on public.habit_logs
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

create policy app_key_rw on public.fitness_logs
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

create policy app_key_rw on public.shopping_items
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

create policy app_key_rw on public.media_items
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

create policy app_key_rw on public.app_settings
  for all to anon using (public.app_key_ok()) with check (public.app_key_ok());

-- ------------------------------------------------------------
-- 4. 自检：7 张表都应该是 app_key_rw
-- ------------------------------------------------------------
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename;
