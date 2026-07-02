import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Question answers
  String _name = '';
  int _age = 25;
  String _gender = 'Female';
  String _skinType = 'Normal';
  final List<String> _selectedConcerns = [];
  final List<String> _selectedGoals = [];
  final TextEditingController _sensitivitiesController = TextEditingController();
  bool _notifScan = true;
  bool _notifRoutine = true;
  bool _notifProgress = true;

  @override
  void initState() {
    super.initState();
    // Prefill name from auth service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      setState(() {
        _name = authService.currentUserName ?? '';
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sensitivitiesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _saveAndComplete();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveAndComplete() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    final profile = UserProfile(
      uid: authService.currentUid!,
      name: _name.trim().isEmpty ? "Aura User" : _name.trim(),
      age: _age,
      gender: _gender,
      skinType: _skinType,
      primaryConcerns: _selectedConcerns,
      goals: _selectedGoals,
      knownSensitivities: _sensitivitiesController.text.trim(),
      notifications: {
        'scan': _notifScan,
        'routine': _notifRoutine,
        'progress': _notifProgress,
      },
    );

    await storageService.saveUserProfile(profile);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                onPressed: _prevStep,
              )
            : null,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: AppColors.border,
            color: AppColors.primaryGold,
            minHeight: 6,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "${_currentStep + 1}/$_totalSteps",
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (step) {
          setState(() {
            _currentStep = step;
          });
        },
        children: [
          _buildStepPersonalInfo(),
          _buildStepSkinType(),
          _buildStepConcernsAndGoals(),
          _buildStepPreferences(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _nextStep,
            child: Text(_currentStep == _totalSteps - 1 ? "Complete Profile" : "Continue"),
          ),
        ),
      ),
    );
  }

  // STEP 1: Personal Info
  Widget _buildStepPersonalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Tell us about yourself", style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            "We personalize your skin analysis metrics based on age and gender parameters.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          
          // Name Field
          Text("What should we call you?", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _name,
            decoration: const InputDecoration(
              hintText: "Enter your name",
              prefixIcon: Icon(Icons.person_outline, size: 20, color: AppColors.textMuted),
            ),
            onChanged: (val) => _name = val,
          ),
          const SizedBox(height: 32),
          
          // Age Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Age", style: Theme.of(context).textTheme.titleMedium),
              Text(
                "$_age years",
                style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _age.toDouble(),
            min: 12,
            max: 90,
            divisions: 78,
            activeColor: AppColors.primaryGold,
            inactiveColor: AppColors.border,
            onChanged: (val) {
              setState(() {
                _age = val.toInt();
              });
            },
          ),
          const SizedBox(height: 32),
          
          // Gender Selection
          Text("Gender Identity", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderChip("Female"),
              const SizedBox(width: 12),
              _buildGenderChip("Male"),
              const SizedBox(width: 12),
              _buildGenderChip("Other"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    final isSelected = _gender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _gender = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGold : AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primaryGold : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.textDark : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // STEP 2: Skin Type selection (premium cards)
  Widget _buildStepSkinType() {
    final List<Map<String, String>> skinTypes = [
      {'name': 'Oily', 'desc': 'Skin has excess shine, dilated pores, and is prone to acne.'},
      {'name': 'Dry', 'desc': 'Feels tight, flaky, lacks moisture and can appear dull.'},
      {'name': 'Combination', 'desc': 'Oily T-zone (forehead, nose, chin) but dry/normal cheeks.'},
      {'name': 'Normal', 'desc': 'Balanced moisture, regular texture, few imperfections.'},
      {'name': 'Sensitive', 'desc': 'Prone to redness, burning, itching, or environmental allergies.'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("What is your skin type?", style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            "Select the description that matches your skin's daily behavior.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ...skinTypes.map((type) {
            final isSelected = _skinType == type['name'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _skinType = type['name']!;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGold.withValues(alpha: 0.08) : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryGold : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type['name']!,
                              style: TextStyle(
                                color: isSelected ? AppColors.primaryGold : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type['desc']!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.primaryGold : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // STEP 3: Concerns and Goals
  Widget _buildStepConcernsAndGoals() {
    final List<String> concerns = ["Acne / Breakouts", "Dark Spots / Pigmentation", "Dullness / Uneven Tone", "Wrinkles / Aging", "Redness / Irritation", "Enlarged Pores"];
    final List<String> goals = ["Clearer Skin", "Reduce Acne", "Even Out Skin Tone", "Reduce Signs of Aging", "Improve Hydration", "Build Consistent Routine"];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Your concerns & goals", style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            "Select all that apply. We use this to curate your product recommendations.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          
          // Concerns section
          Text("Primary Concerns", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: concerns.map((concern) {
              final isSelected = _selectedConcerns.contains(concern);
              return FilterChip(
                label: Text(concern),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedConcerns.add(concern);
                    } else {
                      _selectedConcerns.remove(concern);
                    }
                  });
                },
                backgroundColor: AppColors.cardBg,
                selectedColor: AppColors.primaryGold.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primaryGold,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primaryGold : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(color: isSelected ? AppColors.primaryGold : AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          
          // Goals section
          Text("Aesthetic Goals", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: goals.map((goal) {
              final isSelected = _selectedGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGoals.add(goal);
                    } else {
                      _selectedGoals.remove(goal);
                    }
                  });
                },
                backgroundColor: AppColors.cardBg,
                selectedColor: AppColors.accentSage.withValues(alpha: 0.15),
                checkmarkColor: AppColors.accentSage,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.accentSage : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(color: isSelected ? AppColors.accentSage : AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // STEP 4: Preferences & Sensitivities
  Widget _buildStepPreferences() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Final details", style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            "Do you have any chemical or product sensitivities? Let us know.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Sensitivities field
          Text("Sensitivities / Allergies", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sensitivitiesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: "E.g. Salicylic acid, Alcohol, fragrance (Optional)",
            ),
          ),
          const SizedBox(height: 40),

          // Notification Toggles
          Text("Notification Settings", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          
          _buildNotificationToggle(
            title: "Skin Scan Reminders",
            subtitle: "Remind me to capture a scan every Sunday to track trends.",
            value: _notifScan,
            onChanged: (val) => setState(() => _notifScan = val),
          ),
          _buildNotificationToggle(
            title: "Skincare Routine Reminders",
            subtitle: "Reminders for morning and evening skincare application.",
            value: _notifRoutine,
            onChanged: (val) => setState(() => _notifRoutine = val),
          ),
          _buildNotificationToggle(
            title: "Progress Updates",
            subtitle: "Receive charts summarizing skin improvements.",
            value: _notifProgress,
            onChanged: (val) => setState(() => _notifProgress = val),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryGold,
            activeTrackColor: AppColors.primaryGold.withValues(alpha: 0.3),
            inactiveTrackColor: AppColors.border,
          )
        ],
      ),
    );
  }
}
