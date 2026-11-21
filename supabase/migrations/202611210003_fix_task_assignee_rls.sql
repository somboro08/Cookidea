-- Fix assignee membership checks: explicitly correlate membership to the task's project.
drop policy if exists "Editors can create tasks" on public.project_tasks;
create policy "Editors can create tasks"
on public.project_tasks for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.can_edit_project(project_id)
  and (
    assignee_id is null
    or assignee_id = (select p.owner_id from public.projects p where p.id = project_tasks.project_id)
    or exists (
      select 1 from public.project_members pm
      where pm.project_id = project_tasks.project_id
        and pm.user_id = project_tasks.assignee_id
    )
  )
);

drop policy if exists "Editors can update tasks" on public.project_tasks;
create policy "Editors can update tasks"
on public.project_tasks for update
to authenticated
using (public.can_edit_project(project_id))
with check (
  public.can_edit_project(project_id)
  and (
    assignee_id is null
    or assignee_id = (select p.owner_id from public.projects p where p.id = project_tasks.project_id)
    or exists (
      select 1 from public.project_members pm
      where pm.project_id = public.project_tasks.project_id
        and pm.user_id = public.project_tasks.assignee_id
    )
  )
);
