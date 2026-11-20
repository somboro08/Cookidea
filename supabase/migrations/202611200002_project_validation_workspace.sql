-- Cookidea: project discovery and validation workspace
begin;

create table public.project_hypotheses (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text not null default '',
  status text not null default 'À vérifier' check (status in ('À vérifier','Validée','Invalidée')),
  confidence smallint not null default 50 check (confidence between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index project_hypotheses_project_idx on public.project_hypotheses(project_id, created_at desc);
create trigger project_hypotheses_set_updated_at before update on public.project_hypotheses
for each row execute function public.set_updated_at();

create table public.project_experiments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 1 and 160),
  method text not null default '',
  success_criteria text not null default '',
  status text not null default 'À préparer' check (status in ('À préparer','En cours','Terminée','Abandonnée')),
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index project_experiments_project_idx on public.project_experiments(project_id, created_at desc);
create trigger project_experiments_set_updated_at before update on public.project_experiments
for each row execute function public.set_updated_at();

create table public.project_evidence (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text not null default '',
  source text not null default '',
  evidence_type text not null default 'Observation' check (evidence_type in ('Observation','Entretien','Donnée','Document','Test')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index project_evidence_project_idx on public.project_evidence(project_id, created_at desc);
create trigger project_evidence_set_updated_at before update on public.project_evidence
for each row execute function public.set_updated_at();

create table public.project_decisions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 1 and 160),
  rationale text not null default '',
  outcome text not null default 'À décider' check (outcome in ('Poursuivre','Ajuster','Pivoter','Arrêter','À décider')),
  decision_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index project_decisions_project_idx on public.project_decisions(project_id, created_at desc);
create trigger project_decisions_set_updated_at before update on public.project_decisions
for each row execute function public.set_updated_at();

grant select, insert, update, delete on public.project_hypotheses, public.project_experiments, public.project_evidence, public.project_decisions to authenticated;

do $
declare t text;
begin
  foreach t in array array['project_hypotheses','project_experiments','project_evidence','project_decisions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "Members can view %1$s" on public.%1$I for select to authenticated using (public.is_project_member(project_id))', t);
    execute format('create policy "Editors can insert %1$s" on public.%1$I for insert to authenticated with check (created_by = (select auth.uid()) and public.can_edit_project(project_id))', t);
    execute format('create policy "Editors can update %1$s" on public.%1$I for update to authenticated using (public.can_edit_project(project_id)) with check (public.can_edit_project(project_id))', t);
    execute format('create policy "Editors can delete %1$s" on public.%1$I for delete to authenticated using (public.can_edit_project(project_id))', t);
  end loop;
end $$;

commit;create policy "Members can view hypotheses" on public.project_hypotheses for select to authenticated using (public.is_project_member(project_id));
create policy "Editors can insert hypotheses" on public.project_hypotheses for insert to authenticated with check (created_by = (select auth.uid()) and public.can_edit_project(project_id));
create policy "Editors can update hypotheses" on public.project_hypotheses for update to authenticated using (public.can_edit_project(project_id)) with check (public.can_edit_project(project_id));
create policy "Editors can delete hypotheses" on public.project_hypotheses for delete to authenticated using (public.can_edit_project(project_id));

create policy "Members can view experiments" on public.project_experiments for select to authenticated using (public.is_project_member(project_id));
create policy "Editors can insert experiments" on public.project_experiments for insert to authenticated with check (created_by = (select auth.uid()) and public.can_edit_project(project_id));
create policy "Editors can update experiments" on public.project_experiments for update to authenticated using (public.can_edit_project(project_id)) with check (public.can_edit_project(project_id));
create policy "Editors can delete experiments" on public.project_experiments for delete to authenticated using (public.can_edit_project(project_id));

create policy "Members can view evidence" on public.project_evidence for select to authenticated using (public.is_project_member(project_id));
create policy "Editors can insert evidence" on public.project_evidence for insert to authenticated with check (created_by = (select auth.uid()) and public.can_edit_project(project_id));
create policy "Editors can update evidence" on public.project_evidence for update to authenticated using (public.can_edit_project(project_id)) with check (public.can_edit_project(project_id));
create policy "Editors can delete evidence" on public.project_evidence for delete to authenticated using (public.can_edit_project(project_id));

create policy "Members can view decisions" on public.project_decisions for select to authenticated using (public.is_project_member(project_id));
create policy "Editors can insert decisions" on public.project_decisions for insert to authenticated with check (created_by = (select auth.uid()) and public.can_edit_project(project_id));
create policy "Editors can update decisions" on public.project_decisions for update to authenticated using (public.can_edit_project(project_id)) with check (public.can_edit_project(project_id));
create policy "Editors can delete decisions" on public.project_decisions for delete to authenticated using (public.can_edit_project(project_id));

commit;
