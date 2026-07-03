import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../models/user_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onSaved;

  const NotificationSettingsScreen({super.key, required this.profile, required this.onSaved});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late bool _scan;
  late bool _routine;
  late bool _progress;

  @override
  void initState() {
    super.initState();
    _scan = widget.profile.notifications['scan'] ?? true;
    _routine = widget.profile.notifications['routine'] ?? true;
    _progress = widget.profile.notifications['progress'] ?? true;
  }

  Future<void> _save() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    final updatedProfile = UserProfile(
      uid: authService.currentUid!,
      name: widget.profile.name,
      age: widget.profile.age,
      gender: widget.profile.gender,
      skinType: widget.profile.skinType,
      primaryConcerns: widget.profile.primaryConcerns,
      goals: widget.profile.goals,
      knownSensitivities: widget.profile.knownSensitivities,
      notifications: {
        'scan': _scan,
        'routine': _routine,
        'progress': _progress,
      },
    );

    await storageService.saveUserProfile(updatedProfile);
    widget.onSaved();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Notification settings updated")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primaryGold),
            onPressed: _save,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            "ALERTS & REMINDERS",
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
          ),
          const SizedBox(height: 16),

          // Scan Switch
          _buildToggleItem(
            title: "Skin Scan Reminders",
            subtitle: "Get notified when it's time to capture your weekly diagnostic skin scan to keep profiles fresh.",
            value: _scan,
            onChanged: (val) => setState(() => _scan = val),
            icon: Icons.camera_alt_outlined,
          ),
          const Divider(color: AppColors.border, height: 24),

          // Routine Switch
          _buildToggleItem(
            title: "Skincare Habit Alerts",
            subtitle: "Reminders to complete your morning and evening skincare routines or facial exercises.",
            value: _routine,
            onChanged: (val) => setState(() => _routine = val),
            icon: Icons.alarm_rounded,
          ),
          const Divider(color: AppColors.border, height: 24),

          // Progress Switch
          _buildToggleItem(
            title: "Progress Insights",
            subtitle: "Weekly summaries highlighting improvements in your acne, redness, or symmetry scores.",
            value: _progress,
            onChanged: (val) => setState(() => _progress = val),
            icon: Icons.analytics_outlined,
          ),
          
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _save,
            child: const Text("Save Alert Preferences"),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile.adaptive(
      activeThumbColor: AppColors.primaryGold,
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.primaryGold, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
