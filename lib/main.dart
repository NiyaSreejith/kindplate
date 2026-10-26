import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/navigation/main_navigation_shell.dart';
import 'screens/onboarding/auth_screen.dart';
import 'screens/onboarding/netflix_role_selection_screen.dart';
import 'screens/onboarding/onboarding_carousel_screen.dart';
import 'screens/onboarding/role_selection_screen.dart';
import 'screens/onboarding/splash_poster_screen.dart';
import 'services/firebase_auth_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
      '🔥 Firebase initialized successfully for: ${DefaultFirebaseOptions.currentPlatform.projectId}',
    );
  } catch (e) {
    debugPrint('ℹ️ Firebase initialization note: $e');
  }
  await FirebaseAuthService().initialize();
  runApp(const KindPlateApp());
}

class KindPlateApp extends StatefulWidget {
  const KindPlateApp({super.key});

  @override
  State<KindPlateApp> createState() => _KindPlateAppState();
}

class _KindPlateAppState extends State<KindPlateApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        return MaterialApp(
          title: 'KindPlate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(accessibleNavigation: false),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildCurrentScreen(_state),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen(AppState state) {
    final screen = switch (state.onboardingStep) {
      0 => SplashPosterScreen(state: state),
      1 => OnboardingCarouselScreen(state: state),
      2 => NetflixRoleSelectionScreen(
        state: state,
      ), // Step 2: Netflix "Who's Watching?" profile screen before signup
      3 => AuthScreen(
        state: state,
        initialMode: state.targetAuthMode,
        initialRole: state.targetSignupRole,
      ), // Step 3: Login / Signup
      4 => RoleSelectionScreen(state: state), // Step 4: Choose Your Role
      _ => MainNavigationShell(state: state), // Step 5+: Main Dashboard
    };

    return PopScope(
      canPop: state.onboardingStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.onboardingStep >= 5) {
          // Inside main authenticated experience
        } else if (state.onboardingStep == 4) {
          state.setOnboardingStep(!state.currentUser.isDemo ? 5 : 2);
        } else if (state.onboardingStep == 3) {
          state.setOnboardingStep(
            2,
          ); // From Sign Up back to Netflix Profile Selection
        } else if (state.onboardingStep == 2) {
          state.setOnboardingStep(1); // From Netflix Profile back to Carousel
        } else if (state.onboardingStep == 1) {
          state.setOnboardingStep(0); // Back to Splash
        }
      },
      child: KeyedSubtree(
        key: ValueKey<int>(state.onboardingStep),
        child: screen,
      ),
    );
  }
}

