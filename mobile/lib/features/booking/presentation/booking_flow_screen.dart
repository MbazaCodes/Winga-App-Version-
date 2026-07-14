import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import 'booking_form.dart';
import 'booking_stepper.dart';

class BookingFlowScreen extends StatelessWidget {
  const BookingFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking flow')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create a booking', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('The V3 booking experience preserves the core flow while improving structure and reusability.', style: AppTextStyles.body),
            const SizedBox(height: 24),
            const Expanded(child: Column(
              children: [
                BookingForm(),
                SizedBox(height: 16),
                Expanded(child: BookingStepper()),
              ],
            )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
