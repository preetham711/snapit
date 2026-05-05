import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/models/memory_model.dart';
import '../models/person_model.dart';
import '../models/meeting_model.dart';
import '../widgets/person_card_widget.dart';
import 'person_detail_screen.dart';
import 'settings_screen.dart';
import '../../camera/screens/camera_home_screen.dart';
import '../../camera/screens/add_details_screen.dart';

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
  final _searchCtrl = TextEditingController();

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
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }

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
      case 'Close':   return '34C759';
      case 'Regular': return '4F46E5';
      case 'Recent':  return 'FF9500';
      default:        return '8E8E93';
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

  void _openSettings() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const SettingsScreen()))
        .then((_) => _loadData());
  }

  void _openPersonDetail(PersonModel person) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => PersonDetailScreen(person: person),
    ));
  }

  void _goToCamera() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CameraHomeScreen()),
      (route) => false,
    );
  }

  void _openPhotoViewer(Memory memory) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => _PhotoViewerScreen(memory: memory, onAddDetails: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => AddDetailsScreen(imagePath: memory.imagePath)));
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: Column(
        children: [
          // iOS Large Title Navigation Bar
          _buildNavBar(),
          // iOS Segmented Control
          _buildSegmentedControl(),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
      // iOS-style camera FAB
      floatingActionButton: _buildCameraFAB(),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large title — iOS style
                  Text(
                    _tabTitle,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // Settings button — iOS style
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openSettings,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.bg2,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.subtleShadow,
                ),
                child: const Icon(CupertinoIcons.ellipsis_circle,
                    color: AppTheme.primary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _tabTitle {
    switch (_selectedTab) {
      case 0: return 'Photos';
      case 1: return 'People';
      case 2: return 'Memories';
      default: return 'Gallery';
    }
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _selectedTab,
        backgroundColor: AppTheme.bg3,
        thumbColor: AppTheme.bg2,
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('People', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          2: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Memories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        },
        onValueChanged: (v) {
          if (v != null) setState(() { _selectedTab = v; _searchQuery = ''; _searchCtrl.clear(); });
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    switch (_selectedTab) {
      case 0: return _buildPhotosTab();
      case 1: return _buildPeopleTab();
      case 2: return _buildMemoriesTab();
      default: return _buildPhotosTab();
    }
  }

  // ── Photos tab ────────────────────────────────────────────────────────────

  Widget _buildPhotosTab() {
    final memories = _searchQuery.isEmpty
        ? _allMemories
        : _allMemories.where((m) {
            final q = _searchQuery.toLowerCase();
            return (m.location ?? '').toLowerCase().contains(q) ||
                (m.notes ?? '').toLowerCase().contains(q) ||
                m.people.any((p) => p.name.toLowerCase().contains(q));
          }).toList();

    return Column(
      children: [
        _buildSearchBar('Search photos...'),
        Expanded(
          child: memories.isEmpty
              ? _buildEmptyState(
                  icon: CupertinoIcons.photo_on_rectangle,
                  title: _searchQuery.isEmpty ? 'No Photos Yet' : 'No Results',
                  subtitle: _searchQuery.isEmpty
                      ? 'Take your first photo to see it here'
                      : 'Try a different search term',
                  actionLabel: _searchQuery.isEmpty ? 'Open Camera' : null,
                  onAction: _searchQuery.isEmpty ? _goToCamera : null,
                )
              : _buildPhotosGrid(memories),
        ),
      ],
    );
  }

  Widget _buildPhotosGrid(List<Memory> memories) {
    final groups = <String, List<Memory>>{};
    for (final m in memories) {
      final key = _photoGroupLabel(m.dateTime);
      groups.putIfAbsent(key, () => []).add(m);
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final entry in groups.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(entry.key,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary, letterSpacing: -0.2)),
              ),
            ),
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => GestureDetector(
                  onTap: () => _openPhotoViewer(entry.value[i]),
                  child: _PhotoCell(memory: entry.value[i]),
                ),
                childCount: entry.value.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
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
    if (diff < 7)  return DateFormat('EEEE').format(dt);
    if (dt.year == now.year) return DateFormat('MMMM d').format(dt);
    return DateFormat('MMMM d, y').format(dt);
  }

  // ── People tab ────────────────────────────────────────────────────────────

  Widget _buildPeopleTab() {
    final people = _searchQuery.isEmpty
        ? _people
        : _people.where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.tag.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        _buildSearchBar('Search people...'),
        Expanded(
          child: people.isEmpty
              ? _buildEmptyState(
                  icon: CupertinoIcons.person_2,
                  title: _searchQuery.isEmpty ? 'No People Yet' : 'No Results',
                  subtitle: _searchQuery.isEmpty
                      ? 'Capture a photo and add details to see people here'
                      : 'Try a different search term',
                  actionLabel: _searchQuery.isEmpty ? 'Open Camera' : null,
                  onAction: _searchQuery.isEmpty ? _goToCamera : null,
                )
              : RefreshIndicator(
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
                    itemBuilder: (context, index) => PersonCardWidget(
                      person: people[index],
                      animationIndex: index,
                      onTap: () => _openPersonDetail(people[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Memories tab ──────────────────────────────────────────────────────────

  Widget _buildMemoriesTab() {
    final reminders = _buildReminders();
    if (reminders.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.sparkles,
        title: 'No Reminders Yet',
        subtitle: 'Smart reminders appear once you have memories with people you have not seen in a while',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: reminders.length,
        itemBuilder: (_, i) => _ReminderCard(reminder: reminders[i]),
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
        msg = 'You have not seen ${p.name} in $days days.';
      } else if (days < 30) {
        final w = (days / 7).floor();
        msg = '$w ${w == 1 ? "week" : "weeks"} since you met ${p.name}.';
      } else {
        final mo = (days / 30).floor();
        msg = '$mo ${mo == 1 ? "month" : "months"} since you last met!';
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

  // ── Shared components ─────────────────────────────────────────────────────

  Widget _buildSearchBar(String hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: CupertinoSearchTextField(
        controller: _searchCtrl,
        placeholder: hint,
        onChanged: (q) => setState(() => _searchQuery = q),
        backgroundColor: AppTheme.bg2,
        style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
        placeholderStyle: const TextStyle(fontSize: 16, color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppTheme.textMuted, height: 1.4)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: onAction,
                borderRadius: BorderRadius.circular(14),
                child: Text(actionLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraFAB() {
    return GestureDetector(
      onTap: _goToCamera,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: AppTheme.primaryGlow,
        ),
        child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── Photo cell ───────────────────────────────────────────────────────────────

class _PhotoCell extends StatelessWidget {
  final Memory memory;
  const _PhotoCell({required this.memory});

  @override
  Widget build(BuildContext context) {
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
      child: const Icon(CupertinoIcons.photo, color: AppTheme.textMuted, size: 24));
}

// ─── Photo viewer ─────────────────────────────────────────────────────────────

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
          InteractiveViewer(
            child: Center(
              child: path.startsWith('http')
                  ? Image.network(path, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.white38, size: 64))
                  : (path.isNotEmpty && File(path).existsSync()
                      ? Image.file(File(path), fit: BoxFit.contain)
                      : const Icon(CupertinoIcons.photo, color: Colors.white38, size: 64)),
            ),
          ),
          // Top bar
          Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5)),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 16)),
                ),
                const Spacer(),
                if (memory.dateTime != null)
                  Text(DateFormat('MMM d, y').format(memory.dateTime),
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ))),
          // Bottom bar
          Positioned(bottom: 0, left: 0, right: 0,
            child: SafeArea(child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.75), Colors.transparent])),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (memory.people.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(memory.people.map((p) => p.name).join(', '),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                  if (memory.location != null && memory.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        const Icon(CupertinoIcons.location_fill, color: Color(0xFF34C759), size: 13),
                        const SizedBox(width: 4),
                        Text(memory.location!, style: const TextStyle(color: Color(0xFF34C759), fontSize: 13)),
                      ])),
                  if (!hasDetails)
                    CupertinoButton.filled(
                      onPressed: onAddDetails,
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(CupertinoIcons.person_badge_plus, size: 18),
                        SizedBox(width: 8),
                        Text('Add Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ],
              ),
            ))),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Reminder {
  final String name, message;
  final String? avatarPath;
  final Color color;
  final int daysAgo;
  const _Reminder({required this.name, required this.message, this.avatarPath, required this.color, required this.daysAgo});
}

class _ReminderCard extends StatelessWidget {
  final _Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.iosCard(radius: 14),
      child: Row(children: [
        _avatar(),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reminder.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(reminder.message, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.3)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: reminder.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('${reminder.daysAgo}d',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: reminder.color))),
      ]),
    );
  }

  Widget _avatar() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: reminder.color.withOpacity(0.12)),
      child: ClipOval(
        child: reminder.avatarPath != null && reminder.avatarPath!.isNotEmpty &&
                !reminder.avatarPath!.startsWith('http')
            ? Image.file(File(reminder.avatarPath!), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Center(child: Text(
      reminder.name.isNotEmpty ? reminder.name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: reminder.color)));
}
