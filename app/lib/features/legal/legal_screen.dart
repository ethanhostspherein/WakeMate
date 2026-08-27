import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared scaffold for the Privacy Policy / Terms of Service screens —
/// plain scrollable text, no network fetch, ships inside the app bundle.
class _LegalScaffold extends StatelessWidget {
  final String title;
  final String body;

  const _LegalScaffold({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = 'August 26, 2026';

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Privacy Policy',
      body: '''Last updated: $_lastUpdated

WakeMate ("we", "us", "the app") helps you sleep on the way to your stop by tracking your live location and waking you before you arrive. This policy explains what we collect and why.

1. INFORMATION WE COLLECT
• Location data — precise GPS location, including in the background while a trip is active, so we can calculate your remaining distance and trigger your alarm on time.
• Account information — your email address, if you choose to sign in for cloud sync. Guest use requires no account.
• Family contact details — the name and phone number you enter for "Notify Family", stored so you can reuse it on future trips.
• Trip history — destination, alarm distance/time, and trip status, so your Recent Trips and Favorites work.

2. HOW WE USE IT
Solely to power the app's core features: live trip tracking, distance/time-based alarms, trip history, and the optional family-notify deep link. We do not use your data for advertising, and we do not sell your data to anyone.

3. THIRD-PARTY SERVICES
• Supabase — our backend/database provider. Your account and trip data are stored there, protected by row-level access rules so only you can read or write your own data.
• Map/geocoding services — used to search destinations and render the map preview; only the coordinates you search for are sent.

4. FAMILY NOTIFY FEATURE
When enabled, dismissing the alarm opens WhatsApp or your SMS app with a pre-filled message addressed to the number you provided. WakeMate does not send this message itself and does not read your messages — you send it with one tap inside that app.

5. DATA STORAGE & SECURITY
Your trips and contacts are stored locally on your device first, and mirrored to our Supabase database only when you're signed in, so you can access your history across devices.

6. YOUR RIGHTS
You can delete your saved contacts and trip history from within the app at any time. To request full account deletion, email us at the address below. Signing out stops cloud sync; uninstalling the app removes all local data.

7. CHILDREN
WakeMate is not directed at children under 13, and we do not knowingly collect data from them.

8. CHANGES TO THIS POLICY
We may update this policy as the app changes. The "Last updated" date above will reflect the latest revision.

9. CONTACT US
Questions about this policy: support@wakemate.app''',
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _lastUpdated = 'August 26, 2026';

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Terms of Service',
      body: '''Last updated: $_lastUpdated

By using WakeMate, you agree to these terms.

1. THE SERVICE
WakeMate is a GPS-based travel alarm: it tracks your location and alerts you as you approach your chosen stop. It is a convenience tool, not a safety or emergency service.

2. NO GUARANTEE OF ACCURACY
GPS signal, network conditions, and device battery-optimization settings can all delay or prevent an alarm from firing. Do not rely on WakeMate as your only means of knowing when to get off — always verify your stop yourself, especially on unfamiliar or high-stakes journeys.

3. YOUR RESPONSIBILITIES
• Provide an accurate destination and keep location/notification/battery permissions enabled for reliable tracking.
• Any phone number you enter for the family-notify feature is your responsibility — WakeMate does not verify that person's identity or consent.

4. FAMILY NOTIFY
This feature opens WhatsApp/SMS with a pre-filled message; you must tap Send yourself. WakeMate is not responsible for messages that fail to send, are delayed, or are sent to an incorrect number you entered.

5. NO WARRANTY
WakeMate is provided "as is," without warranty of any kind. We are not liable for missed stops, travel delays, or any loss arising from reliance on the app's alerts.

6. PREMIUM FEATURES
Any optional one-time paid unlock is for ad-free use only, is non-recurring, and does not affect the core alarm functionality, which remains free.

7. ACCOUNT & TERMINATION
We may suspend or terminate access for accounts that abuse the service or violate these terms.

8. GOVERNING LAW
These terms are governed by the laws of India.

9. CONTACT US
Questions about these terms: support@wakemate.app''',
    );
  }
}
