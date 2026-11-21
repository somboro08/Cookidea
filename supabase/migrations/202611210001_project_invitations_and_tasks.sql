-- Cookidea: project invitations and assignable tasks
begin;

create type public.project_task_status as enum ('todo', 'in_progress', 'done', 'cancelled');
create type public.project_task_priority as enum ('low', 'normal', 'high', 'urgent');

create table public.project_invitations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  email text not null check (email = lower(trim(email))),
  role public.project_member_role not null check (role in ('editor', 'viewer')),
  token_hash text not null unique,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'revoked', 'expired')),
  invited_by uuid not null references auth.users(id) on delete cascade,
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index project_invitations_project_created_idx
  on public.project_invitations(project_id, created_at desc);
create index project_invitations_pending_email_idx
  on public.project_invitations(lower(email), expires_at)
  where status = 'pending';

create table public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text not null default '',
  status public.project_task_status not null default 'todo',
  priority public.project_task_priority not null default 'normal',
  assignee_id uuid references auth.users(id) on delete set null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_tasks_completed_at_check
    check ((status = 'done' and completed_at is not null) or (status <> 'done' and completed_at is null))
);

create index project_tasks_project_status_idx
  on public.project_tasks(project_id, status, due_date);
create index project_tasks_assignee_idx
  on public.project_tasks(assignee_id, status, due_date);

create trigger project_tasks_set_updated_at
before update on public.project_tasks
for each row execute function public.set_updated_at();

alter table public.project_invitations enable row level security;
alter table public.project_tasks enable row level security;

revoke all on table public.project_invitations from anon, authenticated;
grant select, insert, update, delete on table public.project_tasks to authenticated;

create policy "Project members can view tasks"
on public.project_tasks for select
to authenticated
using (public.is_project_member(project_id));

create policy "Editors can create tasks"
on public.project_tasks for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.can_edit_project(project_id)
  and (
    assignee_id is null
    or assignee_id = (select p.owner_id from public.projects p where p.id = project_id)
    or exists (
      select 1 from public.project_members pm
      where pm.project_id = project_id and pm.user_id = assignee_id
    )
  )
);

create policy "Editors can update tasks"
on public.project_tasks for update
to authenticated
using (public.can_edit_project(project_id))
with check (
  public.can_edit_project(project_id)
  and (
    assignee_id is null
    or assignee_id = (select p.owner_id from public.projects p where p.id = project_id)
    or exists (
      select 1 from public.project_members pm
      where pm.project_id = project_id and pm.user_id = assignee_id
    )
  )
);

create policy "Editors can delete tasks"
on public.project_tasks for delete
to authenticated
using (public.can_edit_project(project_id));

create or replace function public.log_project_task_activity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  event_name text;
  event_title text;
begin
  if tg_op = 'INSERT' then
    event_name := 'task_created';
    event_title := 'Tâche créée : ' || new.title;
  elsif tg_op = 'UPDATE' then
    event_name := 'task_updated';
    event_title := 'Tâche modifiée : ' || new.title;
  else
    event_name := 'task_deleted';
    event_title := 'Tâche supprimée : ' || old.title;
  end if;

  insert into public.project_activity(project_id, actor_id, event_type, title, metadata)
  values (
    case when tg_op = 'DELETE' then old.project_id else new.project_id end,
    (select auth.uid()),
    event_name,
    event_title,
    jsonb_build_object(
      'task_id', case when tg_op = 'DELETE' then old.id else new.id end,
      'status', case when tg_op = 'DELETE' then old.status::text else new.status::text end
    )
  );

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger project_tasks_activity
after insert or update or delete on public.project_tasks
for each row execute function public.log_project_task_activity();

commit;
