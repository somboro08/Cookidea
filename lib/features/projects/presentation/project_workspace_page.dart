import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import 'project_members_tab.dart';
import 'project_activity_tab.dart';

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
  late int _stage;
  bool _saving = false;
  static const stages = ['Intuition','Idée','Problème','Opportunité','Concept','Validation','MVP','Traction','Business','Startup'];

  @override
  void initState() {
    super.initState();
    _problem = TextEditingController(text: widget.project['problem_statement']?.toString() ?? '');
    _audience = TextEditingController(text: widget.project['target_audience']?.toString() ?? '');
    _stage = ((widget.project['current_maturity_level'] as num?)?.toInt() ?? 0).clamp(0, 9);
  }

  @override
  void dispose() { _problem.dispose(); _audience.dispose(); super.dispose(); }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _save() async {
    if (!widget.supabaseEnabled) { _message('Connectez Supabase pour enregistrer vos modifications.'); return; }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('projects').update({
        'problem_statement': _problem.text.trim(),
        'target_audience': _audience.text.trim(),
      }).eq('id', widget.project['id'].toString());
      if (mounted) _message('Cadrage enregistré.');
    } on PostgrestException catch (e) {
      if (mounted) _message('Enregistrement impossible : ${e.message}');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _changeStage(int value) async {
    final old = _stage;
    setState(() => _stage = value);
    if (!widget.supabaseEnabled) { _message('Connectez Supabase pour conserver cette progression.'); return; }
    try {
      await Supabase.instance.client.from('projects').update({'current_maturity_level': value}).eq('id', widget.project['id'].toString());
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _stage = old);
      _message('Étape non modifiée : ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final name = widget.project['name']?.toString() ?? 'Projet sans nom';
    final idea = widget.project['initial_idea']?.toString() ?? '';
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('${_stage + 1}/10')))],
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Cadrage'),
            Tab(icon: Icon(Icons.lightbulb_outline), text: 'Hypothèses'),
            Tab(icon: Icon(Icons.science_outlined), text: 'Expériences'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Preuves'),
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Décisions'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Équipe'),
            Tab(icon: Icon(Icons.history), text: 'Activité'),
          ]),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                if (idea.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(idea, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (_stage + 1) / 10, minHeight: 7))),
                  const SizedBox(width: 12),
                  Text(stages[_stage], style: Theme.of(context).textTheme.labelLarge),
                ]),
              ]),
            )),
          ),
          const Divider(height: 1),
          Expanded(child: TabBarView(children: [
            _framing(p),
            for (final config in configs) _RecordsTab(key: ValueKey(config.table), projectId: widget.project['id'].toString(), enabled: widget.supabaseEnabled, config: config),
            ProjectMembersTab(projectId: widget.project['id'].toString(), enabled: widget.supabaseEnabled),
            ProjectActivityTab(projectId: widget.project['id'].toString(), enabled: widget.supabaseEnabled),
          ])),
        ]),
      ),
    );
  }

  Widget _framing(AppPalette p) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Panel(title: 'Comprendre le problème', subtitle: 'Une bonne solution commence par une compréhension précise du terrain.', child: Column(children: [
            TextField(controller: _problem, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Quel problème cherchez-vous à résoudre ?', hintText: 'Décrivez la difficulté observée, pour qui et dans quel contexte…', alignLabelWithHint: true)),
            const SizedBox(height: 16),
            TextField(controller: _audience, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Qui rencontre ce problème ?', hintText: 'Personnes, organisations, contexte…', alignLabelWithHint: true)),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 16,height: 16,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Enregistrer le cadrage'))),
          ])),
          const SizedBox(height: 16),
          _Panel(title: 'Stade de maturité', subtitle: 'Un repère pour savoir où concentrer vos efforts.', child: DropdownButtonFormField<int>(
            value: _stage, decoration: const InputDecoration(labelText: 'Étape actuelle'),
            items: [for (var i=0;i<stages.length;i++) DropdownMenuItem(value:i,child:Text('${i+1}. ${stages[i]}'))],
            onChanged: (v) { if (v != null) _changeStage(v); },
          )),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color:p.goldTint.withOpacity(.45),borderRadius:BorderRadius.circular(16),border:Border.all(color:p.gold.withOpacity(.3))), child: const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(Icons.tips_and_updates_outlined), SizedBox(width:12),
            Expanded(child:Text('Ne cherchez pas à prouver que votre idée est bonne. Cherchez d’abord à comprendre ce qui est vrai sur le terrain. Les hypothèses et les expériences vous aideront à le vérifier.')),
          ])),
        ]),
      )),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});
  final String title, subtitle; final Widget child;
  @override Widget build(BuildContext context) => Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:6),
    Text(subtitle,style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:20),child,
  ])));
}

