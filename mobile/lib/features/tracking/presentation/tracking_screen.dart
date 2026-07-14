import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track ride')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live tracking', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Follow the driver and estimated arrival time.', style: AppTextStyles.body),
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
                  Text('ETA', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('8 minutes'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
