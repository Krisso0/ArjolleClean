import 'package:flutter/material.dart';
import 'success_screen.dart';

/// Factory class to create SuccessScreen without Riverpod dependencies
class SuccessScreenFactory {
  /// Static method to create and navigate to a SuccessScreen
  /// This avoids Riverpod reference issues by not using any provider references during navigation
  static void navigateToSuccessScreen(
    BuildContext context, {
    required String firstName,
    required String lastName,
    required Map<String, Map<String, String>> taskHours,
    required String filePath,
    required String companyName,
  }) {
    // Push replacement without any provider dependencies
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SuccessScreen(
          firstName: firstName,
          lastName: lastName,
          taskHours: taskHours,
          filePath: filePath,
          companyName: companyName,
        ),
      ),
    );
  }
}
