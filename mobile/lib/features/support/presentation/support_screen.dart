import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Help center', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Reach support for ride issues, billing questions, and account help.', style: AppTextStyles.body),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.headset_mic_outlined),
              title: const Text('Call support'),
              subtitle: const Text('Available 24/7'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
