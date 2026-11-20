# Cookidea

**Transformez vos idées en projets structurés, étape par étape.**

Cookidea est un workspace de maturation d'idées et de construction entrepreneuriale. Il accompagne les utilisateurs depuis une intuition initiale jusqu'à un projet documenté, expérimenté et progressivement validé.

## Stack

- Flutter Web / Dart
- Riverpod pour l'état applicatif
- GoRouter pour la navigation
- Supabase (PostgreSQL, Auth, Storage, RLS, Edge Functions)
- GitHub Actions pour analyse, tests et build Flutter Web
- Netlify pour l'hébergement (déploiement mis en pause pendant le développement)

## Démarrage local

Prérequis : Flutter stable, Dart et Python 3.

1. Installer les dépendances :

```bash
flutter pub get
```

2. Créer le fichier d'environnement local :

```bash
cp .env.example .env
```

3. Renseigner les valeurs du projet Supabase dans `.env` :

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

4. Lancer Flutter en chargeant automatiquement les variables :

```bash
python3 tool/flutter_env.py run -d chrome
```

Pour compiler le Web localement :

```bash
python3 tool/flutter_env.py build web --release
```

Le script transmet les variables en `--dart-define` à Flutter. Le fichier `.env` reste local et n'est jamais commité. Le lancement direct via `flutter run` sans `--dart-define` démarre en mode aperçu non connecté.

Les variables d'environnement du système ont priorité sur celles du fichier local. La CI utilise ses propres secrets GitHub `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY`.

Ne jamais placer une clé `service_role`, une clé secrète Supabase ou un secret SMTP dans l'application Flutter, `.env` racine ou les variables de build Web.

## Edge Functions Supabase

La fonction `send-project-email` est déployée sur le projet Supabase et exige un JWT utilisateur valide. Elle vérifie l'appartenance au projet, le rôle de l'expéditeur et du destinataire, applique une limite d'envoi et journalise l'opération.

Pour la tester localement, créer `supabase/functions/.env` à partir de `supabase/functions/.env.example`, puis démarrer Supabase et la fonction :

```bash
supabase start
supabase functions serve send-project-email --env-file supabase/functions/.env
```

Pour activer l'envoi sur le projet hébergé, renseigner les variables SMTP dans Supabase Dashboard → Edge Functions → Secrets. Utiliser un port SMTP compatible avec les restrictions Edge Functions (465 avec TLS est le choix prévu ici). Ne jamais commiter le mot de passe d'application. Le service renvoie `503 EMAIL_SERVICE_NOT_CONFIGURED` tant que ces secrets ne sont pas configurés.

Les e-mails OTP, confirmations et réinitialisations de mot de passe restent gérés par Supabase Auth et sa configuration SMTP dédiée. Cette Edge Function concerne les e-mails métier entre membres d'un même projet.

## Structure

- `lib/core` : configuration, thème, navigation et composants transverses
- `lib/features` : fonctionnalités organisées par domaine
- `supabase/migrations` : migrations SQL versionnées
- `supabase/functions` : Edge Functions et exemples de secrets locaux
- `docs` : spécifications et décisions d'architecture
- `tool` : scripts de développement local

## Produit

La première livraison couvre la fondation du workspace : expérience d'accueil, navigation, tableau de bord initial, cadrage, hypothèses, expériences, preuves et décisions.

Voir [la stratégie e-mail et notifications](docs/EMAILS.md).

## Contrôles qualité

Le workflow GitHub Actions exécute le formatage, l'analyse, les tests et le build Flutter Web. La publication Netlify reste volontairement désactivée pendant la phase de développement.
