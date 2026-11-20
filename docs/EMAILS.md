# Cookidea — E-mail et notifications

## Objectif

Cookidea prévoit un service de communication partagé par les fonctionnalités d'identité et les fonctionnalités métier.

## 1. E-mails d'authentification (Supabase Auth)

Les codes OTP de connexion, confirmations d'inscription et réinitialisations de mot de passe sont gérés par Supabase Auth. Flutter demande l'envoi du code puis vérifie celui-ci auprès de Supabase Auth ; le navigateur ne génère et ne valide jamais lui-même un OTP.

Configuration à faire dans le Dashboard du projet Supabase :
1. Ouvrir Authentication → Emails / SMTP Settings (le libellé peut varier selon la version du Dashboard).
2. Activer le SMTP personnalisé.
3. Renseigner l'hôte SMTP, le port, l'utilisateur, le mot de passe d'application, l'adresse expéditeur et le nom expéditeur.
4. Vérifier les modèles d'e-mail et choisir le modèle OTP/code.
5. Vérifier le domaine expéditeur et ses enregistrements SPF/DKIM chez le fournisseur.
6. Tester l'inscription, la connexion OTP et la récupération de compte.

Les identifiants SMTP doivent rester dans la configuration sécurisée Supabase. Ne jamais les mettre dans Flutter, --dart-define, le dépôt Git ou les secrets de build Web.

## 2. E-mails applicatifs et communication entre utilisateurs

Les notifications métier (invitation à collaborer, partage de projet, message, rappel) sont distinctes des e-mails Auth. Elles seront émises par une API serveur authentifiée, après vérification de l'identité, des permissions et des préférences du destinataire.

Le contrat prévu sera centralisé autour de modèles et de types d'événements :
- project_invitation
- project_message
- project_activity
- security_notice

Le client ne choisira pas librement un destinataire et ne pourra pas envoyer du HTML arbitraire. Le serveur résout les destinataires depuis les identifiants d'utilisateurs, applique les règles anti-abus et journalise le résultat sans stocker de secrets.

### Important sur SMTP

Le SMTP configuré dans Supabase Auth sert à l'envoi des e-mails Auth. Il ne devient pas automatiquement un service SMTP générique accessible depuis les Edge Functions. Les Edge Functions utilisent normalement des appels HTTP vers un fournisseur d'e-mail. Pour réutiliser un serveur SMTP arbitraire pour les e-mails métier, il faudra un composant serveur Node compatible SMTP (par exemple une fonction Netlify) avec les identifiants stockés dans les variables secrètes de son environnement, ou un relais HTTP sécurisé.

La décision d'implémentation sera prise avant le module de messagerie. Aucun mot de passe d'application n'est demandé ni enregistré dans cette première livraison.

## Sécurité minimale

- OTP généré et validé par Supabase Auth, jamais par le navigateur.
- SMTP uniquement côté serveur.
- Limitation de fréquence et réponses non révélatrices pour les adresses inconnues.
- Autorisation vérifiée côté serveur pour chaque invitation/message.
- Journalisation des états d'envoi, sans enregistrer OTP, mots de passe ou contenu sensible.
- Secrets différents pour développement et production lorsque possible.