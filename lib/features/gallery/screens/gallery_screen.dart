import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../models/person_model.dart';
import '../models/meeting_model.dart';
import '../widgets/header_widget.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/tab_switcher_widget.dart';
import '../widgets/person_card_widget.dart';
import '../widgets/floating_camera_button.dart';
import 'person_detail_screen.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';
import '../../camera/screens/camera_home_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with WidgetsBindingObserver {
  int _selectedTab = 0;
  String _searchQuery = '';
  List<PersonModel> _people = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Reload when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final corePeople     = await StorageService.getAllPeople();
      final allMemoriesRaw = await StorageService.getAllMemoriesWithPeopleIds();

      // Build map: personId → list of memories
      final memoryMap = <String, List<MemoryWithPeopleIds>>{};
      for (final mw in allMemoriesRaw) {
        for (final pid in mw.peopleIds) {
          memoryMap.putIfAbsent(pid, () => []).add(mw);
        }
      }

      final uiPeople = <PersonModel>[];
      for (final p in corePeople) {
        final personMems = memoryMap[p.id] ?? [];

        final daysSince = DateTime.now().difference(p.lastSeen).inDays;
        final timeLabel = _dayLabel(daysSince);
        final strength  = p.relationshipStrength;
        final colorHex  = _strengthColor(strength);

        final meetings = personMems.map((mw) {
          final m       = mw.memory;
          final dateStr = DateFormat('MMM d, y').format(m.dateTime);
          final isLocal = !m.imagePath.startsWith('http');
          return MeetingModel(
            id:        m.id,
            title:     p.notes?.isNotEmpty == true ? p.notes! : 'Meeting',
            date:      dateStr,
            notes:     m.notes ?? '',
            imagePath: isLocal ? m.imagePath : null,
            imageUrl:  isLocal ? null : m.imagePath,
          );
        }).toList();

        final lastLocation = personMems.isNotEmpty &&
                personMems.first.memory.location != null &&
                personMems.first.memory.location!.isNotEmpty
            ? personMems.first.memory.location!
            : 'Unknown';

        uiPeople.add(PersonModel(
          id:             p.id,
          name:           p.name,
          timeLabel:      timeLabel,
          meetingCount:   p.memoryIds.length,
          indicatorColor: colorHex,
          imagePath:      p.avatarPath,
          tag:            p.tags.isNotEmpty ? p.tags.first : 'Friend',
          strength:       strength,
          lastLocation:   lastLocation,
          meetings:       meetings,
        ));
      }

      uiPeople.sort((a, b) =>
          _daysFromLabel(a.timeLabel).compareTo(_daysFromLabel(b.timeLabel)));

      if (mounted) {
        setState(() {
          _people  = uiPeople;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Gallery] _loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dayLabel(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7)  return '$days days ago';
    if (days < 30) {
      final w = (days / 7).floor();
      return '$w ${w == 1 ? "week" : "weeks"} ago';
    }
    final mo = (days / 30).floor();
    return '$mo ${mo == 1 ? "month" : "months"} ago';
  }

  String _strengthColor(String strength) {
    switch (strength) {
      case 'Close':   return '10B981';
      case 'Regular': return '4F46E5';
      case 'Recent':  return 'F59E0B';
      default:        return '8B5CF6';
    }
  }

  int _daysFromLabel(String label) {
    final l = label.toLowerCase();
    if (l == 'today')     return 0;
    if (l == 'yesterday') return 1;
    if (l.contains('days ago'))  return int.tryParse(l.split(' ').first) ?? 99;
    if (l.contains('week'))      return (int.tryParse(l.split(' ').first) ?? 1) * 7;
    if (l.contains('month'))     return (int.tryParse(l.split(' ').first) ?? 1) * 30;
    return 999;
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<PersonModel> get _filteredPeople {
    if (_searchQuery.isEmpty) return _people;
    final q = _searchQuery.toLowerCase();
    return _people.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.tag.toLowerCase().contains(q) ||
        p.lastLocation.toLowerCase().contains(q)).toList();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
        .then((_) => _loadData());
  }

  void _openPersonDetail(PersonModel person) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => PersonDetailScreen(person: person),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _goToCamera() {
    // Always navigate to camera — replace entire stack so camera is root
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CameraHomeScreen()),
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: SafeArea(
        child: Column(
          children: [
            HeaderWidget(onSettingsTap: _openSettings),

            // Search bar — only on People tab
            if (_selectedTab == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SearchBarWidget(
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ),

            // Tab switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TabSwitcherWidget(
                tabs: const ['People', 'Timeline', 'Memories'],
                selectedIndex: _selectedTab,
                onTabSelected: (i) => setState(() {
                  _selectedTab = i;
                  _searchQuery = '';
                }),
              ),
            ),

            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingCameraButton(onTap: _goToCamera),
    );
  }

  Widget _buildTabContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    switch (_selectedTab) {
      case 0: return _buildPeopleGrid();
      case 1: return const TimelineScreen();
      case 2: return _buildMemoriesTab();
      default: return _buildPeopleGrid();
    }
  }

  // ── People grid ───────────────────────────────────────────────────────────

  Widget _buildPeopleGrid() {
    final people = _filteredPeople;

    if (people.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: _searchQuery.isEmpty ? 'No people yet' : 'No people found',
        subtitle: _searchQuery.isEmpty
            ? 'Capture a photo and add details to see people here'
            : 'Try a different search term',
        action: _searchQuery.isEmpty
            ? _EmptyAction(label: 'Open Camera', onTap: _goToCamera)
            : null,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: people.length,
        itemBuilder: (context, index) => _AnimatedCard(
          index: index,
          child: PersonCardWidget(
            person: people[index],
            animationIndex: index,
            onTap: () => _openPersonDetail(people[index]),
          ),
        ),
      ),
    );
  }

  // ── Memories tab ──────────────────────────────────────────────────────────

  Widget _buildMemoriesTab() {
    final reminders = _buildReminders();

    if (reminders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'No reminders yet',
        subtitle: 'Smart reminders appear once you have memories\nwith people you haven\'t seen in a while',
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: reminders.length,
        itemBuilder: (_, i) => _AnimatedCard(
          index: i,
          child: _ReminderCard(reminder: reminders[i]),
        ),
      ),
    );
  }

  List<_Reminder> _buildReminders() {
    final reminders = <_Reminder>[];
    for (final p in _people) {
      final days = _daysFromLabel(p.timeLabel);
      if (days < 3) continue;

      String msg;
      if (days < 7) {
        msg = 'You haven\'t seen ${p.name} in $days days. Say hi!';
      } else if (days < 30) {
        final w = (days / 7).floor();
        msg = 'It\'s been $w ${w == 1 ? "week" : "weeks"} since you met ${p.name}.';
      } else {
        final mo = (days / 30).floor();
        msg = '${p.name} — $mo ${mo == 1 ? "month" : "months"} since you last met!';
      }

      reminders.add(_Reminder(
        name:       p.name,
        message:    msg,
        avatarPath: p.imagePath,
        color:      _hexColor(p.indicatorColor),
        daysAgo:    days,
      ));
    }
    reminders.sort((a, b) => b.daysAgo.compareTo(a.daysAgo));
    return reminders.take(10).toList();
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    _EmptyAction? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textMuted, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: action.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.primaryGlow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(action.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helper types ──────────────────────────────────────────────────────────────

class _EmptyAction {
  final String label;
  final VoidCallback onTap;
  const _EmptyAction({required this.label, required this.onTap});
}

class _Reminder {
  final String name;
  final String message;
  final String? avatarPath;
  final Color color;
  final int daysAgo;
  const _Reminder({
    required this.name,
    required this.message,
    this.avatarPath,
    required this.color,
    required this.daysAgo,
  });
}

// ── Staggered card animation ──────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ── Reminder card ─────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final _Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(radius: 16),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text(reminder.message,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: reminder.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${reminder.daysAgo}d',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: reminder.color)),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: reminder.color.withOpacity(0.3), width: 2),
      ),
      child: ClipOval(
        child: reminder.avatarPath != null &&
                reminder.avatarPath!.isNotEmpty &&
                !reminder.avatarPath!.startsWith('http')
            ? Image.file(File(reminder.avatarPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: reminder.color.withOpacity(0.1),
        child: Center(
          child: Text(
            reminder.name.isNotEmpty ? reminder.name[0].toUpperCase() : '?',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: reminder.color),
          ),
        ),
      );
}
