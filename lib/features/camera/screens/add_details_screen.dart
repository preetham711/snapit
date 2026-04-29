import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/location_service.dart';
import '../../gallery/screens/gallery_screen.dart';

class AddDetailsScreen extends StatefulWidget {
  final String imagePath;
  const AddDetailsScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<AddDetailsScreen> createState() => _AddDetailsScreenState();
}

class _AddDetailsScreenState extends State<AddDetailsScreen> with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _instaCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late DateTime _now;
  String _locationText = 'Fetching...';
  bool _locationFetched = false;
  bool _showMore = false;
  bool _isSaving = false;

  late AnimationController _c1, _c2, _moreCtrl;
  late Animation<double> _f1, _f2;
  late Animation<Offset> _s1, _s2;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _moreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _f1 = CurvedAnimation(parent: _c1, curve: Curves.easeOut);
    _f2 = CurvedAnimation(parent: _c2, curve: Curves.easeOut);
    _s1 = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c1, curve: Curves.easeOut));
    _s2 = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c2, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 80), () { if (mounted) _c1.forward(); });
    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _c2.forward(); });
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      final name = await LocationService.getLocationName(pos.latitude, pos.longitude);
      setState(() {
        _locationText = name ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        _locationFetched = true;
      });
    } else if (mounted) {
      setState(() { _locationText = 'Location unavailable'; _locationFetched = true; });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _notesCtrl.dispose(); _emailCtrl.dispose();
    _instaCtrl.dispose(); _phoneCtrl.dispose();
    _c1.dispose(); _c2.dispose(); _moreCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      const uuid = Uuid();
      final pid = uuid.v4();
      final mid = uuid.v4();
      final person = Person(
        id: pid, name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        tags: const [], memoryIds: [mid],
        firstMet: _now, lastSeen: _now, avatarPath: widget.imagePath,
      );
      final memory = Memory(
        id: mid, imagePath: widget.imagePath, dateTime: _now,
        location: _locationFetched ? _locationText : null,
        people: [person],
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await StorageService.savePerson(person);
      await StorageService.saveMemory(memory);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GalleryScreen()), (r) => false);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _topBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _imagePreview(),
                      const SizedBox(height: 20),
                      FadeTransition(opacity: _f1, child: SlideTransition(position: _s1, child: _card1())),
                      const SizedBox(height: 14),
                      FadeTransition(opacity: _f2, child: SlideTransition(position: _s2, child: _card2())),
                      const SizedBox(height: 14),
                      _moreBtn(),
                      if (_showMore) ...[
                        const SizedBox(height: 14),
                        SizeTransition(
                          sizeFactor: CurvedAnimation(parent: _moreCtrl, curve: Curves.easeOut),
                          child: _card3()),
                      ],
                      const SizedBox(height: 24),
                      _saveBtn(),
                      const SizedBox(height: 12),
                      Center(child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 14, color: AppTheme.textMuted,
                                decoration: TextDecoration.underline)))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppTheme.textPrimary,
          ),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Fill details or go back for more photos', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ),
          _SavePill(onTap: _isSaving ? null : _save, isSaving: _isSaving),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(File(widget.imagePath), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppTheme.bg1,
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted)))),
      ),
    );
  }

  Widget _card1() {
    return _Card(
      icon: Icons.person_outline_rounded, title: 'Person Details', color: AppTheme.primary,
      children: [
        TextFormField(
          controller: _nameCtrl, autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Full name *',
              prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppTheme.textMuted)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesCtrl, maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Notes (optional)',
              prefixIcon: Padding(padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_rounded, size: 18, color: AppTheme.textMuted)),
              alignLabelWithHint: true),
        ),
      ],
    );
  }

  Widget _card2() {
    final dateStr = DateFormat('EEE, MMM d, y').format(_now);
    final timeStr = DateFormat('h:mm a').format(_now);
    return _Card(
      icon: Icons.schedule_rounded, title: 'When & Where', color: const Color(0xFF10B981),
      children: [
        _ReadRow(icon: Icons.calendar_today_outlined, iconColor: AppTheme.primary,
            label: '$dateStr  -  $timeStr'),
        const SizedBox(height: 10),
        _ReadRow(icon: Icons.location_on_outlined, iconColor: const Color(0xFF10B981),
            label: _locationText, isLoading: _locationText == 'Fetching...'),
      ],
    );
  }

  Widget _card3() {
    return _Card(
      icon: Icons.contact_page_outlined, title: 'Contact Info', color: const Color(0xFF8B5CF6),
      children: [
        TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppTheme.textMuted))),
        const SizedBox(height: 12),
        TextFormField(controller: _instaCtrl,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Instagram handle',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: AppTheme.textMuted))),
        const SizedBox(height: 12),
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined, size: 18, color: AppTheme.textMuted))),
      ],
    );
  }

  Widget _moreBtn() {
    return GestureDetector(
      onTap: () {
        setState(() => _showMore = !_showMore);
        _showMore ? _moreCtrl.forward() : _moreCtrl.reverse();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_showMore ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(_showMore ? 'Hide extra details' : '+ Add more details',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ]),
      ),
    );
  }

  Widget _saveBtn() {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: _isSaving ? null : AppTheme.primaryGradient,
          color: _isSaving ? AppTheme.bg3 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSaving ? null : AppTheme.primaryGlow,
        ),
        child: Center(child: _isSaving
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.save_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Save Memory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ])),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;
  const _Card({required this.icon, required this.title, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLoading;
  const _ReadRow({required this.icon, required this.iconColor, required this.label, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.bg1, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        if (isLoading) ...[
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: iconColor)),
          const SizedBox(width: 8),
          const Text('Fetching...', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
        ] else
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _SavePill extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isSaving;
  const _SavePill({this.onTap, required this.isSaving});

  @override
  State<_SavePill> createState() => _SavePillState();
}

class _SavePillState extends State<_SavePill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _ctrl.forward() : null,
      onTapUp: widget.onTap != null ? (_) { _ctrl.reverse(); widget.onTap!(); } : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.primaryGlow),
          child: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}
