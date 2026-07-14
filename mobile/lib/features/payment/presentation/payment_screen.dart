import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/primary_button.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose your payment method', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('M-Pesa, Airtel Money, Tigo Pesa, and HaloPesa are prepared for the V3 release.', style: AppTextStyles.body),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                Chip(label: Text('M-Pesa')),
                Chip(label: Text('Airtel Money')),
                Chip(label: Text('Tigo Pesa')),
                Chip(label: Text('HaloPesa')),
              ],
            ),
            const Spacer(),
            PrimaryButton(label: 'Proceed to pay', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
