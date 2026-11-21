-- Maintain the invitation updated_at timestamp on status transitions.
create trigger project_invitations_set_updated_at
before update on public.project_invitations
for each row execute function public.set_updated_at();
