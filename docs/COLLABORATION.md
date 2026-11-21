# Collaboration Cookidea

## Équipe d'un projet

Le panneau Équipe est intégré à l'espace projet.

- Le propriétaire est affiché comme tel et conserve le contrôle des accès.
- Le propriétaire peut ajouter un compte Cookidea existant par adresse e-mail.
- Un collaborateur reçoit le rôle Éditeur ou Lecteur.
- Le propriétaire peut modifier le rôle ou retirer un collaborateur.
- Les membres du projet peuvent consulter la liste de l'équipe.
- Les changements sont journalisés dans `project_activity`.

### Limitation actuelle

La première version ajoute directement un compte existant au projet. Elle ne crée pas encore d'invitation en attente pour une personne qui ne possède pas de compte Cookidea, ni de lien d'acceptation. Dans ce cas, la personne doit d'abord créer son compte.

La notification e-mail est envoyée uniquement lorsque les secrets SMTP de l'Edge Function sont configurés. L'ajout au projet reste possible sans SMTP.

## Permissions

| Rôle | Consulter | Modifier les contenus | Gérer l'équipe |
|---|---:|---:|---:|
| Propriétaire | Oui | Oui | Oui |
| Éditeur | Oui | Oui | Non |
| Lecteur | Oui | Non | Non |

Les permissions d'écriture sont appliquées par les politiques RLS, pas seulement par l'interface Flutter.

## Edge Function

`manage-project-members` exige un JWT valide. Le service :
- vérifie la session utilisateur ;
- vérifie l'appartenance au projet pour consulter l'équipe ;
- réserve les mutations d'équipe au propriétaire ;
- limite les rôles possibles à `editor` et `viewer` ;
- vérifie l'existence du compte avant de l'ajouter ;
- journalise les opérations importantes ;
- envoie une notification e-mail si SMTP est configuré.

## Activité

L'onglet Activité lit les événements de `project_activity` en respectant RLS. Il affiche les événements récents, les dates locales et les descriptions disponibles.
