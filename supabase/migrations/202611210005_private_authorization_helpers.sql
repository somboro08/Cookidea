-- Keep SECURITY DEFINER authorization helpers out of the exposed public schema.
begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_project_member(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = target_project_id and p.owner_id = (select auth.uid())
  )
  or exists (
    select 1 from public.project_members pm
    where pm.project_id = target_project_id and pm.user_id = (select auth.uid())
  );
$$;

create or replace function private.can_edit_project(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = target_project_id and p.owner_id = (select auth.uid())
  )
  or exists (
    select 1 from public.project_members pm
    where pm.project_id = target_project_id
      and pm.user_id = (select auth.uid())
      and pm.role = 'editor'
  );
$$;

grant execute on function private.is_project_member(uuid) to authenticated;
grant execute on function private.can_edit_project(uuid) to authenticated;

do $$
declare
  p record;
  using_clause text;
  check_clause text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        coalesce(qual, '') like '%is_project_member(%'
        or coalesce(qual, '') like '%can_edit_project(%'
        or coalesce(with_check, '') like '%is_project_member(%'
        or coalesce(with_check, '') like '%can_edit_project(%'
      )
  loop
    using_clause := '';
    check_clause := '';
    if p.qual is not null then
      using_clause := ' USING (' ||
        replace(replace(p.qual, 'is_project_member(', 'private.is_project_member('),
          'can_edit_project(', 'private.can_edit_project(') || ')';
    end if;
    if p.with_check is not null then
      check_clause := ' WITH CHECK (' ||
        replace(replace(p.with_check, 'is_project_member(', 'private.is_project_member('),
          'can_edit_project(', 'private.can_edit_project(') || ')';
    end if;
    execute format('alter policy %I on %I.%I%s%s',
      p.policyname, p.schemaname, p.tablename, using_clause, check_clause);
  end loop;
end;
$$;

revoke all on function public.is_project_member(uuid) from public, anon, authenticated;
revoke all on function public.can_edit_project(uuid) from public, anon, authenticated;
drop function public.is_project_member(uuid);
drop function public.can_edit_project(uuid);

commit;
