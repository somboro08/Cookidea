-- Cookidea: initial workspace schema
-- Apply with Supabase CLI: supabase db push
begin;

create extension if not exists pgcrypto;

create type public.project_status as enum ('draft', 'active', 'paused', 'archived');
create type public.project_member_role as enum ('owner', 'editor', 'viewer');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  preferred_language text not null default 'fr',
  experience_mode text not null default 'guided'
    check (experience_mode in ('guided', 'advanced')),
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 100),
  slug text,
  description text not null default '',
  initial_idea text not null default '',
  problem_statement text,
  target_audience text,
  status public.project_status not null default 'draft',
  current_maturity_level smallint not null default 0
    check (current_maturity_level between 0 and 9),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_owner_updated_idx
  on public.projects(owner_id, updated_at desc);

create table public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.project_member_role not null default 'viewer',
  joined_at timestamptz not null default now(),
  unique (project_id, user_id)
);

create index project_members_user_idx on public.project_members(user_id, project_id);

create table public.project_activity (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  title text not null,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index project_activity_project_created_idx
  on public.project_activity(project_id, created_at desc);

create or replace function public.is_project_member(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = target_project_id
      and p.owner_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.project_members pm
    where pm.project_id = target_project_id
      and pm.user_id = (select auth.uid())
  );
$$;

create or replace function public.can_edit_project(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = target_project_id
      and p.owner_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.project_members pm
    where pm.project_id = target_project_id
      and pm.user_id = (select auth.uid())
      and pm.role = 'editor'
  );
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_activity enable row level security;

create policy "Profiles are visible to their owner"
on public.profiles for select
to authenticated
using (id = (select auth.uid()));

create policy "Users can create their own profile"
on public.profiles for insert
to authenticated
with check (id = (select auth.uid()));

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "Project members can view projects"
on public.projects for select
to authenticated
using (owner_id = (select auth.uid()) or public.is_project_member(id));

create policy "Authenticated users can create projects for themselves"
on public.projects for insert
to authenticated
with check (owner_id = (select auth.uid()));

create policy "Owners and editors can update projects"
on public.projects for update
to authenticated
using (public.can_edit_project(id))
with check (public.can_edit_project(id));

create policy "Only owners can delete projects"
on public.projects for delete
to authenticated
using (owner_id = (select auth.uid()));

create policy "Project members can view membership"
on public.project_members for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.projects p
    where p.id = project_id and p.owner_id = (select auth.uid())
  )
);

create policy "Owners can add project members"
on public.project_members for insert
to authenticated
with check (
  exists (
    select 1 from public.projects p
    where p.id = project_id and p.owner_id = (select auth.uid())
  )
);

create policy "Owners can update project members"
on public.project_members for update
to authenticated
using (
  exists (
    select 1 from public.projects p
    where p.id = project_id and p.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.projects p
    where p.id = project_id and p.owner_id = (select auth.uid())
  )
);

create policy "Owners can remove project members"
on public.project_members for delete
to authenticated
using (
  exists (
    select 1 from public.projects p
    where p.id = project_id and p.owner_id = (select auth.uid())
  )
);

create policy "Members can view project activity"
on public.project_activity for select
to authenticated
using (public.is_project_member(project_id));

create policy "Editors and owners can create project activity"
on public.project_activity for insert
to authenticated
with check (
  actor_id = (select auth.uid())
  and public.can_edit_project(project_id)
);

-- Restrict helper execution to authenticated application users.
revoke all on function public.is_project_member(uuid) from public, anon;
revoke all on function public.can_edit_project(uuid) from public, anon;
grant execute on function public.is_project_member(uuid) to authenticated;
grant execute on function public.can_edit_project(uuid) to authenticated;

commit;
