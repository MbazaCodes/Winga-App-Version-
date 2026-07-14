import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.isSecondary = false});

  final String label;
  final VoidCallback onPressed;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? AppColors.accentAmber : AppColors.primaryGreen,
          foregroundColor: isSecondary ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
