import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/models/memory_model.dart';

/// TimelineScreen — offline-first with optional Firestore live updates.
///
/// Strategy:
///   1. Load from local Hive immediately (no spinner for offline users).
///   2. Subscribe to Firestore stream in background.
///   3. If Firestore delivers data, merge/replace local list.
///   4. If Firestore errors (offline), keep showing local data silently.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Memory> _memories = [];
  bool _loadingLocal = true;
  bool _cloudConnected = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _subscribeToCloud();
  }

  // ── Step 1: Load from Hive immediately ────────────────────────────────────

  Future<void> _loadLocal() async {
    final local = await StorageService.getAllMemories();
    if (mounted) {
      setState(() {
        _memories     = local;
        _loadingLocal = false;
      });
    }
  }

  // ── Step 2: Subscribe to Firestore stream ─────────────────────────────────

  void _subscribeToCloud() {
    CloudSyncService.instance.memoriesStream().listen(
      (cloudMemories) {
        if (!mounted) return;
        if (cloudMemories.isNotEmpty) {
          setState(() {
            _memories        = cloudMemories;
            _cloudConnected  = true;
          });
        }
      },
      onError: (e) {
        // Firestore unavailable — silently keep local data
        debugPrint('[Timeline] Firestore stream error (offline?): $e');
      },
    );
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  String _groupLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(dt.year, dt.month, dt.day);
    final diff  = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return '$diff days ago';
    return DateFormat('MMMM d, y').format(dt);
  }

  Map<String, List<Memory>> _groupMemories() {
    final groups = <String, List<Memory>>{};
    for (final m in _memories) {
      final label = _groupLabel(m.dateTime);
      groups.putIfAbsent(label, () => []).add(m);
    }
    return groups;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingLocal) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_memories.isEmpty) {
      return _buildEmptyState();
    }

    final groups    = _groupMemories();
    final groupKeys = groups.keys.toList();

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: groupKeys.length,
          itemBuilder: (context, groupIndex) {
            final label = groupKeys[groupIndex];
            final items = groups[label]!;
            return _TimelineGroup(
              label: label,
              memories: items,
              groupIndex: groupIndex,
            );
          },
        ),

        // Small cloud indicator in top-right when Firestore is live
        if (_cloudConnected)
          Positioned(
            top: 8,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_rounded,
                      size: 12, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text('Live',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            child: const Icon(Icons.timeline_rounded,
                size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          const Text('No memories yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Capture your first memory\nto see it here',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppTheme.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline group ───────────────────────────────────────────────────────────

class _TimelineGroup extends StatefulWidget {
  final String label;
  final List<Memory> memories;
  final int groupIndex;

  const _TimelineGroup({
    required this.label,
    required this.memories,
    required this.groupIndex,
  });

  @override
  State<_TimelineGroup> createState() => _TimelineGroupState();
}

class _TimelineGroupState extends State<_TimelineGroup>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 380 + widget.groupIndex * 60),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.groupIndex * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildGroupHeader(),
            const SizedBox(height: 8),
            ...widget.memories.map((m) => _MemoryCard(memory: m)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(widget.label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 0.2)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppTheme.border)),
      ],
    );
  }
}

// ─── Memory card ──────────────────────────────────────────────────────────────

class _MemoryCard extends StatelessWidget {
  final Memory memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCard(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(),
          const SizedBox(width: 12),
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    Widget image;
    final path = memory.imagePath;

    if (path.startsWith('http')) {
      // Cloud URL — show from network
      image = Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(),
      );
    } else if (path.isNotEmpty && File(path).existsSync()) {
      // Local file
      image = Image.file(File(path), fit: BoxFit.cover);
    } else {
      image = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 88, height: 88, child: image),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.primary.withOpacity(0.08),
        child: const Icon(Icons.image_outlined,
            color: AppTheme.primary, size: 28),
      );

  Widget _buildInfo() {
    final names   = memory.people.map((p) => p.name).join(', ');
    final timeStr = DateFormat('h:mm a').format(memory.dateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          names.isNotEmpty ? names : 'Memory',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (memory.location != null && memory.location!.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  memory.location!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (memory.notes != null && memory.notes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            memory.notes!,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 11, color: AppTheme.textMuted),
            const SizedBox(width: 3),
            Text(timeStr,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }
}
