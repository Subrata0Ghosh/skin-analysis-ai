import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../models/skin_scan.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../auth/auth_screen.dart';
import '../scan/scan_camera_screen.dart';
import '../results/results_screen.dart';
import '../history/compare_scans_screen.dart';
import 'widgets/progress_chart.dart';
import 'widgets/aesthetics_guide_screen.dart';
import 'widgets/edit_profile_screen.dart';
import 'widgets/notification_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  UserProfile? _profile;
  List<SkinScan> _scans = [];
  bool _isLoading = true;

  // Checklist routine states (in-memory progress tracking)
  final List<bool> _morningChecked = [false, false, false, false];
  final List<bool> _eveningChecked = [false, false, false, false];
  
  // Qoves aesthetics additions
  bool _showSculptingRoutine = false;
  final List<bool> _sculptingChecked = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    if (authService.currentUid != null) {
      final profile = await storageService.getUserProfile(authService.currentUid!);
      final scans = await storageService.getSkinScans(authService.currentUid!);
      setState(() {
        _profile = profile;
        _scans = scans;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _triggerReload() {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

    final List<Widget> pages = [
      _buildDashboardView(),
      _buildHistoryView(),
      _buildRoutineView(),
      _buildProfileView(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Reload data whenever navigating between tabs
            if (index == 0 || index == 1) {
              _loadData();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardBg,
          selectedItemColor: AppColors.primaryGold,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: "Dashboard",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: "Scans",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              activeIcon: Icon(Icons.fact_check),
              label: "Routine",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }

  // VIEW 1: Dashboard
  Widget _buildDashboardView() {
    final lastScan = _scans.isNotEmpty ? _scans.first : null;
    final userName = _profile?.name ?? 'Skin Care Guest';
    final hasNoScans = _scans.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting & Tagline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, $userName",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  const Text("Here is your skin profile update.", style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              
              // Notification Badge/Indicator
              if (authIsDemo())
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    "Demo Mode",
                    style: TextStyle(color: AppColors.primaryGold, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Daily Skincare tip
          _buildDailyTipBanner(),
          const SizedBox(height: 16),

          // Qoves Scientific Aesthetics Advisor Card
          _buildQovesAestheticsCard(),
          const SizedBox(height: 16),

          // Core Radial Score Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF151522),
                  AppColors.cardBg,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shield_outlined, color: AppColors.primaryGold, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "DIAGNOSTIC HEALTH INDEX",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Animated gauge
                PremiumRadialScore(
                  score: hasNoScans ? 0.0 : lastScan!.overallScore.toDouble(),
                  skinAge: hasNoScans ? "No Scans" : "Skin Age: ${lastScan!.skinAge}",
                ),
                
                const SizedBox(height: 16),
                
                // Quick Summary Table
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem("Skin Type", hasNoScans ? (_profile?.skinType ?? "--") : lastScan!.skinType),
                    Container(height: 24, width: 1, color: AppColors.border),
                    _buildSummaryItem("Symmetry", hasNoScans ? "--" : "${lastScan!.symmetryScore.toStringAsFixed(0)}%"),
                    Container(height: 24, width: 1, color: AppColors.border),
                    _buildSummaryItem("Concerns", hasNoScans ? "None" : "${lastScan!.issues.length} Areas"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action CTAs (Analyze Face, Compare Scans)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScanCameraScreen(onScanCompleted: _triggerReload),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_enhance_outlined, size: 20),
                  label: const Text("Scan Face"),
                ),
              ),
              if (_scans.length >= 2) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CompareScansScreen(scans: _scans),
                        ),
                      );
                    },
                    icon: const Icon(Icons.compare, size: 20),
                    label: const Text("Compare"),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),

          // Trends Header
          Text("Health Over Time", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ProgressChart(scans: _scans),
          const SizedBox(height: 32),

          // History preview header
          if (_scans.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recent Analysis", style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1; // Nav to history tab
                    });
                  },
                  child: const Text("View All", style: TextStyle(color: AppColors.primaryGold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildScanHistoryCard(_scans.first),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildQovesAestheticsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AestheticsGuideScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryGold.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_3x3, color: AppColors.primaryGold, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Facial Aesthetics Reference",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Explore Qoves vertical thirds, symmetry & angles",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.primaryGold, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTipBanner() {
    String tip = "Sage tip: Hydration is the cornerstone of healthy skin. Drink at least 3L of water daily and lock it in with a light moisturizer.";
    if (_profile != null) {
      if (_profile!.skinType == 'Oily') {
        tip = "Oily skin tip: Avoid heavy creams. Choose gel-based moisturizers containing hyaluronic acid to hydrate without clogging pores.";
      } else if (_profile!.skinType == 'Dry') {
        tip = "Dry skin tip: Apply creams immediately after showering while skin is damp to trap extra moisture inside the dermal layers.";
      } else if (_profile!.skinType == 'Sensitive') {
        tip = "Sensitive skin tip: Always do patch tests for new serums. Look for calming ingredients like Centella Asiatica (Cica) and Ceramides.";
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSage.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentSage.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: AppColors.accentSage, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // VIEW 2: History List
  Widget _buildHistoryView() {
    if (_scans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                "No Skin Scans Yet",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                "Capture a photo using the scanner to see your first skin report.",
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScanCameraScreen(onScanCompleted: _triggerReload),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_enhance_outlined),
                label: const Text("Scan Now"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Scan History", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        itemCount: _scans.length,
        itemBuilder: (ctx, index) {
          final scan = _scans[index];
          return Dismissible(
            key: Key(scan.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: AppColors.diagnosticRedness,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: ctx,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text("Delete Scan"),
                  content: const Text("Are you sure you want to permanently delete this scan record?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text("Delete", style: TextStyle(color: AppColors.diagnosticRedness)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              final storageService = Provider.of<StorageService>(context, listen: false);
              final authService = Provider.of<AuthService>(context, listen: false);
              await storageService.deleteSkinScan(authService.currentUid!, scan.id);
              if (!mounted) return;
              setState(() {
                _scans.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Scan record deleted")),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildScanHistoryCard(scan),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanHistoryCard(SkinScan scan) {
    final dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(scan.dateTime);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResultsScreen(scan: scan)),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Circular score representation
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardBgSecondary,
                  border: Border.all(color: AppColors.primaryGold, width: 2),
                ),
                child: Center(
                  child: Text(
                    "${scan.overallScore}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Scan metadata details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.skinType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${scan.issues.length} conditions highlighted",
                      style: TextStyle(
                        color: scan.issues.isEmpty ? AppColors.accentSage : AppColors.accentRose,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // VIEW 3: Skincare Routine checklist
  Widget _buildRoutineView() {
    final lastScan = _scans.isNotEmpty ? _scans.first : null;
    
    final List<String> morningSteps = lastScan != null
        ? _filterRoutineSteps(lastScan.recommendations, isMorning: true)
        : _getDefaultRoutineSteps(isMorning: true);

    final List<String> eveningSteps = lastScan != null
        ? _filterRoutineSteps(lastScan.recommendations, isMorning: false)
        : _getDefaultRoutineSteps(isMorning: false);

    final List<String> sculptingSteps = [
      "Mewing Toning: Rest tongue flat to palate. Tones submandibular neck contour.",
      "Gua Sha Drainage: Sweep scraper 10 times from jaw center to ears to drain fluid.",
      "Zygomatic Lifts: Lift cheeks towards eyes and hold 5 seconds. Repeat 10 times.",
      "Posture chin tucks: Tuck chin and pull head back to fix forward-neck slouching."
    ];

    // Calculate progress fraction
    int completed = 0;
    int total = 0;

    if (_showSculptingRoutine) {
      completed = _sculptingChecked.sublist(0, sculptingSteps.length).where((c) => c).length;
      total = sculptingSteps.length;
    } else {
      int completedM = _morningChecked.sublist(0, morningSteps.length).where((c) => c).length;
      int completedE = _eveningChecked.sublist(0, eveningSteps.length).where((c) => c).length;
      completed = completedM + completedE;
      total = morningSteps.length + eveningSteps.length;
    }
    double progress = total > 0 ? completed / total : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_showSculptingRoutine ? "Facial Toning Guide" : "Daily Skincare Routine", style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 6),
          Text(
            _showSculptingRoutine 
                ? "Perform these physical face sculpting movements to align proportions." 
                : "Complete steps and check off to track your daily habits.", 
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Segmented Toggle
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showSculptingRoutine = false),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_showSculptingRoutine ? AppColors.primaryGold : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Skincare",
                        style: TextStyle(
                          color: !_showSculptingRoutine ? AppColors.textDark : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showSculptingRoutine = true),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _showSculptingRoutine ? AppColors.accentSage : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Face Toning",
                        style: TextStyle(
                          color: _showSculptingRoutine ? AppColors.textDark : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Progress Tracker Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_showSculptingRoutine ? AppColors.accentSage : AppColors.primaryGold).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (_showSculptingRoutine ? AppColors.accentSage : AppColors.primaryGold).withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's Progress", style: TextStyle(fontWeight: FontWeight.bold, color: _showSculptingRoutine ? AppColors.accentSage : AppColors.primaryGold)),
                    Text(
                      "${(progress * 100).round()}% Completed",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _showSculptingRoutine ? AppColors.accentSage : AppColors.primaryGold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: _showSculptingRoutine ? AppColors.accentSage : AppColors.primaryGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (_showSculptingRoutine) ...[
            Row(
              children: const [
                Icon(Icons.fitness_center, color: AppColors.accentSage, size: 22),
                SizedBox(width: 10),
                Text("Structural Exercises", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sculptingSteps.length,
              itemBuilder: (context, index) {
                return _buildRoutineItem(
                  step: sculptingSteps[index],
                  isChecked: _sculptingChecked[index],
                  onChanged: (val) {
                    setState(() {
                      _sculptingChecked[index] = val ?? false;
                    });
                  },
                );
              },
            ),
          ] else ...[
            // Morning Routine Section
            Row(
              children: const [
                Icon(Icons.wb_sunny_outlined, color: AppColors.primaryGold, size: 22),
                SizedBox(width: 10),
                Text("Morning Routine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: morningSteps.length,
              itemBuilder: (context, index) {
                return _buildRoutineItem(
                  step: morningSteps[index],
                  isChecked: _morningChecked[index],
                  onChanged: (val) {
                    setState(() {
                      _morningChecked[index] = val ?? false;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 32),

            // Evening Routine Section
            Row(
              children: const [
                Icon(Icons.dark_mode_outlined, color: AppColors.diagnosticCircles, size: 22),
                SizedBox(width: 10),
                Text("Evening Routine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: eveningSteps.length,
              itemBuilder: (context, index) {
                return _buildRoutineItem(
                  step: eveningSteps[index],
                  isChecked: _eveningChecked[index],
                  onChanged: (val) {
                    setState(() {
                      _eveningChecked[index] = val ?? false;
                    });
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutineItem({
    required String step,
    required bool isChecked,
    required ValueChanged<bool?> onChanged,
  }) {
    // Separate product title from description
    final parts = step.split(":");
    final title = parts.isNotEmpty ? parts[0] : "Step";
    final desc = parts.length > 1 ? parts[1].trim() : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.cardBg.withValues(alpha: 0.4) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isChecked ? AppColors.border.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: onChanged,
        activeColor: AppColors.primaryGold,
        checkColor: AppColors.textDark,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isChecked ? AppColors.textMuted : AppColors.textPrimary,
            decoration: isChecked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: desc.isNotEmpty
            ? Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isChecked ? AppColors.textMuted : AppColors.textSecondary,
                ),
              )
            : null,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  List<String> _filterRoutineSteps(List<String> recommendations, {required bool isMorning}) {
    // Filter recommendations by AM or PM indicators
    final List<String> list = [];
    for (var rec in recommendations) {
      if (isMorning) {
        // Exclude Salicylic acid or retinol steps for morning as they sensitize to sun
        if (!rec.contains("evening") && !rec.contains("night") && !rec.contains("Evening") && !rec.contains("Night")) {
          list.add(rec);
        }
      } else {
        // Exclude Sunscreen for evening
        if (!rec.contains("Sunscreen") && !rec.contains("SPF")) {
          list.add(rec);
        }
      }
    }
    return list.take(4).toList();
  }

  List<String> _getDefaultRoutineSteps({required bool isMorning}) {
    if (isMorning) {
      return [
        "Gentle Hydrating Cleanser: Wash face with cool water to cleanse nighttime sweat.",
        "Hyaluronic Acid Serum: Apply on damp skin to seal hydration layer.",
        "Light Moisturizer: Protect skin and prevent water loss.",
        "SPF 50+ Sunscreen: Shield against UV pigmentation and wrinkles."
      ];
    } else {
      return [
        "Double Cleanse: Use an oil cleanser first, followed by a water-based wash to wipe sebum/SPF.",
        "Calming Niacinamide Serum: Minimize redness and repair epidermal layer.",
        "Ceramide Cream: Locks in hydration and boosts moisture wall.",
      ];
    }
  }

  // VIEW 4: Profile & settings
  Widget _buildProfileView() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Header
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryGold.withValues(alpha: 0.12),
                child: const Icon(Icons.person, color: AppColors.primaryGold, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?.name ?? "Demo User",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authIsDemo() ? "Guest (Demo Profile)" : "Premium Member",
                      style: const TextStyle(color: AppColors.primaryGold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Skin Metadata Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Skin Metrics", style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 14, color: AppColors.primaryGold),
                label: const Text("Edit", style: TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (_profile != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                          profile: _profile!,
                          onSaved: _loadData,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildProfileMetaRow("Analyzed Skin Type", _profile?.skinType ?? "Normal"),
                const Divider(color: AppColors.border),
                _buildProfileMetaRow("Selected Age Profile", "${_profile?.age ?? 25} years"),
                const Divider(color: AppColors.border),
                _buildProfileMetaRow("Aesthetic Goals", _profile?.goals.join(", ") ?? "Clearer skin"),
                const Divider(color: AppColors.border),
                _buildProfileMetaRow("Sensitivities", _profile?.knownSensitivities.isNotEmpty == true ? _profile!.knownSensitivities : "None reported"),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Account & Notification Settings
          Text("App Settings", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryGold),
                  title: const Text("Manage Notifications", style: TextStyle(fontSize: 14, color: Colors.white)),
                  subtitle: const Text("Tweak routine and weekly scan alerts.", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                  onTap: () {
                    if (_profile != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationSettingsScreen(
                            profile: _profile!,
                            onSaved: _loadData,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Privacy Actions
          Text("Data Settings", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Reset/Wipe button
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.diagnosticRedness),
                  title: const Text("Wipe Scan History", style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: const Text("Delete all past scan results and photos permanently.", style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Wipe History"),
                        content: const Text("This will permanently delete all your skin scans from our system. This action cannot be undone."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Wipe Data", style: TextStyle(color: AppColors.diagnosticRedness)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await storageService.wipeUserData(authService.currentUid!);
                      if (!mounted) return;
                      setState(() {
                        _scans.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Scan records wiped successfully.")),
                      );
                    }
                  },
                ),
                
                // Account deletion simulator
                ListTile(
                  leading: const Icon(Icons.no_accounts_outlined, color: AppColors.diagnosticRedness),
                  title: const Text("Delete Account Data", style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: const Text("Permanently remove profile preferences and login tokens.", style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Account"),
                        content: const Text("This will erase your entire account profile, sensitivities, and scans. You will be logged out."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete", style: TextStyle(color: AppColors.diagnosticRedness)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await storageService.wipeUserData(authService.currentUid!);
                      await authService.logout();
                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Logout Button
          ElevatedButton.icon(
            onPressed: () async {
              await authService.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text("Log Out"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.diagnosticRedness.withValues(alpha: 0.12),
              foregroundColor: AppColors.diagnosticRedness,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.diagnosticRedness, width: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  bool authIsDemo() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return authService.isDemoMode;
  }
}

// Premium animated radial score gauge
class PremiumRadialScore extends StatelessWidget {
  final double score;
  final String skinAge;

  const PremiumRadialScore({
    super.key,
    required this.score,
    required this.skinAge,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: score / 100.0),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final currentScoreVal = (value * 100).toInt();
        return Column(
          children: [
            SizedBox(
              height: 160,
              width: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gauge Custom Paint overlay
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RadialScoreGaugePainter(progress: value),
                    ),
                  ),
                  
                  // Score numbers count-up and age indicator
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score == 0.0 ? "--" : "$currentScoreVal",
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                          shadows: [
                            Shadow(
                              color: AppColors.primaryGold.withValues(alpha: 0.5),
                              blurRadius: 15,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Text(
                          skinAge,
                          style: const TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom Painter for the premium radial arc
class RadialScoreGaugePainter extends CustomPainter {
  final double progress;

  RadialScoreGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final double startAngle = math.pi * 0.75;
    final double totalSweepAngle = math.pi * 1.5;
    final double activeSweepAngle = totalSweepAngle * progress;

    // 1. Draw background track track
    final trackPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweepAngle,
      false,
      trackPaint,
    );

    // 2. Draw active glowing sweep
    final activePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primaryGold.withValues(alpha: 0.7),
          AppColors.primaryGold,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweepAngle,
      false,
      activePaint,
    );

    // 3. Draw active glow shadow under the arc
    final glowPaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.15)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweepAngle,
      false,
      glowPaint,
    );

    // 4. Draw indicator needle/dot at the active tip
    final double endAngle = startAngle + activeSweepAngle;
    final double needleX = center.dx + radius * math.cos(endAngle);
    final double needleY = center.dy + radius * math.sin(endAngle);

    final needlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final outerNeedlePaint = Paint()
      ..color = AppColors.primaryGold
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(needleX, needleY), 7.0, outerNeedlePaint);
    canvas.drawCircle(Offset(needleX, needleY), 3.5, needlePaint);
  }

  @override
  bool shouldRepaint(covariant RadialScoreGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
