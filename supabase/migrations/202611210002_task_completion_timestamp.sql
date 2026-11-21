-- Keep completed_at consistent when a task changes state.
create or replace function public.sync_project_task_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'done' then
    if new.completed_at is null then new.completed_at := now(); end if;
  else
    new.completed_at := null;
  end if;
  return new;
end;
$$;

create trigger project_tasks_sync_completion
before insert or update of status, completed_at on public.project_tasks
for each row execute function public.sync_project_task_completion();
