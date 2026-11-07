-- ============================================================
-- LX集 · 多账号隔离改造
-- 用法：Supabase 后台 → SQL Editor → 全选粘贴 → Run
--
-- 做什么：每个登录账号只读写自己的数据行，由数据库强制，前端绕不过去。
--        每个账号自动生成一串专属口令，页面登录后自动取来填，不用手输。
--        首次登录自动建好这个账号的数据空间。
--
-- 前提：先在 Supabase 后台 → Authentication → Providers 打开 Email，
--       URL Configuration 里把 Site URL 填成 https://llxcad.cn
--
-- 注意：本脚本不删除任何现有数据。旧数据由第一个登录的账号一次性认领。
--       跑之前建议先在 Table Editor 里看一眼数据，心里有数。
-- ============================================================

-- ------------------------------------------------------------
-- 1. 7 张业务表加一列：这条数据属于谁
-- ------------------------------------------------------------
do $$
declare t text;
begin
  for t in select unnest(array[
    'money_records','schedules','habit_logs','fitness_logs',
    'shopping_items','media_items','app_settings'
  ]) loop
    execute format('alter table public.%I add column if not exists user_id uuid references auth.users(id) on delete cascade', t);
    execute format('create index if not exists %I on public.%I (user_id)', t || '_user_idx', t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2. 账号专属口令表（一行 = 一个账号）
-- ------------------------------------------------------------
create table if not exists public.user_spaces (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  app_key    text not null,
  created_at timestamptz not null default now()
);
alter table public.user_spaces enable row level security;

-- ------------------------------------------------------------
-- 3. 新账号注册时，自动建好专属口令 + 一行空设置
--    （app_settings 的主键是 id text，用 'u-账号id' 当 id，不用改主键）
-- ------------------------------------------------------------
create or replace function public.on_user_created() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.user_spaces (user_id, app_key)
  values (new.id, encode(gen_random_bytes(24), 'hex'))
  on conflict (user_id) do nothing;

  insert into public.app_settings (id, user_id, data)
  values ('u-' || new.id::text, new.id, '{}'::jsonb)
  on conflict (id) do nothing;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.on_user_created();

-- ------------------------------------------------------------
-- 4. 校验函数：请求头里的口令，必须等于「当前登录账号」的口令
--    security definer 只为读口令表；身份仍取自登录令牌，冒充不了
-- ------------------------------------------------------------
create or replace function public.app_key_ok() returns boolean
  language sql stable security definer set search_path = public as $$
    select exists (
      select 1 from public.user_spaces s
      where s.user_id = auth.uid()
        and s.app_key = coalesce(
          current_setting('request.headers', true)::json ->> 'x-app-key', '')
    );
  $$;

-- ------------------------------------------------------------
-- 5. 登录后的页面调这个拿自己的口令（自动填，不用手输）
-- ------------------------------------------------------------
create or replace function public.my_app_key() returns text
  language sql stable security definer set search_path = public as $$
    select app_key from public.user_spaces where user_id = auth.uid();
  $$;

-- ------------------------------------------------------------
-- 6. 口令缺失 / 老账号补建空间：一次性认领旧数据，返回口令
--    旧数据（user_id 为空）归第一个登录的账号，之后没人能再认领
-- ------------------------------------------------------------
create or replace function public.ensure_my_space() returns text
  language plpgsql security definer set search_path = public as $$
declare
  uid_ uuid; k text; t text;
begin
  uid_ := auth.uid();
  if uid_ is null then raise exception 'not signed in'; end if;

  select app_key into k from public.user_spaces where user_id = uid_;
  if k is null then
    k := encode(gen_random_bytes(24), 'hex');
    insert into public.user_spaces (user_id, app_key) values (uid_, k);
  end if;

  -- 认领旧数据：只认领还没归属的
  for t in select unnest(array[
    'money_records','schedules','habit_logs','fitness_logs',
    'shopping_items','media_items'
  ]) loop
    execute format('update public.%I set user_id = $1 where user_id is null', t) using uid_;
  end loop;

  insert into public.app_settings (id, user_id, data)
  values ('u-' || uid_::text, uid_, '{}'::jsonb)
  on conflict (id) do nothing;

  return k;
end $$;

-- ------------------------------------------------------------
-- 7. 清掉旧的「任何人可读写」策略，换成「只能碰自己的行」
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'money_records','schedules','habit_logs','fitness_logs',
        'shopping_items','media_items','app_settings')
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

do $$
declare t text;
begin
  for t in select unnest(array[
    'money_records','schedules','habit_logs','fitness_logs',
    'shopping_items','media_items','app_settings'
  ]) loop
    execute format(
      'create policy own_rows on public.%I for all to authenticated '
      || 'using (user_id = auth.uid() and public.app_key_ok()) '
      || 'with check (user_id = auth.uid() and public.app_key_ok())', t);
  end loop;
end $$;

-- 口令表本身不开放直接读写，只能通过上面几个函数
grant usage on schema public to authenticated;
grant select, insert, update, delete on
  public.money_records, public.schedules, public.habit_logs,
  public.fitness_logs, public.shopping_items, public.media_items,
  public.app_settings to authenticated;

grant execute on function public.app_key_ok()     to anon, authenticated;
grant execute on function public.my_app_key()    to authenticated;
grant execute on function public.ensure_my_space() to authenticated;

-- ------------------------------------------------------------
-- 8. 自检：应该看到 7 张表都是 own_rows
-- ------------------------------------------------------------
select tablename, policyname, roles
from pg_policies
where schemaname = 'public'
order by tablename;
