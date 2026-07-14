import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/primary_button.dart';

class BookingForm extends StatefulWidget {
  const BookingForm({super.key});

  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  final _pickupController = TextEditingController(text: 'Airport');
  final _dropoffController = TextEditingController(text: 'Downtown');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Booking details', style: AppTextStyles.headline.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        TextField(
          controller: _pickupController,
          decoration: const InputDecoration(labelText: 'Pickup location'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dropoffController,
          decoration: const InputDecoration(labelText: 'Dropoff location'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Estimated fare'),
              Text('TZS 45,000', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Confirm booking', onPressed: () {}),
      ],
    );
  }
}
