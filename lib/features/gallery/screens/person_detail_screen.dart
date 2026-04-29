import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/person_model.dart';
import '../models/meeting_model.dart';

class PersonDetailScreen extends StatelessWidget {
  final PersonModel person;
  const PersonDetailScreen({Key? key, required this.person}) : super(key: key);

  Color get _accent {
    try { return Color(int.parse('FF${person.indicatorColor.replaceAll("#","")}', radix: 16)); }
    catch (_) { return AppTheme.primary; }
  }

  @override
  Widget build(BuildContext context) {
    // Collect all images from meetings
    final allImages = person.meetings
        .map((m) => m.imagePath ?? m.imageUrl)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: CustomScrollView(
        slivers: [
          _header(context),
          SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _statsCard(),
              if (allImages.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('Photos', allImages.length),
                const SizedBox(height: 12),
                _photosGrid(context, allImages),
              ],
              const SizedBox(height: 24),
              _sectionTitle('Recent Meetings', person.meetings.length),
              const SizedBox(height: 12),
              if (person.meetings.isEmpty)
                _noMeetings()
              else
                ...person.meetings.map((m) => _MeetingTile(meeting: m)),
              const SizedBox(height: 48),
            ],
          )),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300, pinned: true,
      backgroundColor: _accent, automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
          Container(decoration: BoxDecoration(gradient: LinearGradient(
            colors: [_accent, _accent.withOpacity(0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
          Positioned(top: -40, right: -40, child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
          Positioned(bottom: 20, left: -30, child: Container(width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
          SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 40),
            _avatar(),
            const SizedBox(height: 16),
            Text(person.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _chip(person.tag, Colors.white.withOpacity(0.2)),
              const SizedBox(width: 8),
              _chip(person.strength, Colors.white.withOpacity(0.2)),
            ]),
          ])),
        ]),
      ),
      leading: Padding(padding: const EdgeInsets.all(8),
          child: _BackBtn(onTap: () => Navigator.of(context).pop())),
    );
  }

  Widget _avatar() {
    Widget img;
    if (person.imagePath != null && person.imagePath!.isNotEmpty) {
      final f = File(person.imagePath!);
      img = f.existsSync() ? Image.file(f, fit: BoxFit.cover) : _avatarFallback();
    } else if (person.avatarUrl != null && person.avatarUrl!.isNotEmpty) {
      img = Image.network(person.avatarUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback());
    } else {
      img = _avatarFallback();
    }
    return Container(width: 96, height: 96,
        decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))]),
        child: ClipOval(child: img));
  }

  Widget _avatarFallback() => Container(
      color: Colors.white.withOpacity(0.2),
      child: Center(child: Text(
          person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white))));

  Widget _chip(String label, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3))),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)));

  Widget _statsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: AppTheme.glassCard(radius: 20),
        child: Row(children: [
          _stat(Icons.people_outline_rounded, '${person.meetingCount}', 'Meetings', AppTheme.primary),
          _divider(),
          _stat(Icons.access_time_rounded, person.timeLabel, 'Last seen', const Color(0xFF10B981)),
          _divider(),
          _stat(Icons.location_on_outlined, person.lastLocation.split(',').first.trim(), 'Location', const Color(0xFFF59E0B)),
        ]),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) => Expanded(
      child: Column(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ]));

  Widget _divider() => Container(width: 1, height: 48, color: AppTheme.border);

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary))),
      ]),
    );
  }

  Widget _photosGrid(BuildContext context, List<String> images) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: images.length,
        itemBuilder: (_, i) {
          final path = images[i];
          return GestureDetector(
            onTap: () => _viewPhoto(context, path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: path.startsWith('http')
                  ? Image.network(path, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppTheme.bg1,
                          child: const Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 24)))
                  : Image.file(File(path), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppTheme.bg1,
                          child: const Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 24))),
            ),
          );
        },
      ),
    );
  }

  void _viewPhoto(BuildContext context, String path) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PhotoViewer(imagePath: path)));
  }

  Widget _noMeetings() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassCard(radius: 16),
        child: const Center(child: Column(children: [
          Icon(Icons.event_note_outlined, size: 32, color: AppTheme.textMuted),
          SizedBox(height: 8),
          Text('No meetings recorded yet', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
        ])),
      ));
}

class _MeetingTile extends StatelessWidget {
  final MeetingModel meeting;
  const _MeetingTile({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCard(radius: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _thumb(),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meeting.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(meeting.date, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ]),
          if (meeting.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meeting.notes, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ])),
      ]),
    );
  }

  Widget _thumb() {
    Widget img;
    if (meeting.imagePath != null && meeting.imagePath!.isNotEmpty) {
      final f = File(meeting.imagePath!);
      img = f.existsSync() ? Image.file(f, fit: BoxFit.cover) : _ph();
    } else if (meeting.imageUrl != null && meeting.imageUrl!.isNotEmpty) {
      img = Image.network(meeting.imageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ph(),
          loadingBuilder: (_, child, p) => p == null ? child : _ph());
    } else {
      img = _ph();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 64, height: 64, child: img));
  }

  Widget _ph() => Container(color: AppTheme.primary.withOpacity(0.08),
      child: const Icon(Icons.image_outlined, color: AppTheme.primary, size: 24));
}

class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale,
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.textPrimary))),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final String imagePath;
  const _PhotoViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            child: Center(
              child: imagePath.startsWith('http')
                  ? Image.network(imagePath, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 64))
                  : Image.file(File(imagePath), fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 64)),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5)),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22))),
              ),
            ))),
        ],
      ),
    );
  }
}
