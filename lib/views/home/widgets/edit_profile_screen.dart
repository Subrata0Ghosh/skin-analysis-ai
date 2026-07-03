import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../models/user_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onSaved;

  const EditProfileScreen({super.key, required this.profile, required this.onSaved});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late int _age;
  late String _gender;
  late String _skinType;
  late String _knownSensitivities;
  late List<String> _primaryConcerns;
  late List<String> _goals;

  final TextEditingController _backendUrlController = TextEditingController();
  final TextEditingController _geminiApiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = widget.profile.name;
    _age = widget.profile.age;
    _gender = widget.profile.gender;
    _skinType = widget.profile.skinType;
    _knownSensitivities = widget.profile.knownSensitivities;
    _primaryConcerns = List<String>.from(widget.profile.primaryConcerns);
    _goals = List<String>.from(widget.profile.goals);
    _loadBackendPrefs();
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadBackendPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrlController.text = prefs.getString('backend_url') ?? "http://10.0.2.2:8000";
      _geminiApiKeyController.text = prefs.getString('gemini_api_key') ?? "";
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final storageService = Provider.of<StorageService>(context, listen: false);

      final updatedProfile = UserProfile(
        uid: authService.currentUid!,
        name: _name.trim(),
        age: _age,
        gender: _gender,
        skinType: _skinType,
        primaryConcerns: _primaryConcerns,
        goals: _goals,
        knownSensitivities: _knownSensitivities.trim(),
        notifications: widget.profile.notifications, // preserve notifications
      );

      // Save user profile settings
      await storageService.saveUserProfile(updatedProfile);

      // Save backend and key preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backend_url', _backendUrlController.text.trim());
      await prefs.setString('gemini_api_key', _geminiApiKeyController.text.trim());

      widget.onSaved();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile details saved successfully")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Edit Profile Info", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primaryGold),
            onPressed: _save,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Name field
            Text("Full Name", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                hintText: "Your name",
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? "Name cannot be empty" : null,
              onSaved: (val) => _name = val ?? "",
            ),
            const SizedBox(height: 24),

            // Age Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Age Profile", style: Theme.of(context).textTheme.titleMedium),
                Text("$_age years", style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _age.toDouble(),
              min: 12,
              max: 90,
              divisions: 78,
              activeColor: AppColors.primaryGold,
              inactiveColor: AppColors.border,
              onChanged: (val) => setState(() => _age = val.toInt()),
            ),
            const SizedBox(height: 24),

            // Gender Identity row
            Text("Gender Identity", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              dropdownColor: AppColors.cardBg,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.wc_outlined, size: 20),
              ),
              items: ["Female", "Male", "Other"].map((g) {
                return DropdownMenuItem(value: g, child: Text(g));
              }).toList(),
              onChanged: (val) => setState(() => _gender = val ?? "Other"),
            ),
            const SizedBox(height: 24),

            // Skin Type Selection
            Text("Skin Type", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _skinType,
              dropdownColor: AppColors.cardBg,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.spa_outlined, size: 20),
              ),
              items: ["Oily", "Dry", "Combination", "Normal", "Sensitive"].map((st) {
                return DropdownMenuItem(value: st, child: Text(st));
              }).toList(),
              onChanged: (val) => setState(() => _skinType = val ?? "Normal"),
            ),
            const SizedBox(height: 24),

            // Sensitivities
            Text("Known Sensitivities / Allergies", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _knownSensitivities,
              decoration: const InputDecoration(
                hintText: "e.g. Salicylic Acid, Retinol (optional)",
                prefixIcon: Icon(Icons.warning_amber_rounded, size: 20),
              ),
              onSaved: (val) => _knownSensitivities = val ?? "",
            ),
            const SizedBox(height: 32),

            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              "DEVELOPER BACKEND SETTINGS",
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
            ),
            const SizedBox(height: 16),

            // Backend URL
            Text("FastAPI Server URL", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                hintText: "http://192.168.1.XX:8000",
                prefixIcon: Icon(Icons.dns_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 24),

            // Gemini API Key
            Text("Gemini API Key (Free Tier)", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _geminiApiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "AIzaSy...",
                prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _save,
              child: const Text("Save Preferences"),
            ),
          ],
        ),
      ),
    );
  }
}
