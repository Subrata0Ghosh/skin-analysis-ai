import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auraskin_ai/core/theme/app_theme.dart';
import 'package:auraskin_ai/models/user_profile.dart';
import 'package:auraskin_ai/models/skin_scan.dart';
import 'package:auraskin_ai/services/auth_service.dart';
import 'package:auraskin_ai/services/storage_service.dart';
import 'package:auraskin_ai/views/splash/splash_screen.dart';
import 'package:auraskin_ai/views/onboarding/onboarding_screen.dart';
import 'package:auraskin_ai/views/auth/auth_screen.dart';
import 'package:auraskin_ai/views/onboarding/questionnaire_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.isFirebaseInitialized = false;
  });

  group('Model Serialization Tests', () {
    test('UserProfile model serialization test', () {
      final profile = UserProfile(
        uid: 'test_uid',
        name: 'John Doe',
        age: 30,
        gender: 'Male',
        skinType: 'Dry',
        primaryConcerns: ['Acne'],
        goals: ['Clearer Skin'],
        knownSensitivities: 'Alcohol',
        notifications: {'scan': true, 'routine': false, 'progress': true},
      );

      final map = profile.toMap();
      expect(map['uid'], 'test_uid');
      expect(map['name'], 'John Doe');
      expect(map['age'], 30);
      expect(map['gender'], 'Male');
      expect(map['skinType'], 'Dry');
      expect(map['primaryConcerns'], ['Acne']);
      expect(map['goals'], ['Clearer Skin']);
      expect(map['knownSensitivities'], 'Alcohol');
      expect(map['notifications']['routine'], false);

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.uid, 'test_uid');
      expect(fromMap.name, 'John Doe');
      expect(fromMap.age, 30);
      expect(fromMap.skinType, 'Dry');
      expect(fromMap.notifications['routine'], false);
    });

    test('SkinScan model serialization test', () {
      final scan = SkinScan(
        id: 'scan_123',
        uid: 'user_123',
        dateTime: DateTime(2026, 7, 2),
        imagePath: 'assets/images/sample_face.png',
        overallScore: 88,
        skinAge: 25,
        skinType: 'Combination',
        detailScores: {'acne': 90, 'redness': 80},
        issues: [
          ScanIssue(
            label: 'Active Breakout',
            type: 'acne',
            x: 0.5,
            y: 0.25,
            radius: 0.05,
            severity: 'Mild',
            description: 'A small blemish.',
          )
        ],
        recommendations: ['Salicylic acid cleanser'],
        symmetryScore: 92.4,
        verticalThirds: [0.334, 0.331, 0.335],
        jawlineAngle: 122.5,
        cheekboneSymmetry: 93.8,
      );

      final map = scan.toMap();
      expect(map['id'], 'scan_123');
      expect(map['overallScore'], 88);
      expect(map['issues'][0]['label'], 'Active Breakout');

      final fromMap = SkinScan.fromMap(map);
      expect(fromMap.id, 'scan_123');
      expect(fromMap.overallScore, 88);
      expect(fromMap.issues[0].label, 'Active Breakout');
    });
  });

  group('Widget UI Verification Tests', () {
    // Helper to wrap widgets in necessary provider hierarchy
    Widget buildTestableWidget(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(
            create: (_) => AuthService(),
          ),
          ProxyProvider<AuthService, StorageService>(
            update: (context, auth, previousStorage) => StorageService(false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: child,
        ),
      );
    }

    testWidgets('SplashScreen UI elements test', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const SplashScreen()));

      // Verify splash structures
      expect(find.text("A U R A S K I N"), findsOneWidget);
      expect(find.text("Understand your skin, clearly."), findsOneWidget);
      expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    });

    testWidgets('OnboardingScreen slides & indicators test', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const OnboardingScreen()));

      // Slide 1 text
      expect(find.textContaining("Meet Your Personal"), findsOneWidget);
      expect(find.text("Skip"), findsOneWidget);
      expect(find.text("Next"), findsOneWidget);

      // Tap next to slide 2
      await tester.tap(find.text("Next"));
      await tester.pumpAndSettle();

      // Slide 2 text
      expect(find.textContaining("Scan in Seconds"), findsOneWidget);

      // Tap next to slide 3
      await tester.tap(find.text("Next"));
      await tester.pumpAndSettle();

      // Slide 3 text
      expect(find.textContaining("Targeted Routines"), findsOneWidget);
      expect(find.text("Get Started"), findsOneWidget);
    });

    testWidgets('AuthScreen email validation & toggles test', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AuthScreen()));

      // Verify sign in screen widgets
      expect(find.text("AURA SKIN"), findsOneWidget);
      expect(find.text("Sign In"), findsNWidgets(2)); // Tab title & button text
      expect(find.text("Join Aura"), findsOneWidget);
      expect(find.text("Email Address"), findsOneWidget);
      expect(find.text("Password"), findsOneWidget);
      expect(find.text("Instant Demo Access (Evaluator Key)"), findsOneWidget);

      // Click join aura tab
      await tester.tap(find.text("Join Aura"));
      await tester.pumpAndSettle();

      // Verify registration inputs
      expect(find.text("Full Name"), findsOneWidget);
      expect(find.text("Confirm Password"), findsOneWidget);
      expect(find.text("Create Account"), findsOneWidget);
    });

    testWidgets('QuestionnaireScreen stepper path test', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const QuestionnaireScreen()));

      // Step 1: Personal Info
      expect(find.text("Tell us about yourself"), findsOneWidget);
      expect(find.text("What should we call you?"), findsOneWidget);
      expect(find.text("Your Age"), findsOneWidget);
      expect(find.text("Gender Identity"), findsOneWidget);
      expect(find.text("Female"), findsOneWidget);
      expect(find.text("Continue"), findsOneWidget);

      // Select Male
      await tester.tap(find.text("Male"));
      await tester.pumpAndSettle();

      // Click Continue to Step 2
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Step 2: Skin Type
      expect(find.text("What is your skin type?"), findsOneWidget);
      expect(find.text("Oily"), findsOneWidget);
      expect(find.text("Combination"), findsOneWidget);

      // Select Dry
      await tester.tap(find.text("Dry"));
      await tester.pumpAndSettle();

      // Click Continue to Step 3
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Step 3: Concerns and Goals
      expect(find.text("Your concerns & goals"), findsOneWidget);
      expect(find.text("Primary Concerns"), findsOneWidget);
      expect(find.text("Aesthetic Goals"), findsOneWidget);

      // Select Acne concern
      await tester.tap(find.text("Acne / Breakouts"));
      await tester.pumpAndSettle();

      // Click Continue to Step 4
      await tester.tap(find.text("Continue"));
      await tester.pumpAndSettle();

      // Step 4: Final details
      expect(find.text("Final details"), findsOneWidget);
      expect(find.text("Sensitivities / Allergies"), findsOneWidget);
      expect(find.text("Notification Settings"), findsOneWidget);
      expect(find.text("Complete Profile"), findsOneWidget);
    });
  });
}
