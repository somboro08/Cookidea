import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.supabaseEnabled});
  final bool supabaseEnabled;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _loading = true;
  bool _creating = false;
  String? _loadError;
  final List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (widget.supabaseEnabled) {
      try {
        final rows = await Supabase.instance.client
            .from('projects')
            .select('id,name,initial_idea,description,status,current_maturity_level,created_at,updated_at')
            .order('updated_at', ascending: false);
        if (!mounted) return;
        setState(() {
          _projects
            ..clear()
            ..addAll(List<Map<String, dynamic>>.from(rows));
          _loadError = null;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() { _loadError = 'Impossible de charger vos projets. Vérifiez votre connexion puis réessayez.'; _loading = false; });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createProject(String name, String idea) async {
    setState(() => _creating = true);
    try {
      Map<String, dynamic> project;
      if (widget.supabaseEnabled) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('Session expirée. Reconnectez-vous.');
        project = await Supabase.instance.client.from('projects').insert({
          'owner_id': user.id,
          'name': name,
          'initial_idea': idea,
          'description': idea,
        }).select('id,name,initial_idea,description,status,current_maturity_level,created_at,updated_at').single();
      } else {
        project = {
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'name': name, 'initial_idea': idea, 'description': idea,
          'status': 'draft', 'current_maturity_level': 0,
          'created_at': DateTime.now().toIso8601String(),
        };
      }
      if (!mounted) return;
      setState(() { _projects.insert(0, project); _loadError = null; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.supabaseEnabled ? 'Projet enregistré dans votre espace.' : 'Projet ajouté à cet aperçu local.')),
      );
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _showCreateProjectDialog() async {
    final name = TextEditingController();
    final idea = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Donnez vie à une idée'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller:name, autofocus:true, textCapitalization:TextCapitalization.sentences,
              decoration:const InputDecoration(labelText:'Nom du projet',hintText:'Ex. Une plateforme de logement étudiant')),
            const SizedBox(height:14),
            TextField(controller:idea,minLines:3,maxLines:5,
              decoration:const InputDecoration(labelText:'Votre idée, en quelques mots',hintText:'Décrivez librement ce que vous avez en tête...',alignLabelWithHint:true)),
          ]),
        ),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Annuler')),
          FilledButton(onPressed:()=>Navigator.pop(dialogContext,[name.text.trim(),idea.text.trim()]),child:const Text('Créer mon projet')),
        ],
      ),
    );
    name.dispose(); idea.dispose();
    if (result != null && result.first.isNotEmpty) await _createProject(result.first,result.length>1?result[1]:'');
  }

  Future<void> _signOut() async {
    if (widget.supabaseEnabled) await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final p = context.pal;
    return Scaffold(
      drawer: compact ? Drawer(
        backgroundColor:p.bg,
        child:_Sidebar(selectedIndex:_selectedIndex,onSelect:(i){setState(()=>_selectedIndex=i);Navigator.pop(context);},onSignOut:_signOut),
      ) : null,
      body: Row(children:[
        if (!compact) SizedBox(width:260,child:_Sidebar(selectedIndex:_selectedIndex,onSelect:(i)=>setState(()=>_selectedIndex=i),onSignOut:_signOut)),
        Expanded(child:Column(children:[
          _TopBar(compact:compact,onCreate:_showCreateProjectDialog,onSignOut:_signOut),
          Expanded(child:SingleChildScrollView(
            padding:EdgeInsets.symmetric(horizontal:width<600?18:width<1000?28:44,vertical:width<600?24:36),
            child:Center(child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:1160),
              child:_selectedIndex<=1
                ? _DashboardContent(projects:_projects,loading:_loading,error:_loadError,onRetry:_loadProjects,onCreate:_showCreateProjectDialog,projectsOnly:_selectedIndex==1)
                : _Placeholder(title:_navItems[_selectedIndex].label),
            )),
          )),
        ])),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact,required this.onCreate,required this.onSignOut});
  final bool compact; final VoidCallback onCreate; final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    return Container(height:76,padding:EdgeInsets.symmetric(horizontal:compact?12:30),
      decoration:BoxDecoration(color:p.bg,border:Border(bottom:BorderSide(color:p.divider))),
      child:Row(children:[
        if(compact) Builder(builder:(context)=>IconButton(onPressed:()=>Scaffold.of(context).openDrawer(),icon:const Icon(IconsaxMenu.icon))),
        Icon(AppIcons.dashboard,size:20,color:p.textSoft),
        const SizedBox(width:12),
        Text('Mon espace',style:Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        if(!compact) OutlinedButton.icon(onPressed:onCreate,icon:const Icon(AppIcons.add,size:19),label:const Text('Nouvelle idée')),
        if(compact) IconButton(onPressed:onCreate,tooltip:'Nouvelle idée',icon:const Icon(AppIcons.add)),
        const SizedBox(width:8),
        PopupMenuButton<String>(
          tooltip:'Compte',
          onSelected:(v){if(v=='logout')onSignOut();},
          itemBuilder:(_)=>const [PopupMenuItem(value:'logout',child:Text('Se déconnecter'))],
          child:CircleAvatar(radius:18,backgroundColor:p.goldTint,child:Icon(AppIcons.user,size:19,color:p.text)),
        ),
      ]),
    );
  }
}

