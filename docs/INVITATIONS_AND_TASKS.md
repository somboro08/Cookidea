# Invitations et tâches Cookidea

## Invitations aux projets

L'onglet Équipe permet au propriétaire :
- d'inviter une adresse e-mail avec un rôle Éditeur ou Lecteur ;
- de consulter les invitations en attente ;
- de renvoyer un lien (nouveau jeton) ;
- de révoquer un lien ;
- de consulter l'historique des invitations.

Les invitations sont valables 7 jours. Le jeton contient 256 bits aléatoires ; seule son empreinte SHA-256 est stockée. L'acceptation exige une session Cookidea dont l'adresse e-mail correspond à l'adresse invitée. Une invitation déjà acceptée par le même utilisateur peut être retraitée sans créer de doublon.

La fonction `manage-project-invitations` est déployée avec JWT obligatoire. La table `project_invitations` n'expose aucune politique RLS client : toutes les opérations passent par l'Edge Function et son accès serveur.

### Configuration requise

Dans `supabase/functions/.env` (local) ou Supabase Dashboard → Edge Functions → Secrets (hébergé) :
- `APP_BASE_URL` : URL d'ouverture de l'application Flutter Web
- `SMTP_HOST`
- `SMTP_PORT=465`
- `SMTP_SECURE=true`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM`

En local, créer le fichier depuis `supabase/functions/.env.example`. Le fichier réel est ignoré par Git. Pour une invitation locale, le navigateur du destinataire doit pouvoir atteindre cette URL ; `localhost` ne convient donc qu'à un test sur le même ordinateur.

L'URL de redirection utilisée par la confirmation d'inscription doit être autorisée dans Supabase Authentication → URL Configuration.

## Tâches de projet

L'onglet Tâches permet aux propriétaires et éditeurs de :
- créer et modifier des tâches ;
- attribuer une tâche au propriétaire ou à un membre du projet ;
- choisir une priorité (basse, normale, haute, urgente) ;
- définir une date d'échéance ;
- suivre l'état (à faire, en cours, terminée, annulée) ;
- filtrer les tâches et suivre la progression.

Les lecteurs consultent les tâches sans les modifier. Les permissions sont imposées par RLS. Les assignations sont limitées aux membres du projet concerné. Les changements de tâches alimentent automatiquement `project_activity`.

## Schéma

- `project_invitations` : invitations, jetons hachés, rôle, expiration et acceptation.
- `project_tasks` : tâches, assignations, priorités, échéances et dates de fin.
- `sync_project_task_completion` maintient `completed_at` en cohérence avec l'état de la tâche.
