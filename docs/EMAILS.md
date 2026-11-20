# Cookidea — E-mail et notifications

## 1. E-mails d'authentification (Supabase Auth)

Les codes OTP de connexion, confirmations d'inscription et réinitialisations de mot de passe sont gérés par Supabase Auth. Flutter demande l'envoi du code puis vérifie celui-ci auprès de Supabase Auth ; le navigateur ne génère et ne valide jamais lui-même un OTP.

Configuration dans Supabase Dashboard → Authentication → Emails / SMTP Settings :
1. Activer le SMTP personnalisé.
2. Renseigner l'hôte SMTP, le port, l'utilisateur, le mot de passe d'application, l'adresse expéditeur et le nom expéditeur.
3. Vérifier les modèles OTP et les modèles de confirmation.
4. Vérifier le domaine expéditeur et ses enregistrements SPF/DKIM.
5. Tester inscription, connexion OTP et récupération de compte.

Les identifiants SMTP restent dans la configuration Auth de Supabase. Ne jamais les mettre dans Flutter, `--dart-define`, le dépôt Git ou les secrets de build Web.

## 2. E-mails applicatifs entre membres

Une Edge Function `send-project-email` est déployée dans Supabase. Le client Flutter dispose du service `ProjectEmailService` pour l'appeler avec la session de l'utilisateur.

La fonction :
- exige un JWT utilisateur valide ;
- vérifie que l'expéditeur est propriétaire ou éditeur du projet ;
- vérifie que le destinataire est membre du même projet ;
- limite les envois par utilisateur et par projet ;
- résout l'adresse e-mail du destinataire côté serveur ;
- journalise l'envoi dans `project_activity` sans stocker le contenu du message ;
- refuse les messages et sujets hors limites.

Le client ne fournit jamais l'adresse e-mail du destinataire, seulement son identifiant utilisateur. L'Edge Function résout l'adresse via Supabase Auth.

## 3. Configuration SMTP de l'Edge Function

La fonction utilise Nodemailer côté serveur. Les Edge Functions Supabase bloquent les connexions sortantes sur les ports SMTP 25 et 587 ; la configuration prévue utilise donc le port 465 avec TLS.

Dans Supabase Dashboard → Edge Functions → Secrets, ajouter :
- `SMTP_HOST`
- `SMTP_PORT=465`
- `SMTP_SECURE=true`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM`

Les secrets ne sont pas configurés automatiquement par le déploiement du code. Tant qu'ils ne sont pas renseignés, la fonction répond `503 EMAIL_SERVICE_NOT_CONFIGURED`. Ne pas envoyer le mot de passe d'application dans une conversation et ne jamais le commiter.

Pour le développement local, créer `supabase/functions/.env` à partir de `supabase/functions/.env.example`, puis exécuter :

```bash
supabase start
supabase functions serve send-project-email --env-file supabase/functions/.env
```

Le fichier racine `.env` est réservé aux variables de compilation Flutter (`SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY`). Les secrets Edge Function sont séparés dans `supabase/functions/.env`.

## Sécurité

- Aucune clé Supabase secrète ou `service_role` dans Flutter.
- Aucun secret SMTP dans le bundle Web, le dépôt ou les logs.
- Authentification JWT et contrôle des permissions côté serveur.
- Limitation d'envoi et journalisation des événements.
- Les e-mails d'authentification et les e-mails métier restent deux circuits distincts.
