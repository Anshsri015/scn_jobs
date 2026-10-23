import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 6-digit OTP field. Uses `autofillHints: [AutofillHints.oneTimeCode]`
/// so Android's SMS Retriever autofill can populate it directly.
class OtpField extends StatelessWidget {
  const OtpField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 8),
      decoration: const InputDecoration(
        counterText: '',
        hintText: '000000',
      ),
      validator: (v) =>
          (v == null || v.length != 6) ? '6-digit OTP daalo' : null,
    );
  }
}