class _Field {
  const _Field(this.keyName,this.label,this.hint,{this.multiline=false,this.options});
  final String keyName,label,hint; final bool multiline; final List<String>? options;
}
class _Config {
  const _Config(this.table,this.title,this.description,this.empty,this.icon,this.fields);
  final String table,title,description,empty; final IconData icon; final List<_Field> fields;
}
const configs = [
  _Config('project_hypotheses','Hypothèses à vérifier','Notez les suppositions qui doivent être vraies pour que votre projet fonctionne.','Aucune hypothèse pour le moment',Icons.lightbulb_outline,[
    _Field('title','Hypothèse','Ex. Les étudiants seraient prêts à payer pour…'),
    _Field('description','Pourquoi le pensez-vous ?','Votre raisonnement et les éléments manquants…',multiline:true),
    _Field('status','État','État',options:['À vérifier','Validée','Invalidée']),
  ]),
  _Config('project_experiments','Expériences terrain','Transformez vos hypothèses en petites expériences concrètes et mesurables.','Aucune expérience planifiée',Icons.science_outlined,[
    _Field('title','Expérience','Ex. Interroger 10 étudiants'),
    _Field('method','Méthode','Comment allez-vous procéder ?',multiline:true),
    _Field('success_criteria','Critère de réussite','Quel résultat confirmerait votre hypothèse ?',multiline:true),
    _Field('status','État','État',options:['À préparer','En cours','Terminée','Abandonnée']),
  ]),
  _Config('project_evidence','Preuves et apprentissages','Centralisez observations, entretiens, données et résultats.','Votre carnet de preuves est vide',Icons.fact_check_outlined,[
    _Field('title','Élément observé','Ex. 7 personnes sur 10 rencontrent ce problème'),
    _Field('description','Détail et enseignement','Que nous apprend cet élément ?',multiline:true),
    _Field('source','Source','Entretien, lien, document…'),
    _Field('evidence_type','Type de preuve','Type',options:['Observation','Entretien','Donnée','Document','Test']),
  ]),
  _Config('project_decisions','Décisions du projet','Gardez une trace des décisions et des raisons qui les motivent.','Aucune décision enregistrée',Icons.account_tree_outlined,[
    _Field('title','Décision','Ex. Tester une autre cible'),
    _Field('rationale','Pourquoi cette décision ?','Sur quelles preuves vous appuyez-vous ?',multiline:true),
    _Field('outcome','Orientation','Orientation',options:['Poursuivre','Ajuster','Pivoter','Arrêter','À décider']),
  ]),
];

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({super.key,required this.projectId,required this.enabled,required this.config});
  final String projectId; final bool enabled; final _Config config;
  @override State<_RecordsTab> createState()=>_RecordsTabState();
}
class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String,dynamic>> records=[]; bool loading=true,saving=false; String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(!widget.enabled){setState((){loading=false;error='Connectez Supabase pour créer et retrouver vos données.';});return;}
    setState((){loading=true;error=null;});
    try{
      final rows=await Supabase.instance.client.from(widget.config.table).select().eq('project_id',widget.projectId).order('created_at',ascending:false);
      if(!mounted)return;setState((){records=List<Map<String,dynamic>>.from(rows);loading=false;});
    }on PostgrestException catch(e){if(!mounted)return;setState((){error='Chargement impossible : ${e.message}';loading=false;});}
  }
  Future<void> _edit([Map<String,dynamic>? record]) async {
    final controllers=<String,TextEditingController>{for(final f in widget.config.fields)if(f.options==null)f.keyName:TextEditingController(text:record?[f.keyName]?.toString()??'')};
    final selections=<String,String>{for(final f in widget.config.fields)if(f.options!=null)f.keyName:f.options!.contains(record?[f.keyName]?.toString())?record![f.keyName].toString():f.options!.first};
    final values=await showDialog<Map<String,dynamic>>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,refresh)=>AlertDialog(
      title:Text(record==null?'Ajouter un élément':'Modifier l’élément'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(final f in widget.config.fields)...[
          if(f.options!=null)DropdownButtonFormField<String>(value:selections[f.keyName],decoration:InputDecoration(labelText:f.label),items:[for(final v in f.options!)DropdownMenuItem(value:v,child:Text(v))],onChanged:(v){if(v!=null)refresh(()=>selections[f.keyName]=v);})
          else TextField(controller:controllers[f.keyName],minLines:f.multiline?3:1,maxLines:f.multiline?5:1,decoration:InputDecoration(labelText:f.label,hintText:f.hint,alignLabelWithHint:f.multiline)),
          const SizedBox(height:14),
        ],
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Annuler')),
        FilledButton(onPressed:(){final data=<String,dynamic>{for(final e in controllers.entries)e.key:e.value.text.trim(),...selections};if((data['title']?.toString().trim().isEmpty??true))return;Navigator.pop(dialogContext,data);},child:const Text('Enregistrer')),
      ],
    )));
    for(final c in controllers.values){c.dispose();}
    if(values==null||!mounted)return;
    setState(()=>saving=true);
    try{
      if(record==null){await Supabase.instance.client.from(widget.config.table).insert({...values,'project_id':widget.projectId,'created_by':Supabase.instance.client.auth.currentUser!.id});}
      else{await Supabase.instance.client.from(widget.config.table).update(values).eq('id',record['id'].toString());}
      await _load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enregistrement effectué.')));
    }on PostgrestException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enregistrement impossible : ${e.message}')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> _delete(Map<String,dynamic> record) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Supprimer cet élément ?'),content:const Text('Cette action est définitive.'),actions:[
      TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),
      FilledButton.tonal(onPressed:()=>Navigator.pop(c,true),child:const Text('Supprimer')),
    ]));
    if(ok!=true)return;
    try{await Supabase.instance.client.from(widget.config.table).delete().eq('id',record['id'].toString());await _load();}
    on PostgrestException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Suppression impossible : ${e.message}')));}
  }
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.config.title, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 5),
                          Text(widget.config.description, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: !widget.enabled || saving ? null : () => _edit(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 12),
                          Expanded(child: Text(error!, style: Theme.of(context).textTheme.bodySmall)),
                          if (widget.enabled)
                            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                        ],
                      ),
                    ),
                  ),
                if (!loading && error == null && records.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(widget.config.icon, size: 34, color: p.goldText),
                          const SizedBox(height: 14),
                          Text(
                            widget.config.empty,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoutez un premier élément pour structurer votre démarche.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: !widget.enabled ? null : () => _edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('Créer le premier élément'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!loading)
                  for (final record in records)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: p.goldTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(widget.config.icon, color: p.goldText, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record['title']?.toString() ?? 'Sans titre',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  if ((record['description'] ??
                                          record['method'] ??
                                          record['rationale'] ??
                                          '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        (record['description'] ??
                                                record['method'] ??
                                                record['rationale'])
                                            .toString(),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 5,
                                    children: [
                                      for (final key in ['status', 'outcome', 'evidence_type'])
                                        if (record[key] != null) _Tag(record[key].toString()),
                                      if (record['source'] != null &&
                                          record['source'].toString().isNotEmpty)
                                        _Tag('Source : ${record['source']}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _edit(record);
                                if (value == 'delete') _delete(record);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
class _Tag extends StatelessWidget{
  const _Tag(this.label);final String label;
  @override Widget build(BuildContext context){final p=context.pal;return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:p.goldTint,borderRadius:BorderRadius.circular(20)),child:Text(label,style:Theme.of(context).textTheme.labelSmall?.copyWith(color:p.goldText)));}
}
