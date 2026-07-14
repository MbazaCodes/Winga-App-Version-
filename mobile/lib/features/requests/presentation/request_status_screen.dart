import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class RequestStatusScreen extends StatelessWidget {
  const RequestStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request status')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request status', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Pending assignment', style: AppTextStyles.body),
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
                  Text('Driver', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('Awaiting confirmation from the assigned driver.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
