import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account settings', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Biometric login, notifications, support, and preferences will be managed here.', style: AppTextStyles.body),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment methods', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('M-Pesa • Airtel Money • Tigo Pesa'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(onPressed: () => context.go('/history'), child: const Text('Ride history')),
                      OutlinedButton(onPressed: () => context.go('/driver'), child: const Text('Driver profile')),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(label: 'Logout', onPressed: () {}, isSecondary: true),
          ],
        ),
      ),
    );
  }
}
