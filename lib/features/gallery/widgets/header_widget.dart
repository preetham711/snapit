// This widget is no longer used — gallery_screen.dart builds its own iOS nav bar.
// Kept for backward compatibility.
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HeaderWidget extends StatelessWidget {
  final VoidCallback onSettingsTap;
  const HeaderWidget({Key? key, required this.onSettingsTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Gallery',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary, letterSpacing: -0.5)),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_outlined, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
