import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _moreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _f1 = CurvedAnimation(parent: _c1, curve: Curves.easeOut);
    _f2 = CurvedAnimation(parent: _c2, curve: Curves.easeOut);
    _s1 = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c1, curve: Curves.easeOut));
    _s2 = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c2, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 60), () { if (mounted) _c1.forward(); });
    Future.delayed(const Duration(milliseconds: 160), () { if (mounted) _c2.forward(); });
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
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save: $e'),
            actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
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
              _buildNavBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _imagePreview(),
                      const SizedBox(height: 24),
                      FadeTransition(opacity: _f1, child: SlideTransition(position: _s1, child: _personSection())),
                      const SizedBox(height: 16),
                      FadeTransition(opacity: _f2, child: SlideTransition(position: _s2, child: _whenWhereSection())),
                      const SizedBox(height: 16),
                      _moreDetailsToggle(),
                      if (_showMore) ...[
                        const SizedBox(height: 16),
                        SizeTransition(
                          sizeFactor: CurvedAnimation(parent: _moreCtrl, curve: Curves.easeOut),
                          child: _contactSection()),
                      ],
                      const SizedBox(height: 28),
                      _saveButton(),
                      const SizedBox(height: 12),
                      Center(
                        child: CupertinoButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel',
                              style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
                        ),
                      ),
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

  Widget _buildNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(CupertinoIcons.back, color: AppTheme.primary, size: 28),
          ),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary, letterSpacing: -0.3)),
              Text('Fill in details for this memory',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ]),
          ),
          _isSaving
              ? const CupertinoActivityIndicator()
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        width: double.infinity,
        child: Image.file(File(widget.imagePath), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                color: AppTheme.bg3,
                child: const Center(child: Icon(CupertinoIcons.photo, size: 48, color: AppTheme.textMuted)))),
      ),
    );
  }

  // iOS inset grouped section
  Widget _personSection() {
    return _IosSection(
      header: 'PERSON',
      children: [
        _IosTextField(
          controller: _nameCtrl,
          placeholder: 'Full Name',
          icon: CupertinoIcons.person,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const _IosDivider(),
        _IosTextField(
          controller: _notesCtrl,
          placeholder: 'Notes',
          icon: CupertinoIcons.doc_text,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _whenWhereSection() {
    final dateStr = DateFormat('EEE, MMM d, y').format(_now);
    final timeStr = DateFormat('h:mm a').format(_now);
    return _IosSection(
      header: 'WHEN & WHERE',
      children: [
        _IosReadRow(
          icon: CupertinoIcons.calendar,
          label: '$dateStr  ·  $timeStr',
          iconColor: AppTheme.primary,
        ),
        const _IosDivider(),
        _IosReadRow(
          icon: CupertinoIcons.location_fill,
          label: _locationText,
          iconColor: AppTheme.success,
          isLoading: _locationText == 'Fetching...',
        ),
      ],
    );
  }

  Widget _contactSection() {
    return _IosSection(
      header: 'CONTACT INFO',
      children: [
        _IosTextField(
          controller: _emailCtrl,
          placeholder: 'Email',
          icon: CupertinoIcons.mail,
          keyboardType: TextInputType.emailAddress,
        ),
        const _IosDivider(),
        _IosTextField(
          controller: _instaCtrl,
          placeholder: 'Instagram',
          icon: CupertinoIcons.at,
        ),
        const _IosDivider(),
        _IosTextField(
          controller: _phoneCtrl,
          placeholder: 'Phone',
          icon: CupertinoIcons.phone,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _moreDetailsToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _showMore = !_showMore);
        _showMore ? _moreCtrl.forward() : _moreCtrl.reverse();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_showMore ? CupertinoIcons.minus_circle : CupertinoIcons.plus_circle,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(_showMore ? 'Hide Contact Info' : 'Add Contact Info',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.primary)),
        ]),
      ),
    );
  }

  Widget _saveButton() {
    return CupertinoButton.filled(
      onPressed: _isSaving ? null : _save,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _isSaving
          ? const CupertinoActivityIndicator(color: Colors.white)
          : const Text('Save Memory',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── iOS-style section ────────────────────────────────────────────────────────

class _IosSection extends StatelessWidget {
  final String header;
  final List<Widget> children;
  const _IosSection({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(header,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted, letterSpacing: 0.5)),
        ),
        Container(
          decoration: AppTheme.iosCard(radius: 12),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _IosTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _IosTextField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, size: 18, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              autofocus: autofocus,
              maxLines: maxLines,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              validator: validator,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(fontSize: 16, color: AppTheme.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IosReadRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLoading;
  const _IosReadRow({required this.icon, required this.iconColor, required this.label, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        if (isLoading) ...[
          const CupertinoActivityIndicator(radius: 8),
          const SizedBox(width: 8),
          const Text('Fetching...', style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
        ] else
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _IosDivider extends StatelessWidget {
  const _IosDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 44),
      child: Divider(height: 0.5, thickness: 0.5, color: AppTheme.separator),
    );
  }
}
