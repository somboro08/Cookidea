import 'package:flutter/material.dart';

const _ink = Color(0xFF202238);
const _muted = Color(0xFF85899D);
const _purple = Color(0xFF635BFF);
const _line = Color(0xFFE9EAF2);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final List<_ProjectDraft> _projects = [];

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    final ideaController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Donnez vie à une idée'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nom du projet',
                  hintText: 'Ex. Une plateforme de logement étudiant',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ideaController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Votre idée, en quelques mots',
                  hintText: 'Décrivez librement ce que vous avez en tête...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _projects.insert(
                  0,
                  _ProjectDraft(
                    name: name,
                    idea: ideaController.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Projet ajouté à cet aperçu local.'),
                ),
              );
            },
            child: const Text('Créer mon projet'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      ideaController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 820;

    return Scaffold(
      drawer: compact ? Drawer(child: _Sidebar(
        selectedIndex: _selectedIndex,
        onSelect: (index) {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      )) : null,
      body: Row(
        children: [
          if (!compact)
            SizedBox(
              width: 248,
              child: _Sidebar(
                selectedIndex: _selectedIndex,
                onSelect: (index) => setState(() => _selectedIndex = index),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  compact: compact,
                  onCreateProject: _showCreateProjectDialog,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 600 ? 20 : 36,
                      vertical: 30,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: _selectedIndex == 0
                            ? _DashboardContent(
                                projects: _projects,
                                onCreateProject: _showCreateProjectDialog,
                              )
                            : _ComingSoonContent(
                                title: _navigationItems[_selectedIndex].label,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.onCreateProject,
  });

  final bool compact;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          if (compact) ...[
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.grid_view_rounded, size: 18, color: _muted),
          const SizedBox(width: 10),
          const Text(
            'Mon espace',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle idée'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: const BorderSide(color: Color(0xFFDCD9FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            ),
          ),
          const SizedBox(width: 16),
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFF0EFFF),
            child: Icon(Icons.person_outline_rounded, color: _purple, size: 19),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 26, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 38),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'cookidea',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (var i = 0; i < _navigationItems.length; i++)
            _NavTile(
              item: _navigationItems[i],
              selected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFECEAFF)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: _purple, size: 19),
                SizedBox(height: 9),
                Text(
                  'Une idée en tête ?',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Commencez simplement. Cookidea vous guidera.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: _line),
          const SizedBox(height: 8),
          const _NavTile(
            item: _NavItem(Icons.settings_outlined, 'Paramètres'),
            selected: false,
            onTap: _noop,
          ),
        ],
      ),
    );
  }
}

const _noop = _emptyCallback;

void _emptyCallback() {}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _navigationItems = [
  _NavItem(Icons.space_dashboard_outlined, 'Vue d’ensemble'),
  _NavItem(Icons.folder_open_outlined, 'Mes projets'),
  _NavItem(Icons.explore_outlined, 'Explorer une idée'),
  _NavItem(Icons.account_tree_outlined, 'Carte d’entreprise'),
  _NavItem(Icons.auto_awesome_outlined, 'Assistant IA'),
];

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? const Color(0xFFF0EFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: selected ? _purple : _muted,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? _purple : const Color(0xFF5D6175),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.projects,
    required this.onCreateProject,
  });

  final List<_ProjectDraft> projects;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bonjour 👋',
          style: TextStyle(
            color: _ink,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Chaque grande réalisation commence par une idée.',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Mes idées',
                value: projects.length.toString().padLeft(2, '0'),
                tint: const Color(0xFFF0EFFF),
                iconColor: _purple,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: _StatCard(
                icon: Icons.track_changes_outlined,
                label: 'En maturation',
                value: '—',
                tint: Color(0xFFEAF7F2),
                iconColor: Color(0xFF25966A),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: _StatCard(
                icon: Icons.task_alt_rounded,
                label: 'Actions à venir',
                value: '—',
                tint: Color(0xFFFFF4E8),
                iconColor: Color(0xFFE49A43),
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Row(
          children: [
            const Text(
              'Vos projets',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onCreateProject,
              child: const Text('Créer un projet'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (projects.isEmpty)
          _EmptyProjects(onCreateProject: onCreateProject)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 760 ? 2 : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final project in projects)
                    SizedBox(
                      width: (constraints.maxWidth - (columns - 1) * 16) /
                          columns,
                      child: _ProjectCard(project: project),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 28),
        const _GettingStartedCard(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 17),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_objects_outlined,
              color: _purple,
              size: 31,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Votre prochain projet commence ici',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 390,
            child: Text(
              'Vous n’avez pas besoin d’avoir toutes les réponses. '
              'Décrivez simplement votre idée, et nous avancerons ensemble.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Créer ma première idée'),
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final _ProjectDraft project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _purple, size: 19),
              Spacer(),
              Text(
                'BROUILLON',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            project.name,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (project.idea.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              project.idea,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 15),
          Text(
            'Créé le ${project.createdAt.day.toString().padLeft(2, '0')}/'
            '${project.createdAt.month.toString().padLeft(2, '0')}/'
            '${project.createdAt.year}',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0EFFF), Color(0xFFF9F8FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E5FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: _purple, size: 22),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pas besoin d’une idée parfaite.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Cookidea est conçu pour vous aider à clarifier vos pensées, '
                  'identifier les bonnes questions et transformer vos intuitions '
                  'en étapes concrètes.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonContent extends StatelessWidget {
  const _ComingSoonContent({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          const Icon(Icons.construction_outlined, color: _purple, size: 36),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ce module sera activé dans une prochaine étape du développement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProjectDraft {
  const _ProjectDraft({
    required this.name,
    required this.idea,
    required this.createdAt,
  });

  final String name;
  final String idea;
  final DateTime createdAt;
}
