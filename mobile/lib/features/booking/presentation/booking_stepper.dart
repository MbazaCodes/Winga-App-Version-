import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/primary_button.dart';

class BookingStepper extends StatefulWidget {
  const BookingStepper({super.key});

  @override
  State<BookingStepper> createState() => _BookingStepperState();
}

class _BookingStepperState extends State<BookingStepper> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Choose trip',
      'Confirm details',
      'Pay securely',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Booking stepper', style: AppTextStyles.headline.copyWith(fontSize: 20)),
        const SizedBox(height: 12),
        Stepper(
          currentStep: _step,
          onStepContinue: () {
            if (_step < steps.length - 1) {
              setState(() => _step += 1);
            }
          },
          onStepCancel: () {
            if (_step > 0) {
              setState(() => _step -= 1);
            }
          },
          steps: [
            Step(
              title: const Text('Trip details'),
              content: const Text('Select pickup, destination, and ride category.'),
            ),
            Step(
              title: const Text('Confirm booking'),
              content: const Text('Review fare, travel time, and preferences.'),
            ),
            Step(
              title: const Text('Payment'),
              content: const Text('Complete payment and receive booking confirmation.'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Continue', onPressed: () {
          if (_step < 2) {
            setState(() => _step += 1);
          }
        }),
      ],
    );
  }
}
