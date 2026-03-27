import 'package:flutter/material.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

class AppFeedbackDialog {
  const AppFeedbackDialog._();

  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Aceptar',
  }) {
    return PanaraInfoDialog.showAnimatedFade(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      panaraDialogType: PanaraDialogType.success,
      onTapDismiss: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  static Future<void> error(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Entendido',
  }) {
    return PanaraInfoDialog.showAnimatedFade(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      panaraDialogType: PanaraDialogType.error,
      onTapDismiss: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  static Future<void> warning(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Entendido',
  }) {
    return PanaraInfoDialog.showAnimatedFade(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      panaraDialogType: PanaraDialogType.warning,
      onTapDismiss: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return PanaraInfoDialog.showAnimatedFade(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      panaraDialogType: PanaraDialogType.normal,
      onTapDismiss: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }
}
