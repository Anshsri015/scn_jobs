import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public legal pages, opened in the phone's browser.
class LegalLinks {
  LegalLinks._();

  static final Uri privacy = Uri.parse('https://scnjobs.com/privacy');
  static final Uri terms = Uri.parse('https://scnjobs.com/terms');

  static Future<void> open(BuildContext context, Uri url) async {
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the link.")),
      );
    }
  }
}
