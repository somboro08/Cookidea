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
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<Map<String, dynamic>> _invoke(String action, {Map<String, dynamic> extra = const {}}) async {
    final response = await Supabase.instance.client.functions.invoke(
      'manage-project-members',
      body: {'action': action, 'project_id': widget.projectId, ...extra},
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map || data['error'] != null) {
      final code = data is Map ? data['error']?.toString() : null;
      final message = data is Map ? data['message']?.toString() : null;
      throw Exception(message ?? _friendly(code ?? 'REQUEST_FAILED'));
    }
    return Map<String, dynamic>.from(data);
  }

  String _friendly(String code) => switch (code) {
    'USER_NOT_FOUND' => 'Cette personne doit d’abord créer un compte Cookidea.',
    'ALREADY_MEMBER' => 'Cette personne est déjà membre du projet.',
    'INVALID_EMAIL' => 'Adresse e-mail invalide.',
    'OWNER_ONLY' => 'Seul le propriétaire peut gérer les membres.',
    _ => 'Une erreur est survenue ($code).',
  };

  Future<void> _load() async {
    if (!widget.enabled) {
      setState(() { _loading = false; _error = 'Connectez Supabase pour gérer les membres.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _invoke('list');
      if (!mounted) return;
      setState(() {
        _members = List<Map<String, dynamic>>.from(data['members'] as List? ?? const []);
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
        title: const Text('Ajouter un collaborateur'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: email, autofocus: true, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Adresse e-mail', hintText: 'nom@exemple.com')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Accès accordé'),
            items: const [
              DropdownMenuItem(value: 'editor', child: Text('Éditeur — peut modifier le projet')),
              DropdownMenuItem(value: 'viewer', child: Text('Lecteur — consultation uniquement')),
            ], onChanged: (value) { if (value != null) refresh(() => role = value); }),
          const SizedBox(height: 10),
          Text('La personne doit déjà posséder un compte Cookidea.', style: Theme.of(context).textTheme.bodySmall),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, [email.text.trim(), role]), child: const Text('Ajouter au projet')),
        ],
      )));
    final address = email.text.trim();
    email.dispose();
    if (values == null || address.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _invoke('invite', extra: {'email': address, 'role': values[1]});
      await _load();
      if (mounted) _message(result['email_sent'] == true
        ? 'Membre ajouté et notification envoyée.'
        : 'Membre ajouté. La notification e-mail sera disponible après la configuration SMTP.');
    } catch (e) { if (mounted) _message(e.toString().replaceFirst('Exception: ', '')); }
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

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 32), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Équipe du projet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text('Travaillez à plusieurs et définissez clairement les responsabilités.', style: Theme.of(context).textTheme.bodySmall),
            ])),
            const SizedBox(width: 12),
            FilledButton.icon(onPressed: !widget.enabled || _busy ? null : _invite, icon: const Icon(Icons.person_add_alt_1), label: const Text('Ajouter')),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Icon(Icons.shield_outlined, color: p.goldText), const SizedBox(width: 12),
            Expanded(child: Text('Le propriétaire conserve le contrôle des accès. Les éditeurs peuvent contribuer ; les lecteurs consultent uniquement.', style: Theme.of(context).textTheme.bodySmall)),
          ]))),
          const SizedBox(height: 12),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Expanded(child: Text(_error!)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ]))),
          if (!_loading && _error == null && _members.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [
            Icon(Icons.groups_2_outlined, size: 38, color: p.goldText), const SizedBox(height: 12),
            Text('Vous travaillez seul pour le moment.', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6), Text('Ajoutez un collaborateur pour construire ce projet en équipe.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]))),
          if (!_loading) for (final member in _members) Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            CircleAvatar(backgroundColor: p.goldTint, child: Text(
              ((member['full_name'] ?? member['email'] ?? '?').toString().trim().isNotEmpty
                ? (member['full_name'] ?? member['email']).toString().trim()[0] : '?').toUpperCase(),
              style: TextStyle(color: p.goldText))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member['full_name']?.toString().isNotEmpty == true ? member['full_name'].toString() : 'Membre Cookidea', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3), Text(member['email']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
            ])),
            DropdownButton<String>(value: member['role'] == 'viewer' ? 'viewer' : 'editor', underline: const SizedBox.shrink(),
              onChanged: _busy ? null : (value) { if (value != null && value != member['role']) _changeRole(member, value); },
              items: const [DropdownMenuItem(value: 'editor', child: Text('Éditeur')), DropdownMenuItem(value: 'viewer', child: Text('Lecteur'))]),
            IconButton(tooltip: 'Retirer', onPressed: _busy ? null : () => _remove(member), icon: const Icon(Icons.person_remove_outlined)),
          ]))),
        ],
      ))),
    ]);
  }
}
