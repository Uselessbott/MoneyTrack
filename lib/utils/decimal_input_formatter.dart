import 'package:flutter/services.dart';

class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.decimalRange = 2});

  final int decimalRange;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) return newValue;

    final pattern = RegExp('^\\d*\\.?\\d{0,$decimalRange}\$');
    if (!pattern.hasMatch(newValue.text)) {
      return oldValue;
    }
    return newValue;
  }
}