# Cookidea — Spécifications fonctionnelles

## Vision

Cookidea aide toute personne à transformer une intuition en projet structuré, en avançant progressivement avec un workspace accessible aux débutants et suffisamment profond pour les utilisateurs expérimentés.

## Principes produit

1. Accessibilité : aucune expérience entrepreneuriale préalable n'est requise.
2. Progressivité : l'utilisateur avance étape par étape.
3. Traçabilité : hypothèses, preuves, expériences et décisions restent distinctes.
4. Transparence : une suggestion de l'IA n'est pas un fait ni une décision.
5. Réversibilité : un projet peut pivoter sans effacer son historique.
6. Autonomie : l'utilisateur garde le contrôle des changements importants.

## Utilisateurs

- Débutant : a besoin d'être guidé et de comprendre les notions.
- Porteur d'idée : veut structurer et explorer une idée.
- Entrepreneur : veut expérimenter et prendre des décisions.
- Expert : veut approfondir les analyses et les dépendances.

Deux modes d'expérience sont prévus : guidé et avancé. Le mode ne modifie pas les droits d'accès aux données.

## Modules fonctionnels

### 1. Identité
- Inscription, connexion, déconnexion et réinitialisation du mot de passe.
- Profil et préférences.
- Choix du mode guidé ou avancé.

### 2. Workspace
- Tableau de bord des projets.
- Création, consultation, modification, archivage et suppression contrôlée.
- Activité récente et prochaines actions.

### 3. Exploration d'idée
- Saisie libre d'une intuition.
- Clarification progressive du problème, des utilisateurs et du résultat recherché.
- Sauvegarde en brouillon.

### 4. Maturation
- Dix niveaux de maturité, de l'intuition à la startup.
- Évaluation argumentée de l'état du projet.
- Identification des inconnues, risques, blocages et prochaines actions.
- Les évaluations ne provoquent pas automatiquement une transition.

### 5. Hypothèses, expériences et preuves
- Une hypothèse est une affirmation à vérifier.
- Une expérience est un protocole de vérification.
- Une preuve est une observation ou une source documentée.
- Les résultats peuvent être concluants, contradictoires ou insuffisants.

### 6. Assistant IA
- Assistant contextualisé par projet.
- Questions de clarification, synthèses et recommandations.
- Les propositions IA sont identifiées comme telles et ne modifient pas les données métier sans validation utilisateur.

### 7. Méthodologies
- Bibliothèque de méthodes et parcours guidés.
- Lean Startup, Design Thinking, SWOT, Business Model Canvas, Value Proposition Canvas, entre autres.

### 8. CEV
- Carte d'entreprise visée construite à partir des données du projet.
- Nœuds, relations, dépendances et lacunes.
- La CEV est une vue des données métier, pas une seconde source de vérité.

## Cycle de maturité

| Niveau | Étape |
|---:|---|
| 0 | Intuition |
| 1 | Idée |
| 2 | Problème |
| 3 | Opportunité |
| 4 | Concept |
| 5 | Validation |
| 6 | MVP |
| 7 | Traction |
| 8 | Business |
| 9 | Startup |

Les niveaux ne sont pas un score de qualité. Un projet peut rester à un niveau, régresser ou pivoter si les preuves le justifient.

## Périmètre de la première livraison

- Fondation Flutter Web et design system.
- Navigation workspace.
- Authentification Supabase.
- Profils.
- Création et gestion des projets.
- Tableau de bord.
- Première exploration d'idée.
- Historique minimal des événements.
- Préparation des tables d'hypothèses et d'évaluations.

Les agents multiples, la CEV avancée, la collaboration étendue et les méthodologies complètes seront livrés progressivement.
