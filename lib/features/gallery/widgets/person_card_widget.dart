import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/person_model.dart';

class PersonCardWidget extends StatefulWidget {
  final PersonModel person;
  final VoidCallback onTap;
  final int animationIndex;

  const PersonCardWidget({
    Key? key,
    required this.person,
    required this.onTap,
    this.animationIndex = 0,
  }) : super(key: key);

  @override
  State<PersonCardWidget> createState() => _PersonCardWidgetState();
}

class _PersonCardWidgetState extends State<PersonCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    final hex = widget.person.indicatorColor.replaceAll('#', '');
    try { return Color(int.parse('FF$hex', radix: 16)); }
    catch (_) { return AppTheme.primary; }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.subtleShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo — 65%
              Expanded(
                flex: 65,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(),
                    // Subtle gradient at bottom of image
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.25), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Tag chip on image
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(widget.person.tag,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              // Info — 35%
              Expanded(
                flex: 35,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.person.name,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary, letterSpacing: -0.2, height: 1.2,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      Row(children: [
                        const Icon(Icons.access_time_rounded, size: 10, color: AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(widget.person.timeLabel,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      // Meeting count
                      Text('${widget.person.meetingCount} ${widget.person.meetingCount == 1 ? "meeting" : "meetings"}',
                          style: TextStyle(fontSize: 11, color: _accentColor, fontWeight: FontWeight.w500)),
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

  Widget _buildImage() {
    if (widget.person.imagePath != null && widget.person.imagePath!.isNotEmpty) {
      final file = File(widget.person.imagePath!);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    if (widget.person.avatarUrl != null && widget.person.avatarUrl!.isNotEmpty) {
      return Image.network(widget.person.avatarUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
          loadingBuilder: (_, child, p) => p == null ? child : _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: _accentColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.person.name.isNotEmpty ? widget.person.name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700,
              color: _accentColor.withOpacity(0.5)),
        ),
      ),
    );
  }
}
