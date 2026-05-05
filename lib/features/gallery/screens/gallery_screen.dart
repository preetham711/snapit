import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/models/memory_model.dart';
import '../models/person_model.dart';
import '../models/meeting_model.dart';
import '../widgets/header_widget.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/tab_switcher_widget.dart';
import '../widgets/person_card_widget.dart';
import 'person_detail_screen.dart';
import 'settings_screen.dart';
import '../../camera/screens/camera_home_screen.dart';
import '../../camera/screens/add_details_screen.dart';

// Google Photos-style gallery:
//   Tab 1 "Photos"  — all photos in date-grouped grid (from Firestore + local)
//   Tab 2 "People"  — person cards
//   Tab 3 "Memories"— smart reminders
// FAB → camera

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
  List<Memory> _allMemories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _subscribeToCloud();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  void _subscribeToCloud() {
    CloudSyncService.instance.memoriesStream().listen(
      (cloudMemories) {
        if (!mounted || cloudMemories.isEmpty) return;
        setState(() => _allMemories = cloudMemories);
      },
      onError: (e) => debugPrint('[Gallery] cloud stream error: $e'),
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final corePeople     = await StorageService.getAllPeople();
      final allMemoriesRaw = await StorageService.getAllMemoriesWithPeopleIds();
      final localMemories  = await StorageService.getAllMemories();

      // Build person → memories map
      final memoryMap = <String, List<MemoryWithPeopleIds>>{};
      for (final mw in allMemoriesRaw) {
        for (final pid in mw.peopleIds) {
          memoryMap.putIfAbsent(pid, () => []).add(mw);
        }
      }

      final uiPeople = <PersonModel>[];
      for (final p in corePeople) {
        final personMems = memoryMap[p.id] ?? [];
        final daysSince  = DateTime.now().difference(p.lastSeen).inDays;
        final timeLabel  = _dayLabel(daysSince);
        final strength   = p.relationshipStrength;
        final colorHex   = _strengthColor(strength);

        final meetings = personMems.map((mw) {
          final m       = mw.memory;
          final dateStr = DateFormat('MMM d, y').format(m.dateTime);
          final isLocal = !m.imagePath.startsWith('http');
          return MeetingModel(
            id: m.id, title: p.notes?.isNotEmpty == true ? p.notes! : 'Meeting',
            date: dateStr, notes: m.notes ?? '',
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
          id: p.id, name: p.name, timeLabel: timeLabel,
          meetingCount: p.memoryIds.length, indicatorColor: colorHex,
          imagePath: p.avatarPath,
          tag: p.tags.isNotEmpty ? p.tags.first : 'Friend',
          strength: strength, lastLocation: lastLocation, meetings: meetings,
        ));
      }

      uiPeople.sort((a, b) =>
          _daysFromLabel(a.timeLabel).compareTo(_daysFromLabel(b.timeLabel)));

      if (mounted) {
        setState(() {
          _people      = uiPeople;
          _allMemories = localMemories;
          _loading     = false;
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
    if (days < 30) { final w = (days / 7).floor(); return '$w ${w == 1 ? "week" : "weeks"} ago'; }
    final mo = (days / 30).floor();
    return '$mo ${mo == 1 ? "month" : "months"} ago';
  }

  String _strengthColor(String s) {
    switch (s) {
      case 'Close':   return '10B981';
      case 'Regular': return '4F46E5';
      case 'Recent':  return 'F59E0B';
      default:        return '8B5CF6';
    }
  }

  int _daysFromLabel(String label) {
    final l = label.toLowerCase();
    if (l == 'today')    return 0;
    if (l == 'yesterday') return 1;
    if (l.contains('days ago'))  return int.tryParse(l.split(' ').first) ?? 99;
    if (l.contains('week'))      return (int.tryParse(l.split(' ').first) ?? 1) * 7;
    if (l.contains('month'))     return (int.tryParse(l.split(' ').first) ?? 1) * 30;
    return 999;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
        .then((_) => _loadData());
  }

  void _openPersonDetail(PersonModel person) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => PersonDetailScreen(person: person),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 320),
    ));
  }

  void _goToCamera() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CameraHomeScreen()),
      (route) => false,
    );
  }

  void _openPhotoViewer(Memory memory) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PhotoViewerScreen(memory: memory, onAddDetails: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddDetailsScreen(imagePath: memory.imagePath)));
      }),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo + title + settings
            HeaderWidget(onSettingsTap: _openSettings),

            // Search bar on Photos + People tabs
            if (_selectedTab != 2)
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
                tabs: const ['Photos', 'People', 'Memories'],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCamera,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    switch (_selectedTab) {
      case 0: return _buildPhotosGrid();
      case 1: return _buildPeopleGrid();
      case 2: return _buildMemoriesTab();
      default: return _buildPhotosGrid();
    }
  }

  // ── Tab 0: Photos — Google Photos style date-grouped grid ─────────────────

  Widget _buildPhotosGrid() {
    // Filter by search
    final memories = _searchQuery.isEmpty
        ? _allMemories
        : _allMemories.where((m) {
            final q = _searchQuery.toLowerCase();
            return (m.location ?? '').toLowerCase().contains(q) ||
                (m.notes ?? '').toLowerCase().contains(q) ||
                m.people.any((p) => p.name.toLowerCase().contains(q));
          }).toList();

    if (memories.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: _searchQuery.isEmpty ? 'No photos yet' : 'No photos found',
        subtitle: _searchQuery.isEmpty
            ? 'Take your first photo to see it here'
            : 'Try a different search term',
        action: _searchQuery.isEmpty
            ? _EmptyAction(label: 'Open Camera', onTap: _goToCamera)
            : null,
      );
    }

    // Group by date
    final groups = <String, List<Memory>>{};
    for (final m in memories) {
      final key = _photoGroupLabel(m.dateTime);
      groups.putIfAbsent(key, () => []).add(m);
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final key   = groups.keys.elementAt(i);
          final items = groups[key]!;
          return _PhotoGroup(
            label: key,
            memories: items,
            onTap: _openPhotoViewer,
          );
        },
      ),
    );
  }

  String _photoGroupLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(dt.year, dt.month, dt.day);
    final diff  = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return DateFormat('EEEE').format(dt); // Monday, Tuesday...
    if (dt.year == now.year) return DateFormat('MMMM d').format(dt);
    return DateFormat('MMMM d, y').format(dt);
  }

  // ── Tab 1: People ──────────────────────────────────────────────────────────

  Widget _buildPeopleGrid() {
    final people = _searchQuery.isEmpty
        ? _people
        : _people.where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.tag.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
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

  // ── Tab 2: Memories ────────────────────────────────────────────────────────

  Widget _buildMemoriesTab() {
    final reminders = _buildReminders();
    if (reminders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'No reminders yet',
        subtitle: 'Smart reminders appear once you have memories\nwith people you have not seen in a while',
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
        msg = 'You have not seen ${p.name} in $days days. Say hi!';
      } else if (days < 30) {
        final w = (days / 7).floor();
        msg = 'It has been $w ${w == 1 ? "week" : "weeks"} since you met ${p.name}.';
      } else {
        final mo = (days / 30).floor();
        msg = '${p.name} - $mo ${mo == 1 ? "month" : "months"} since you last met!';
      }
      reminders.add(_Reminder(
        name: p.name, message: msg, avatarPath: p.imagePath,
        color: _hexColor(p.indicatorColor), daysAgo: days,
      ));
    }
    reminders.sort((a, b) => b.daysAgo.compareTo(a.daysAgo));
    return reminders.take(10).toList();
  }

  Color _hexColor(String hex) {
    try { return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return AppTheme.primary; }
  }

  Widget _buildEmptyState({
    required IconData icon, required String title, required String subtitle,
    _EmptyAction? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(icon, size: 36, color: AppTheme.primary)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: action.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.primaryGlow),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(action.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Photo group (Google Photos style) ───────────────────────────────────────

class _PhotoGroup extends StatelessWidget {
  final String label;
  final List<Memory> memories;
  final void Function(Memory) onTap;

  const _PhotoGroup({required this.label, required this.memories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: memories.length,
          itemBuilder: (_, i) => _PhotoCell(memory: memories[i], onTap: () => onTap(memories[i])),
        ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;
  const _PhotoCell({required this.memory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    final path = memory.imagePath;
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
      color: AppTheme.bg3,
      child: const Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 28));
}

// ─── Photo viewer screen ──────────────────────────────────────────────────────

class _PhotoViewerScreen extends StatelessWidget {
  final Memory memory;
  final VoidCallback onAddDetails;

  const _PhotoViewerScreen({required this.memory, required this.onAddDetails});

  @override
  Widget build(BuildContext context) {
    final path = memory.imagePath;
    final hasDetails = memory.people.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen image with pinch zoom
          InteractiveViewer(
            child: Center(
              child: path.startsWith('http')
                  ? Image.network(path, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 64))
                  : (path.isNotEmpty && File(path).existsSync()
                      ? Image.file(File(path), fit: BoxFit.contain)
                      : const Icon(Icons.broken_image, color: Colors.white38, size: 64)),
            ),
          ),

          // Top bar
          Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(width: 40, height: 40,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.5)),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22))),
                    const Spacer(),
                    if (memory.dateTime != null)
                      Text(DateFormat('MMM d, y  h:mm a').format(memory.dateTime),
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            )),

          // Bottom bar
          Positioned(bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Person names if any
                    if (memory.people.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          memory.people.map((p) => p.name).join(', '),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (memory.location != null && memory.location!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          Text(memory.location!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                        ]),
                      ),
                    // Add details button if no details yet
                    if (!hasDetails)
                      GestureDetector(
                        onTap: onAddDetails,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.primaryGlow,
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Add Details', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _EmptyAction {
  final String label;
  final VoidCallback onTap;
  const _EmptyAction({required this.label, required this.onTap});
}

class _Reminder {
  final String name, message;
  final String? avatarPath;
  final Color color;
  final int daysAgo;
  const _Reminder({required this.name, required this.message, this.avatarPath, required this.color, required this.daysAgo});
}

class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 50), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
}

class _ReminderCard extends StatelessWidget {
  final _Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(radius: 16),
      child: Row(children: [
        _avatar(),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reminder.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 3),
          Text(reminder.message, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: reminder.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('${reminder.daysAgo}d',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: reminder.color))),
      ]),
    );
  }

  Widget _avatar() {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: reminder.color.withOpacity(0.3), width: 2)),
      child: ClipOval(
        child: reminder.avatarPath != null && reminder.avatarPath!.isNotEmpty &&
                !reminder.avatarPath!.startsWith('http')
            ? Image.file(File(reminder.avatarPath!), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
      color: reminder.color.withOpacity(0.1),
      child: Center(child: Text(
          reminder.name.isNotEmpty ? reminder.name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: reminder.color))));
}
