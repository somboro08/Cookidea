# Cookidea

**Transformez vos idées en projets structurés, étape par étape.**

Cookidea est un workspace de maturation d'idées et de construction entrepreneuriale. Il accompagne les utilisateurs depuis une intuition initiale jusqu'à un projet documenté, expérimenté et progressivement validé.

## Stack

- Flutter Web / Dart
- Riverpod pour l'état applicatif
- GoRouter pour la navigation
- Supabase (PostgreSQL, Auth, Storage, RLS)
- GitHub Actions pour l'intégration continue

## Démarrage

Prérequis : Flutter stable et Dart compatibles avec le SDK indiqué dans `pubspec.yaml`.

```bash
flutter pub get
flutter run -d chrome
```

L'application démarre en mode aperçu local tant que les variables Supabase ne sont pas configurées.

Pour connecter un projet Supabase :

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
```

Ne jamais placer une clé `service_role`, une clé secrète ou un secret de fournisseur IA dans l'application Flutter.

## Structure

- `lib/core` : configuration, thème, navigation et composants transverses
- `lib/features` : fonctionnalités organisées par domaine
- `supabase/migrations` : migrations SQL versionnées
- `docs` : spécifications et décisions d'architecture

## Produit

La première livraison couvre la fondation du workspace : expérience d'accueil, navigation, tableau de bord initial et préparation de l'intégration Supabase.

Voir [les spécifications fonctionnelles](docs/PRODUCT_SPEC.md) et [l'architecture](docs/ARCHITECTURE.md).
