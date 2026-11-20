# Cookidea — Architecture technique

## Principes

- Feature-first : le code est organisé par domaine fonctionnel.
- Clean Architecture pragmatique : présentation, domaine et données sont séparés lorsque la complexité le justifie.
- Supabase est la source de vérité des données persistantes.
- La logique métier sensible et les secrets restent côté serveur.
- Les interfaces Flutter ne contiennent pas de règles d'autorisation faisant autorité.

## Stack

- Flutter Web / Dart
- Riverpod
- GoRouter
- Supabase Flutter
- PostgreSQL avec RLS
- Supabase Edge Functions pour les opérations serveur et l'orchestration IA future

## Structure cible

```text
lib/
  app/
    app.dart
    router.dart
  core/
    config/
    theme/
    errors/
    widgets/
  shared/
    models/
    widgets/
  features/
    dashboard/
      data/
      domain/
      presentation/
    authentication/
    projects/
    exploration/
    maturation/
    hypotheses/
    experiments/
    evidence/
    decisions/
    assistant/
    cev/
supabase/
  migrations/
  functions/
docs/
```

## Sécurité

- Activer RLS sur chaque table exposée.
- Accès propriétaire ou membre explicite au projet.
- Rôles de projet : owner, editor, viewer.
- Les clés publishable/anon peuvent être utilisées côté client avec RLS correctement configuré.
- Ne jamais embarquer service_role ou clés fournisseurs IA dans Flutter.
- Les opérations privilégiées sont exécutées côté serveur.

## Configuration

Les valeurs publiques Supabase sont injectées au build via `--dart-define`. Aucun fichier contenant des secrets ne doit être versionné.

## Qualité

- `flutter analyze` doit réussir.
- Tests unitaires pour les règles métier.
- Tests de widgets pour les parcours clés.
- Tests d'intégration pour authentification et création de projet.
- GitHub Actions sur chaque pull request et push sur main.
