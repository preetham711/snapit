import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/cloud_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _faceBlur = false;
  bool _appLock = false;
  bool _autoLocation = true;
  bool _quickSaveDefault = false;
  bool _memoryReminders = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final faceBlur =
        await StorageService.getSetting('faceBlur', defaultValue: false);
    final appLock =
        await StorageService.getSetting('appLock', defaultValue: false);
    final autoLocation =
        await StorageService.getSetting('autoLocation', defaultValue: true);
    final quickSave =
        await StorageService.getSetting('quickSaveDefault', defaultValue: false);
    final reminders =
        await StorageService.getSetting('memoryReminders', defaultValue: true);
    if (mounted) {
      setState(() {
        _faceBlur = faceBlur ?? false;
        _appLock = appLock ?? false;
        _autoLocation = autoLocation ?? true;
        _quickSaveDefault = quickSave ?? false;
        _memoryReminders = reminders ?? true;
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await StorageService.saveSetting(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildSection(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Privacy',
                    tiles: [
                      _buildToggleTile(
                        icon: Icons.face_retouching_off_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Face Blur',
                        subtitle: 'Automatically blur faces in photos',
                        value: _faceBlur,
                        onChanged: (v) {
                          setState(() => _faceBlur = v);
                          _saveSetting('faceBlur', v);
                        },
                      ),
                      _buildToggleTile(
                        icon: Icons.fingerprint_rounded,
                        iconColor: const Color(0xFF4F46E5),
                        title: 'App Lock',
                        subtitle: 'Require biometrics to open app',
                        value: _appLock,
                        onChanged: (v) {
                          setState(() => _appLock = v);
                          _saveSetting('appLock', v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.camera_alt_outlined,
                    iconColor: const Color(0xFF10B981),
                    title: 'Capture',
                    tiles: [
                      _buildToggleTile(
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFF10B981),
                        title: 'Auto Location',
                        subtitle: 'Attach GPS location to every capture',
                        value: _autoLocation,
                        onChanged: (v) {
                          setState(() => _autoLocation = v);
                          _saveSetting('autoLocation', v);
                        },
                      ),
                      _buildToggleTile(
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Quick Save Default',
                        subtitle: 'Skip details screen by default',
                        value: _quickSaveDefault,
                        onChanged: (v) {
                          setState(() => _quickSaveDefault = v);
                          _saveSetting('quickSaveDefault', v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.notifications_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Notifications',
                    tiles: [
                      _buildToggleTile(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Memory Reminders',
                        subtitle:
                            'Get reminded about people you haven\'t seen',
                        value: _memoryReminders,
                        onChanged: (v) {
                          setState(() => _memoryReminders = v);
                          _saveSetting('memoryReminders', v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.storage_outlined,
                    iconColor: const Color(0xFF06B6D4),
                    title: 'Data',
                    tiles: [
                      _buildActionTile(
                        icon: Icons.cloud_upload_outlined,
                        iconColor: const Color(0xFF06B6D4),
                        title: 'Backup to Cloud',
                        subtitle: 'Push all local memories to Firestore',
                        onTap: () => _backupToCloud(context),
                      ),
                      _buildActionTile(
                        icon: Icons.cloud_download_outlined,
                        iconColor: const Color(0xFF4F46E5),
                        title: 'Sync from Cloud',
                        subtitle: 'Pull latest data from Firestore',
                        onTap: () => _syncFromCloud(context),
                      ),
                      _buildActionTile(
                        icon: Icons.delete_outline_rounded,
                        iconColor: const Color(0xFFEF4444),
                        title: 'Clear All Data',
                        subtitle: 'Permanently delete all memories',
                        titleColor: const Color(0xFFEF4444),
                        onTap: () => _showClearDataDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.textMuted,
                    title: 'About',
                    tiles: [
                      _buildInfoTile(
                        icon: Icons.apps_rounded,
                        iconColor: AppTheme.primary,
                        title: 'Version',
                        value: '1.0.0',
                      ),
                      _buildInfoTile(
                        icon: Icons.code_rounded,
                        iconColor: AppTheme.textMuted,
                        title: 'Build',
                        value: '2024.1',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppTheme.textPrimary,
          ),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> tiles,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: AppTheme.glassCard(radius: 16),
          child: Column(
            children: List.generate(tiles.length, (i) {
              return Column(
                children: [
                  tiles[i],
                  if (i < tiles.length - 1)
                    const Divider(height: 1, indent: 56, endIndent: 16),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Future<void> _backupToCloud(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Backing up to cloud…'),
        ]),
        duration: Duration(seconds: 60),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await CloudSyncService.instance.syncLocalDataToCloud();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            result.success
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(result.message)),
        ]),
        backgroundColor:
            result.success ? const Color(0xFF10B981) : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _syncFromCloud(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Restoring from cloud…'),
        ]),
        duration: Duration(seconds: 60),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await CloudSyncService.instance.restoreFromCloud();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            result.success ? Icons.sync_rounded : Icons.cloud_off_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(result.message)),
        ]),
        backgroundColor:
            result.success ? const Color(0xFF4F46E5) : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        content: const Text(
          'This will permanently delete all your memories and people. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              await StorageService.clearAll();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
