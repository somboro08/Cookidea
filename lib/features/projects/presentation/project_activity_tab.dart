import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';

class ProjectActivityTab extends StatefulWidget {
  const ProjectActivityTab({super.key, required this.projectId, required this.enabled});
  final String projectId;
  final bool enabled;

  @override
  State<ProjectActivityTab> createState() => _ProjectActivityTabState();
}

class _ProjectActivityTabState extends State<ProjectActivityTab> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!widget.enabled) {
      setState(() { _loading = false; _error = 'Connectez Supabase pour consulter l’activité.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .from('project_activity')
          .select('id,event_type,title,description,created_at')
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false)
          .limit(60);
      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Impossible de charger l’activité : ${e.message}'; _loading = false; });
    }
  }

  IconData _icon(String type) => switch (type) {
    'project_created' => Icons.add_circle_outline,
    'member_added' => Icons.person_add_alt_1,
    'member_removed' => Icons.person_remove_alt_1,
    'member_role_changed' => Icons.admin_panel_settings_outlined,
    'project_email_sent' => Icons.mail_outline,
    _ => Icons.edit_note,
  };

  String _date(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays == 1;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Aujourd’hui à $time';
    if (yesterday) return 'Hier à $time';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 32), children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activité du projet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text('Retrouvez les changements et les événements importants de votre équipe.', style: Theme.of(context).textTheme.bodySmall),
              ])),
              IconButton(onPressed: _loading ? null : _load, tooltip: 'Actualiser', icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 18),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(_error!))),
            if (!_loading && _error == null && _events.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [
              Icon(Icons.history, size: 38, color: p.goldText),
              const SizedBox(height: 12),
              Text('Aucune activité pour le moment', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Les créations, modifications d’équipe et décisions apparaîtront ici.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ]))),
            if (!_loading && _events.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
              for (var i = 0; i < _events.length; i++) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: p.goldTint, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_icon(_events[i]['event_type']?.toString() ?? ''), color: p.goldText, size: 19)),
                    if (i != _events.length - 1) Container(width: 1, height: 38, color: p.divider),
                  ]),
                  const SizedBox(width: 13),
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 2, bottom: 18), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_events[i]['title']?.toString() ?? 'Événement', style: Theme.of(context).textTheme.titleSmall),
                      if ((_events[i]['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_events[i]['description'].toString(), style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: 5),
                      Text(_date(_events[i]['created_at']?.toString()), style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ))),
                ]),
              ],
            ]))),
          ],
        ))),
      ]),
    );
  }
}
