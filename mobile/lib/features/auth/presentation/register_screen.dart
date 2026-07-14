import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 16),
            TextField(decoration: const InputDecoration(labelText: 'Phone number')),
            const SizedBox(height: 16),
            TextField(obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                onPressed: () => context.go('/home'),
                child: const Text('Create account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
