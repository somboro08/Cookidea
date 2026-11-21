import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';

class ProjectTasksTab extends StatefulWidget {
  const ProjectTasksTab({super.key, required this.projectId, required this.enabled});
  final String projectId;
  final bool enabled;

  @override
  State<ProjectTasksTab> createState() => _ProjectTasksTabState();
}

class _ProjectTasksTabState extends State<ProjectTasksTab> {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _filter = 'all';
  bool _canEdit = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!widget.enabled) {
      setState(() { _loading = false; _error = 'Connectez Supabase pour utiliser les tâches.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final memberResponse = await client.functions.invoke('manage-project-members',
        body: {'action': 'list', 'project_id': widget.projectId});
      if (memberResponse.status < 200 || memberResponse.status >= 300) {
        throw Exception('Impossible de charger les membres du projet.');
      }
      final members = List<Map<String, dynamic>>.from(
        (memberResponse.data as Map)['members'] as List? ?? const []);
      Map<String, dynamic>? current;
      for (final member in members) { if (member['user_id'] == userId) { current = member; break; } }
      final canEdit = current?['is_owner'] == true || current?['role'] == 'editor';
      final rows = await client.from('project_tasks').select()
        .eq('project_id', widget.projectId).order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _members = members;
        _canEdit = canEdit;
        _tasks = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? task]) async {
    final title = TextEditingController(text: task?['title']?.toString() ?? '');
    final description = TextEditingController(text: task?['description']?.toString() ?? '');
    String status = task?['status']?.toString() ?? 'todo';
    String priority = task?['priority']?.toString() ?? 'normal';
    String? assignee = task?['assignee_id']?.toString();
    DateTime? due = DateTime.tryParse(task?['due_date']?.toString() ?? '');
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text(task == null ? 'Nouvelle tâche' : 'Modifier la tâche'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, maxLength: 160,
            decoration: const InputDecoration(labelText: 'Intitulé', hintText: 'Ex. Valider le besoin avec 5 utilisateurs')),
          const SizedBox(height: 12),
          TextField(controller: description, minLines: 2, maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description', hintText: 'Contexte, résultat attendu…', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Avancement'),
            items: const [
              DropdownMenuItem(value: 'todo', child: Text('À faire')),
              DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
              DropdownMenuItem(value: 'done', child: Text('Terminée')),
              DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
            ], onChanged: (v) { if (v != null) refresh(() => status = v); }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'Priorité'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Basse')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ], onChanged: (v) { if (v != null) refresh(() => priority = v); }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(value: assignee, decoration: const InputDecoration(labelText: 'Responsable'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Non assignée')),
              for (final m in _members)
                DropdownMenuItem<String?>(value: m['user_id']?.toString(),
                  child: Text((m['full_name'] ?? m['email'] ?? 'Membre').toString(), overflow: TextOverflow.ellipsis)),
            ], onChanged: (v) => refresh(() => assignee = v)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(due == null ? 'Aucune échéance' : 'Échéance : ${due!.day.toString().padLeft(2, '0')}/${due!.month.toString().padLeft(2, '0')}/${due!.year}')),
            TextButton.icon(onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: due ?? DateTime.now(),
                firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) refresh(() => due = picked);
            }, icon: const Icon(Icons.calendar_today_outlined), label: const Text('Choisir')),
            if (due != null) IconButton(onPressed: () => refresh(() => due = null), icon: const Icon(Icons.close)),
          ]),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) return;
            Navigator.pop(dialogContext, {
              'title': title.text.trim(), 'description': description.text.trim(),
              'status': status, 'priority': priority, 'assignee_id': assignee,
              'due_date': due == null ? null : '${due!.year.toString().padLeft(4, '0')}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}',
            });
          }, child: const Text('Enregistrer')),
        ],
      )));
    title.dispose(); description.dispose();
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      if (task == null) {
        await client.from('project_tasks').insert({...result, 'project_id': widget.projectId, 'created_by': client.auth.currentUser!.id});
      } else {
        await client.from('project_tasks').update(result).eq('id', task['id'].toString());
      }
      await _load();
      if (mounted) _message(task == null ? 'Tâche créée.' : 'Tâche mise à jour.');
    } on PostgrestException catch (e) {
      if (mounted) _message('Enregistrement impossible : ${e.message}');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _quickStatus(Map<String, dynamic> task, String status) async {
    try {
      await Supabase.instance.client.from('project_tasks').update({'status': status}).eq('id', task['id'].toString());
      await _load();
    } on PostgrestException catch (e) { if (mounted) _message('Mise à jour impossible : ${e.message}'); }
  }

  Future<void> _delete(Map<String, dynamic> task) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Supprimer cette tâche ?'),
      content: Text(task['title'].toString()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton.tonal(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
      ],
    ));
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('project_tasks').delete().eq('id', task['id'].toString());
      await _load();
    } on PostgrestException catch (e) { if (mounted) _message('Suppression impossible : ${e.message}'); }
  }

  String _status(String value) => switch (value) {
    'in_progress' => 'En cours', 'done' => 'Terminée', 'cancelled' => 'Annulée', _ => 'À faire',
  };
  String _priority(String value) => switch (value) {
    'urgent' => 'Urgente', 'high' => 'Haute', 'low' => 'Basse', _ => 'Normale',
  };
  String _memberName(String? id) {
    if (id == null) return 'Non assignée';
    Map<String, dynamic>? found;
    for (final member in _members) { if (member['user_id'] == id) { found = member; break; } }
    return (found?['full_name'] ?? found?['email'] ?? 'Membre').toString();
  }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final filtered = _tasks.where((t) => _filter == 'all' || t['status'] == _filter).toList();
    final done = _tasks.where((t) => t['status'] == 'done').length;
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 32), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tâches du projet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text('Répartissez le travail et suivez ce qui reste à accomplir.', style: Theme.of(context).textTheme.bodySmall),
          ])),
          if (_canEdit) FilledButton.icon(onPressed: _saving ? null : () => _edit(), icon: const Icon(Icons.add), label: const Text('Nouvelle tâche')),
        ]),
        const SizedBox(height: 16),
        if (!_loading && _error == null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_tasks.length} tâche(s)', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text('$done terminée(s)', style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: _tasks.isEmpty ? 0 : done / _tasks.length, minHeight: 7)),
        ]))),
        const SizedBox(height: 12),
        if (!_loading && _error == null) Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in const [('all','Toutes'),('todo','À faire'),('in_progress','En cours'),('done','Terminées'),('cancelled','Annulées')])
            ChoiceChip(label: Text(f.$2), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1)),
        ]),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Expanded(child: Text(_error!)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]))),
        if (!_loading && _error == null && filtered.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [
          Icon(Icons.task_alt_outlined, size: 38, color: p.goldText),
          const SizedBox(height: 12),
          Text(_tasks.isEmpty ? 'Aucune tâche pour le moment' : 'Aucune tâche dans ce filtre', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(_canEdit ? 'Créez une tâche et attribuez-la à un membre de l’équipe.' : 'Les tâches du projet apparaîtront ici.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ]))),
        for (final task in filtered) Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(task['title'].toString(), style: Theme.of(context).textTheme.titleSmall)),
            if (_canEdit) PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(task); if (v == 'delete') _delete(task); },
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Modifier')), PopupMenuItem(value: 'delete', child: Text('Supprimer'))]),
          ]),
          if ((task['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(task['description'].toString(), style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Chip(label: Text(_priority(task['priority'].toString())), visualDensity: VisualDensity.compact),
            Chip(label: Text(_memberName(task['assignee_id']?.toString())), avatar: const Icon(Icons.person_outline, size: 16), visualDensity: VisualDensity.compact),
            if (task['due_date'] != null) Chip(label: Text('Pour le ${task['due_date']}'), avatar: const Icon(Icons.calendar_today_outlined, size: 14), visualDensity: VisualDensity.compact),
            if (_canEdit) DropdownButton<String>(value: task['status'].toString(), underline: const SizedBox.shrink(),
              onChanged: (v) { if (v != null) _quickStatus(task, v); },
              items: const [
                DropdownMenuItem(value: 'todo', child: Text('À faire')),
                DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
                DropdownMenuItem(value: 'done', child: Text('Terminée')),
                DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
              ])
            else Chip(label: Text(_status(task['status'].toString())), visualDensity: VisualDensity.compact),
          ]),
        ]))),
      ]))),
    ]));
  }
}
