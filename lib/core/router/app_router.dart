import 'package:go_router/go_router.dart';
import 'package:campuslink/features/auth/screens/splash_screen.dart';
import 'package:campuslink/features/auth/screens/onboarding_screen.dart';
import 'package:campuslink/features/auth/screens/login_screen.dart';
import 'package:campuslink/features/auth/screens/register_screen.dart';
import 'package:campuslink/features/auth/screens/pin_setup_screen.dart';
import 'package:campuslink/features/auth/screens/pin_login_screen.dart';
import 'package:campuslink/features/home/screens/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/pin-setup', builder: (_, __) => const PinSetupScreen()),
    GoRoute(path: '/pin-login', builder: (_, __) => const PinLoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
  ],
);