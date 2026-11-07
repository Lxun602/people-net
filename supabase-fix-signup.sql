-- ============================================================
-- 修复：注册时报错 "Database error saving new user"
-- 用法：Supabase 后台 → SQL Editor → New query → 全选粘贴 → Run
-- 可重复执行，不动任何现有数据。
--
-- 改了两处：
-- 1. 生成随机口令改用数据库自带的 gen_random_uuid()（内置函数，不依赖额外扩展）。
--    数据库里已有记录的 id 就是这个函数生成的，所以它一定可用。
-- 2. 给「注册后自动建空间」加保险：万一建空间失败，也不再拖垮注册。
--    空间没建好，页面登录后会用 ensure_my_space() 自己补建。
-- ============================================================

-- 兜底：缺表 / 缺列时补齐（已经跑过脚本则什么都不会做）
create table if not exists public.user_spaces (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  app_key    text not null,
  created_at timestamptz not null default now()
);
alter table public.user_spaces enable row level security;
alter table public.app_settings add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- ---------- 1. 注册触发器：改成"失败也不影响注册" ----------
create or replace function public.on_user_created() returns trigger
  language plpgsql security definer set search_path = public, pg_catalog as $$
declare
  k text;
begin
  begin
    k := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    insert into public.user_spaces (user_id, app_key)
      values (new.id, k)
      on conflict (user_id) do nothing;

    insert into public.app_settings (id, user_id, data)
      values ('u-' || new.id::text, new.id, '{}'::jsonb)
      on conflict (id) do nothing;
  exception when others then
    -- 只记一条警告，绝不抛出去打断注册
    raise warning 'auto space skipped: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.on_user_created();

-- ---------- 2. 补建空间的函数：同样换掉随机串写法 ----------
create or replace function public.ensure_my_space() returns text
  language plpgsql security definer set search_path = public, pg_catalog as $$
declare
  uid_ uuid; k text; t text;
begin
  uid_ := auth.uid();
  if uid_ is null then raise exception 'not signed in'; end if;

  select app_key into k from public.user_spaces where user_id = uid_;
  if k is null then
    k := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    insert into public.user_spaces (user_id, app_key) values (uid_, k);
  end if;

  -- 旧数据（还没归属的）归第一个登录的账号，之后没人能再认领
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

grant execute on function public.ensure_my_space() to authenticated;
grant execute on function public.my_app_key()   to authenticated;
grant execute on function public.app_key_ok()   to anon, authenticated;

-- ---------- 3. 自检：应该列出触发器与三个函数 ----------
select tgname, tgenabled from pg_trigger where tgrelid = 'auth.users'::regclass and not tgisinternal;
