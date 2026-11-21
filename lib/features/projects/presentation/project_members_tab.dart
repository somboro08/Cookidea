import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';

class ProjectMembersTab extends StatefulWidget {
  const ProjectMembersTab({super.key, required this.projectId, required this.enabled});
  final String projectId;
  final bool enabled;
  @override
  State<ProjectMembersTab> createState() => _ProjectMembersTabState();
}

class _ProjectMembersTabState extends State<ProjectMembersTab> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _loading = true, _busy = false, _isOwner = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<Map<String, dynamic>> _invoke(String action, {Map<String, dynamic> extra = const {}}) async {
    final response = await Supabase.instance.client.functions.invoke('manage-project-members',
      body: {'action': action, 'project_id': widget.projectId, ...extra});
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map || data['error'] != null) {
      final code = data is Map ? data['error']?.toString() : null;
      final message = data is Map ? data['message']?.toString() : null;
      throw Exception(message ?? _friendly(code ?? 'REQUEST_FAILED'));
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> _invokeInvitation(String action, {Map<String, dynamic> extra = const {}}) async {
    final response = await Supabase.instance.client.functions.invoke('manage-project-invitations',
      body: {'action': action, 'project_id': widget.projectId, ...extra});
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map || data['error'] != null) {
      final code = data is Map ? data['error']?.toString() : null;
      throw Exception(_friendly(code ?? 'REQUEST_FAILED'));
    }
    return Map<String, dynamic>.from(data);
  }

  String _friendly(String code) => switch (code) {
    'USER_NOT_FOUND' => 'Cette personne doit d’abord créer un compte Cookidea.',
    'ALREADY_MEMBER' => 'Cette personne est déjà membre du projet.',
    'ALREADY_OWNER' => 'Le propriétaire ne peut pas être invité.',
    'INVALID_EMAIL' => 'Adresse e-mail invalide.',
    'OWNER_ONLY' => 'Seul le propriétaire peut gérer les invitations.',
    'SMTP_NOT_CONFIGURED' => 'Les paramètres SMTP du serveur ne sont pas configurés. Aucune invitation n’a été créée.',
    'PROJECT_INVITATION_LIMIT' => 'Ce projet a atteint sa limite de 30 invitations en attente.',
    'INVITATION_RATE_LIMIT' => 'Trop d’invitations ont été envoyées récemment. Réessayez plus tard.',
    'INVITATION_ALREADY_PENDING' => 'Une invitation est déjà en attente pour cette adresse. Vous pouvez la renvoyer depuis la liste.',
    'APP_BASE_URL_NOT_CONFIGURED' => 'Configurez APP_BASE_URL dans les secrets Supabase.',
    'INVITATION_EMAIL_FAILED' => 'L’e-mail n’a pas pu être envoyé. Vérifiez la configuration SMTP.',
    'INVITATION_NOT_FOUND' => 'Cette invitation n’existe plus.',
    'INVITATION_REVOKE_FAILED' => 'Cette invitation ne peut plus être révoquée.',
    _ => 'Une erreur est survenue ($code).',
  };

  Future<void> _load() async {
    if (!widget.enabled) {
      setState(() { _loading = false; _error = 'Connectez Supabase pour gérer les membres.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final membersData = await _invoke('list');
      if (!mounted) return;
      final members = List<Map<String, dynamic>>.from(membersData['members'] as List? ?? const []);
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      final isOwner = members.any((m) => m['user_id'] == currentId && m['is_owner'] == true);
      final invitationsData = isOwner ? await _invokeInvitation('list') : <String, dynamic>{'invitations': <dynamic>[]};
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = List<Map<String, dynamic>>.from(invitationsData['invitations'] as List? ?? const []);
        _isOwner = isOwner;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _invite() async {
    final email = TextEditingController();
    String role = 'editor';
    final values = await showDialog<List<String>>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: const Text('Inviter un collaborateur'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: email, autofocus: true, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Adresse e-mail', hintText: 'nom@exemple.com')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Rôle proposé'),
            items: const [
              DropdownMenuItem(value: 'editor', child: Text('Éditeur — peut contribuer')),
              DropdownMenuItem(value: 'viewer', child: Text('Lecteur — consultation')),
            ], onChanged: (value) { if (value != null) refresh(() => role = value); }),
          const SizedBox(height: 10),
          Text('La personne recevra un lien valable 7 jours. Elle pourra créer son compte avant de rejoindre le projet.', style: Theme.of(context).textTheme.bodySmall),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, [email.text.trim(), role]), child: const Text('Envoyer l’invitation')),
        ],
      )));
    final address = email.text.trim();
    email.dispose();
    if (values == null || address.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _invokeInvitation('invite', extra: {'email': address, 'role': values[1]});
      await _load();
      if (mounted) _message('Invitation envoyée. Elle expire dans 7 jours.');
    } catch (e) { if (mounted) _message(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _resend(Map<String, dynamic> invitation) async {
    setState(() => _busy = true);
    try {
      await _invokeInvitation('resend', extra: {'invitation_id': invitation['id']});
      await _load();
      if (mounted) _message('Une nouvelle invitation a été envoyée.');
    } catch (e) { if (mounted) _message(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _revoke(Map<String, dynamic> invitation) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Révoquer cette invitation ?'),
      content: Text('Le lien envoyé à ${invitation['email']} ne permettra plus de rejoindre le projet.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: const Text('Révoquer')),
      ],
    ));
    if (ok != true) return;
    setState(() => _busy = true);
    try { await _invokeInvitation('revoke', extra: {'invitation_id': invitation['id']}); await _load(); }
    catch (e) { if (mounted) _message(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _changeRole(Map<String, dynamic> member, String role) async {
    setState(() => _busy = true);
    try { await _invoke('change_role', extra: {'user_id': member['user_id'], 'role': role}); await _load(); }
    catch (e) { if (mounted) _message(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Retirer ce membre ?'),
      content: Text('${member['email'] ?? member['full_name'] ?? 'Ce membre'} n’aura plus accès au projet.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
      ],
    ));
    if (ok != true) return;
    setState(() => _busy = true);
    try { await _invoke('remove', extra: {'user_id': member['user_id']}); await _load(); }
    catch (e) { if (mounted) _message(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  String _invitationStatus(String status) => switch (status) {
    'accepted' => 'Acceptée', 'revoked' => 'Révoquée', 'expired' => 'Expirée', _ => 'En attente',
  };
  String _date(String? raw) {
    final d = DateTime.tryParse(raw ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pending = _invitations.where((i) => i['status'] == 'pending').toList();
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 32), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Équipe du projet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text('Invitez des personnes, attribuez des rôles et travaillez ensemble.', style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (_isOwner) FilledButton.icon(onPressed: !widget.enabled || _busy ? null : _invite, icon: const Icon(Icons.person_add_alt_1), label: const Text('Inviter')),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Icon(Icons.shield_outlined, color: p.goldText), const SizedBox(width: 12),
            Expanded(child: Text('Le propriétaire gère les accès. Les éditeurs contribuent au projet ; les lecteurs le consultent.', style: Theme.of(context).textTheme.bodySmall)),
          ]))),
          const SizedBox(height: 18),
          Text('Membres (${_members.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Expanded(child: Text(_error!)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ]))),
          if (!_loading && _error == null && _members.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucun membre.'))),
          if (!_loading) for (final member in _members) Card(margin: const EdgeInsets.only(bottom: 9), child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [
            CircleAvatar(backgroundColor: p.goldTint, child: Text(
              ((member['full_name'] ?? member['email'] ?? '?').toString().trim().isNotEmpty
                ? (member['full_name'] ?? member['email']).toString().trim()[0] : '?').toUpperCase(),
              style: TextStyle(color: p.goldText))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member['full_name']?.toString().isNotEmpty == true ? member['full_name'].toString() : 'Membre Cookidea', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3), Text(member['email']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (member['is_owner'] == true)
              Chip(label: const Text('Propriétaire'), backgroundColor: p.goldTint)
            else if (_isOwner) ...[
              DropdownButton<String>(value: member['role'] == 'viewer' ? 'viewer' : 'editor', underline: const SizedBox.shrink(),
                onChanged: _busy ? null : (value) { if (value != null && value != member['role']) _changeRole(member, value); },
                items: const [DropdownMenuItem(value: 'editor', child: Text('Éditeur')), DropdownMenuItem(value: 'viewer', child: Text('Lecteur'))]),
              IconButton(tooltip: 'Retirer', onPressed: _busy ? null : () => _remove(member), icon: const Icon(Icons.person_remove_outlined)),
            ] else Chip(label: Text(member['role'] == 'viewer' ? 'Lecteur' : 'Éditeur')),
          ]))),
          if (_isOwner) ...[
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text('Invitations en attente (${pending.length})', style: Theme.of(context).textTheme.titleMedium)),
              IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Actualiser'),
            ]),
            const SizedBox(height: 8),
            if (pending.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('Aucune invitation en attente.', style: Theme.of(context).textTheme.bodySmall))),
            for (final invitation in pending) Card(margin: const EdgeInsets.only(bottom: 9), child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [
              CircleAvatar(backgroundColor: p.goldTint, child: Icon(Icons.mail_outline, color: p.goldText)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(invitation['email'].toString(), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text('${invitation['role'] == 'editor' ? 'Éditeur' : 'Lecteur'} · Expire le ${_date(invitation['expires_at']?.toString())}', style: Theme.of(context).textTheme.bodySmall),
              ])),
              IconButton(tooltip: 'Renvoyer', onPressed: _busy ? null : () => _resend(invitation), icon: const Icon(Icons.refresh)),
              IconButton(tooltip: 'Révoquer', onPressed: _busy ? null : () => _revoke(invitation), icon: const Icon(Icons.link_off)),
            ]))),
            if (_invitations.any((i) => i['status'] != 'pending')) ...[
              const SizedBox(height: 16),
              Text('Historique des invitations', style: Theme.of(context).textTheme.titleSmall),
              for (final invitation in _invitations.where((i) => i['status'] != 'pending').take(8))
                ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.mail_outline),
                  title: Text(invitation['email'].toString()),
                  subtitle: Text('${_invitationStatus(invitation['status'].toString())} · ${_date(invitation['created_at']?.toString())}')),
            ],
          ],
        ],
      ))),
    ]));
  }
}
