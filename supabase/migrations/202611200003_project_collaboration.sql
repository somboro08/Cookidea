-- Cookidea collaboration: member directory access is mediated by an authenticated Edge Function.
begin;

drop policy if exists "Project members can view membership" on public.project_members;
create policy "Project members can view membership"
on public.project_members for select
to authenticated
using (public.is_project_member(project_id));

grant select on public.project_members to authenticated;
grant select on public.profiles to authenticated;

commit;