abstract final class IconsaxMenu { static const icon = Icons.menu_rounded; }

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex,required this.onSelect,required this.onSignOut});
  final int selectedIndex; final ValueChanged<int> onSelect; final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    return Container(color:p.bg,padding:const EdgeInsets.fromLTRB(18,26,14,20),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.only(left:8,bottom:42),child:Row(children:[
          Container(width:38,height:38,decoration:BoxDecoration(color:p.gold,borderRadius:BorderRadius.circular(13)),child:Icon(AppIcons.idea,color:p.onGold,size:22)),
          const SizedBox(width:11),
          Text('cookidea',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800,letterSpacing:-.7)),
        ])),
        Padding(padding:const EdgeInsets.only(left:10,bottom:13),child:Text('WORKSPACE',style:Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing:1.4))),
        for(var i=0;i<_navItems.length;i++)
          _NavTile(item:_navItems[i],selected:selectedIndex==i,onTap:()=>onSelect(i)),
        const Spacer(),
        Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:p.card,borderRadius:BorderRadius.circular(16),border:Border.all(color:p.divider)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(AppIcons.sparkles,color:p.gold,size:21),const SizedBox(height:10),
            Text('Une idée en tête ?',style:Theme.of(context).textTheme.labelLarge),
            const SizedBox(height:5),
            Text('Commencez simplement. Cookidea vous guidera.',style:Theme.of(context).textTheme.bodySmall),
          ])),
        const SizedBox(height:18),const Divider(),const SizedBox(height:8),
        _NavTile(item:const _NavItem(AppIcons.settings,'Paramètres'),selected:false,onTap:onSignOut),
      ]),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon,this.label);
  final IconData icon; final String label;
}
const _navItems=[
  _NavItem(AppIcons.dashboard,'Vue d’ensemble'),
  _NavItem(AppIcons.projects,'Mes projets'),
  _NavItem(AppIcons.explore,'Explorer une idée'),
  _NavItem(AppIcons.map,'Carte d’entreprise'),
  _NavItem(AppIcons.assistant,'Assistant IA'),
];

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item,required this.selected,required this.onTap});
  final _NavItem item; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    return Padding(padding:const EdgeInsets.only(bottom:5),child:Material(
      color:selected?p.goldTint:Colors.transparent,borderRadius:BorderRadius.circular(12),
      child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),
        child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),child:Row(children:[
          Icon(item.icon,size:21,color:selected?p.text:p.textSoft),
          const SizedBox(width:13),
          Expanded(child:Text(item.label,style:Theme.of(context).textTheme.labelMedium?.copyWith(color:selected?p.text:p.textSoft,fontWeight:selected?FontWeight.w700:FontWeight.w500))),
        ])),
      ),
    ));
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.projects,required this.loading,required this.error,required this.onRetry,required this.onCreate,required this.projectsOnly});
  final List<Map<String,dynamic>> projects; final bool loading; final String? error;
  final VoidCallback onRetry,onCreate; final bool projectsOnly;

  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(projectsOnly?'Vos projets':'Bonjour 👋',style:Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height:8),
      Text(projectsOnly?'Retrouvez et faites évoluer toutes vos idées.':'Chaque grande réalisation commence par une idée.',style:Theme.of(context).textTheme.bodySmall),
      if(!projectsOnly) ...[
        const SizedBox(height:30),
        LayoutBuilder(builder:(context,c){
          final columns=c.maxWidth<520?1:c.maxWidth<850?2:3;
          final cards=[
            _StatCard(icon:AppIcons.idea,label:'Mes idées',value:projects.length.toString().padLeft(2,'0')),
            const _StatCard(icon:AppIcons.clock,label:'En maturation',value:'—'),
            const _StatCard(icon:AppIcons.task,label:'Actions à venir',value:'—'),
          ];
          return Wrap(spacing:14,runSpacing:14,children:[
            for(final card in cards) SizedBox(width:(c.maxWidth-(columns-1)*14)/columns,child:card),
          ]);
        }),
      ],
      const SizedBox(height:34),
      Row(children:[
        Expanded(child:Text(projectsOnly?'Tous vos projets':'Vos projets',style:Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(onPressed:onCreate,icon:const Icon(AppIcons.add,size:18),label:const Text('Créer un projet')),
      ]),
      const SizedBox(height:14),
      if(error!=null) Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
        Expanded(child:Text(error!,style:TextStyle(color:p.danger))),
        IconButton(onPressed:onRetry,icon:const Icon(Icons.refresh)),
      ]))),
      if(loading) const Padding(padding:EdgeInsets.all(40),child:Center(child:CircularProgressIndicator())),
      if(!loading && error==null && projects.isEmpty) _EmptyProjects(onCreate:onCreate),
      if(!loading && projects.isNotEmpty) LayoutBuilder(builder:(context,c){
        final columns=c.maxWidth>760?2:1;
        return Wrap(spacing:16,runSpacing:16,children:[
          for(final project in projects)
            SizedBox(width:(c.maxWidth-(columns-1)*16)/columns,child:_ProjectCard(project:project)),
        ]);
      }),
      if(!projectsOnly) ...[
        const SizedBox(height:28),
        Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:p.goldTint.withOpacity(.42),borderRadius:BorderRadius.circular(18),border:Border.all(color:p.gold.withOpacity(.35))),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(AppIcons.sparkles,color:p.goldText,size:23),const SizedBox(width:14),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Pas besoin d’une idée parfaite.',style:Theme.of(context).textTheme.titleSmall),
              const SizedBox(height:6),
              Text('Cookidea vous aide à clarifier vos pensées, identifier les bonnes questions et transformer vos intuitions en étapes concrètes.',style:Theme.of(context).textTheme.bodySmall),
            ])),
          ])),
      ],
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon,required this.label,required this.value});
  final IconData icon; final String label,value;
  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:38,height:38,decoration:BoxDecoration(color:p.goldTint,borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:p.goldText,size:21)),
      const SizedBox(height:18),
      Text(value,style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:4),
      Text(label,style:Theme.of(context).textTheme.bodySmall),
    ])));
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    return Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:24,vertical:44),
      decoration:BoxDecoration(color:p.card,borderRadius:BorderRadius.circular(20),border:Border.all(color:p.divider)),
      child:Column(children:[
        Container(width:72,height:72,decoration:BoxDecoration(color:p.goldTint,shape:BoxShape.circle),child:Icon(AppIcons.idea,color:p.goldText,size:32)),
        const SizedBox(height:20),
        Text('Votre prochain projet commence ici',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:9),
        ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Text('Vous n’avez pas besoin d’avoir toutes les réponses. Décrivez simplement votre idée, et nous avancerons ensemble.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height:24),
        FilledButton.icon(onPressed:onCreate,icon:const Icon(AppIcons.add),label:const Text('Créer ma première idée'),style:FilledButton.styleFrom(backgroundColor:p.gold,foregroundColor:p.onGold,padding:const EdgeInsets.symmetric(horizontal:20,vertical:17))),
      ]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Map<String,dynamic> project;
  @override
  Widget build(BuildContext context) {
    final p=context.pal;
    final status=project['status']?.toString()??'draft';
    final idea=(project['initial_idea']??project['description']??'').toString();
    final created=DateTime.tryParse(project['created_at']?.toString()??'');
    return Card(child:Padding(padding:const EdgeInsets.all(19),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(AppIcons.idea,color:p.goldText,size:21),const Spacer(),
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:p.goldTint,borderRadius:BorderRadius.circular(20)),child:Text(status=='draft'?'BROUILLON':status.toUpperCase(),style:Theme.of(context).textTheme.labelSmall?.copyWith(color:p.goldText,fontSize:11))),
      ]),
      const SizedBox(height:16),
      Text(project['name']?.toString()??'Projet sans nom',style:Theme.of(context).textTheme.titleMedium),
      if(idea.isNotEmpty) ...[const SizedBox(height:8),Text(idea,maxLines:3,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall)],
      const SizedBox(height:18),
      Row(children:[
        Icon(AppIcons.clock,size:15,color:p.textSoft),const SizedBox(width:7),
        Text(created==null?'Récemment créé':'Créé le ${created.day.toString().padLeft(2,'0')}/${created.month.toString().padLeft(2,'0')}/${created.year}',style:Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        Text('Niveau ${project['current_maturity_level']??0}/9',style:Theme.of(context).textTheme.labelSmall),
      ]),
    ])));
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(child:Padding(padding:const EdgeInsets.all(32),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(AppIcons.sparkles,size:38,color:context.pal.gold),const SizedBox(height:16),
    Text(title,style:Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height:8),
    Text('Ce module sera construit dans une prochaine étape.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
  ])));
}
