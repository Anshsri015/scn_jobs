import 'dart:async';
import 'package:flutter/material.dart';

/// 60s se count down karta hai; 0 pe pahunchte hi button enable ho jaata
/// hai. Tap karne pe `onResend` call karta hai aur timer restart karta hai.
class ResendCountdownButton extends StatefulWidget {
  const ResendCountdownButton({required this.onResend, super.key});

  final Future<void> Function() onResend;

  @override
  State<ResendCountdownButton> createState() => _ResendCountdownButtonState();
}

class _ResendCountdownButtonState extends State<ResendCountdownButton> {
  static const _totalSeconds = 60;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = _totalSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _handleTap() async {
    setState(() => _sending = true);
    try {
      await widget.onResend();
      if (mounted) _startTimer();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _secondsLeft == 0 && !_sending;
    return TextButton(
      onPressed: enabled ? _handleTap : null,
      child: Text(
        enabled ? 'Resend OTP' : 'Resend OTP in ${_secondsLeft}s',
      ),
    );
  }
}
