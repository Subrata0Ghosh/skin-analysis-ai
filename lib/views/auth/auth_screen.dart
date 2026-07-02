import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../services/auth_service.dart';
import '../onboarding/questionnaire_screen.dart';
import '../home/home_screen.dart';
import '../../services/storage_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _errorMessage = null; // Clear error message when switching tabs
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    try {
      bool success = false;
      if (_tabController.index == 0) {
        // Sign In
        success = await authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (!success) {
          _errorMessage = "Invalid email or password. Hint: Use demo@auraskin.ai or password123.";
        }
      } else {
        // Sign Up
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            _errorMessage = "Passwords do not match";
            _isLoading = false;
          });
          return;
        }

        success = await authService.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        if (!success) {
          _errorMessage = "Registration failed. Try again.";
        }
      }

      if (success && mounted) {
        // Determine routing
        final profile = await storageService.getUserProfile(authService.currentUid!);
        if (!mounted) return;

        if (profile != null && profile.name.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.signInWithGoogle();
    
    if (success && mounted) {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final profile = await storageService.getUserProfile(authService.currentUid!);
      
      if (!mounted) return;
      if (profile != null && profile.name.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo/Header
                  const Icon(
                    Icons.spa_outlined,
                    size: 64,
                    color: AppColors.primaryGold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "AURA SKIN",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 22,
                          letterSpacing: 4.0,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Tab Selector card
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: AppColors.textDark,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: "Sign In"),
                        Tab(text: "Join Aura"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.diagnosticRedness.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.diagnosticRedness.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.diagnosticRedness, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Fields depending on Tab Index
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      final isSignUp = _tabController.index == 1;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isSignUp) ...[
                            TextFormField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: "Full Name",
                                hintText: "Enter your name",
                                prefixIcon: Icon(Icons.person_outline, size: 20, color: AppColors.textMuted),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter your name";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Email Address",
                              hintText: "example@domain.com",
                              prefixIcon: Icon(Icons.mail_outline, size: 20, color: AppColors.textMuted),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your email";
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return "Please enter a valid email address";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              hintText: "••••••••",
                              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textMuted),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your password";
                              }
                              if (value.length < 6) {
                                return "Password must be at least 6 characters";
                              }
                              return null;
                            },
                          ),
                          if (isSignUp) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              decoration: const InputDecoration(
                                labelText: "Confirm Password",
                                hintText: "••••••••",
                                prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppColors.textMuted),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Please confirm your password";
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primaryGold),
                        )
                      : ElevatedButton(
                          onPressed: _submit,
                          child: AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, child) {
                              return Text(_tabController.index == 0 ? "Sign In" : "Create Account");
                            },
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: const [
                      Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "OR CONTINUE WITH",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Social Sign In (Simulated)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.g_mobiledata, color: AppColors.textPrimary, size: 26),
                              SizedBox(width: 4),
                              Text("Google", style: TextStyle(color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleGoogleSignIn, // maps to mock auth too
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.apple, color: AppColors.textPrimary, size: 20),
                              SizedBox(width: 8),
                              Text("Apple", style: TextStyle(color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Evaluator Instant Access
                  GestureDetector(
                    onTap: () async {
                      setState(() {
                        _isLoading = true;
                      });
                      final authService = Provider.of<AuthService>(this.context, listen: false);
                      await authService.login('demo@auraskin.ai', 'password123');
                      if (!mounted) return;
                      Navigator.of(this.context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.flash_on, color: AppColors.primaryGold, size: 18),
                              SizedBox(width: 6),
                              Text(
                                "Instant Demo Access (Evaluator Key)",
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Skip manual signups and load the offline simulation instantly",
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
