import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/booking/presentation/booking_flow_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/payment/presentation/payment_screen.dart';
import '../../features/requests/presentation/request_status_screen.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/history/presentation/ride_history_screen.dart';
import '../../features/history/presentation/ride_detail_screen.dart';
import '../../features/driver/presentation/driver_profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/booking', builder: (context, state) => const BookingFlowScreen()),
      GoRoute(path: '/payment', builder: (context, state) => const PaymentScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/requests', builder: (context, state) => const RequestStatusScreen()),
      GoRoute(path: '/tracking', builder: (context, state) => const TrackingScreen()),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
      GoRoute(path: '/history', builder: (context, state) => const RideHistoryScreen()),
      GoRoute(path: '/ride-detail', builder: (context, state) => const RideDetailScreen()),
      GoRoute(path: '/driver', builder: (context, state) => const DriverProfileScreen()),
    ],
  );
});
