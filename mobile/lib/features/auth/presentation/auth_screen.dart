import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authLoading = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(AppConstants.onboardingTitle, style: AppTextStyles.headline),
              const SizedBox(height: 12),
              const Text(AppConstants.onboardingSubtitle, style: AppTextStyles.body),
              const SizedBox(height: 24),
              TextField(decoration: const InputDecoration(labelText: 'Phone number')),
              const SizedBox(height: 12),
              TextField(obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const Spacer(),
              PrimaryButton(
                label: authLoading ? 'Signing in...' : 'Continue',
                onPressed: authLoading
                    ? () {}
                    : () async {
                        await ref.read(authControllerProvider.notifier).signIn(phoneOrEmail: '+255712345678', password: 'demo');
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
