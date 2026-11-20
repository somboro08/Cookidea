import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';

class ProjectWorkspacePage extends StatefulWidget {
  const ProjectWorkspacePage({super.key, required this.project, required this.supabaseEnabled});
  final Map<String, dynamic> project;
  final bool supabaseEnabled;
  @override
  State<ProjectWorkspacePage> createState() => _ProjectWorkspacePageState();
}

class _ProjectWorkspacePageState extends State<ProjectWorkspacePage> {
  late final TextEditingController _problem;
  late final TextEditingController _audience;
  late int _maturity;
  bool _saving = false;
  static const _stages = ['Intuition', 'Idée', 'Problème', 'Opportunité', 'Concept', 'Validation', 'MVP', 'Traction', 'Business', 'Startup'];

  @override
  void initState() {
    super.initState();
    _problem = TextEditingController(text: widget.project['problem_statement']?.toString() ?? '');
    _audience = TextEditingController(text: widget.project['target_audience']?.toString() ?? '');
    _maturity = (widget.project['current_maturity_level'] as num?)?.toInt() ?? 0;
  }

  @override
  void dispose() { _problem.dispose(); _audience.dispose(); super.dispose(); }

  Future<void> _saveExploration() async {
    if (!widget.supabaseEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez Supabase pour conserver ces informations.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('projects').update({
        'problem_statement': _problem.text.trim(),
        'target_audience': _audience.text.trim(),
      }).eq('id', widget.project['id'].toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exploration enregistrée.')));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : ' + e.message)));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _changeStage(int value) async {
    if (value == _maturity) return;
    final previous = _maturity;
    setState(() => _maturity = value);
    if (!widget.supabaseEnabled) return;
    try {
      await Supabase.instance.client.from('projects').update({'current_maturity_level': value}).eq('id', widget.project['id']);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _maturity = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Étape non modifiée : ' + e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final idea = widget.project['initial_idea']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Espace projet'), actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('Niveau ' + _maturity.toString() + '/9')))]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: ListView(
        padding: EdgeInsets.all(width < 600 ? 18 : 32),
        children: [
          Text(widget.project['name']?.toString() ?? 'Projet sans nom', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(idea.isEmpty ? 'Votre espace de travail pour faire grandir cette idée.' : idea, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          _SectionCard(title: 'Votre progression', subtitle: 'La maturité est un repère de travail, pas une note.', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(value: (_maturity + 1) / 10, minHeight: 7),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              value: _maturity, decoration: const InputDecoration(labelText: 'Étape actuelle'),
              items: [for (var i = 0; i < _stages.length; i++) DropdownMenuItem(value: i, child: Text(i.toString() + ' · ' + _stages[i]))],
              onChanged: (value) { if (value != null) _changeStage(value); },
            ),
          ])),
          const SizedBox(height: 18),
          _SectionCard(title: 'Explorer votre idée', subtitle: 'Comprenez le problème avant de chercher une solution.', child: Column(children: [
            TextField(controller: _problem, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Quel problème cherchez-vous à résoudre ?', hintText: 'Décrivez la difficulté observée, pour qui et dans quel contexte…', alignLabelWithHint: true)),
            const SizedBox(height: 16),
            TextField(controller: _audience, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Qui rencontre ce problème ?', hintText: 'Décrivez les personnes ou organisations concernées…', alignLabelWithHint: true)),
            const SizedBox(height: 18),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _saveExploration, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Enregistrer'))),
          ])),
          const SizedBox(height: 18),
          _SectionCard(title: 'Construire et vérifier', subtitle: 'Les prochains modules structureront chaque élément de votre démarche.', child: const Column(children: [
            _ComingModule(icon: Icons.lightbulb_outline, title: 'Hypothèses', description: 'Lister ce qui doit être vrai pour que votre idée fonctionne.'),
            Divider(height: 24),
            _ComingModule(icon: Icons.science_outlined, title: 'Expériences', description: 'Définir comment vérifier chaque hypothèse sur le terrain.'),
            Divider(height: 24),
            _ComingModule(icon: Icons.fact_check_outlined, title: 'Preuves et résultats', description: 'Conserver les observations et ce qu’elles permettent de conclure.'),
            Divider(height: 24),
            _ComingModule(icon: Icons.account_tree_outlined, title: 'Décisions', description: 'Décider de poursuivre, ajuster ou pivoter à partir des éléments recueillis.'),
          ])),
        ],
      ))),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title; final String subtitle; final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6),
    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height: 20), child,
  ])));
}

class _ComingModule extends StatelessWidget {
  const _ComingModule({required this.icon, required this.title, required this.description});
  final IconData icon; final String title; final String description;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: p.goldText, size: 22), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ])),
      const SizedBox(width: 8), Text('Bientôt', style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}