import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class RideDetailScreen extends StatelessWidget {
  const RideDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride details')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Airport transfer', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Completed • 08:30 • Premium ride', style: AppTextStyles.body),
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
                  Text('Pickup', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Julius Nyerere International Airport'),
                  SizedBox(height: 12),
                  Text('Drop-off', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Dar es Salaam City Center'),
                  SizedBox(height: 12),
                  Text('Fare', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('TZS 45,000'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
