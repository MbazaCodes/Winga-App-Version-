import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Driver profile', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Profile details, rating, and availability for the assigned driver.', style: AppTextStyles.body),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salum M.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('4.9 ★ • 230 rides • Premium sedan'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
