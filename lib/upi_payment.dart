import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'class_roster.dart';
import 'firestore_database.dart';

String upiLink({
  required String upiId,
  required String name,
  required int amount,
  required String note,
}) {
  final query = {
    'pa': upiId,
    'pn': name,
    'am': amount.toString(),
    'cu': 'INR',
    'tn': note,
  };
  return Uri(scheme: 'upi', host: 'pay', queryParameters: query).toString();
}

class UpiIdCard extends StatelessWidget {
  const UpiIdCard({super.key, required this.upiId, required this.name});

  final String upiId;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (upiId.trim().isEmpty) return const SizedBox.shrink();
    final link = upiLink(upiId: upiId.trim(), name: name, amount: 0, note: 'Master Class');
    final colors = AppPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR UPI', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(upiId, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Center(
            child: QrImageView(
              data: link,
              size: 160,
              backgroundColor: Colors.white,
            ),
          ),
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: upiId)),
            icon: const Icon(Icons.copy),
            label: const Text('Copy UPI ID'),
          ),
        ],
      ),
    );
  }
}

class UpiPayPanel extends StatelessWidget {
  const UpiPayPanel({
    super.key,
    required this.listing,
    required this.fee,
    required this.onSubmitted,
  });

  final Map<String, dynamic> listing;
  final FeeLine fee;
  final VoidCallback onSubmitted;

  String get upiId => (listing['upi_id'] ?? listing['upiId'] ?? '').toString();

  Future<String> _masterUpi() async {
    if (upiId.isNotEmpty) return upiId;
    final masterId = (listing['creatorId'] ?? '').toString();
    if (masterId.isEmpty || masterId.startsWith('demo_')) return '';
    final profile = await firestore.collection('profiles').doc(masterId).get();
    return (profile.data()?['upiId'] ?? '').toString();
  }

  Future<void> _pay(BuildContext context) async {
    final id = await _masterUpi();
    if (!context.mounted) return;
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This master has not added a UPI ID yet.')),
      );
      return;
    }
    final amount = TextEditingController(text: '${fee.pending}');
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pay via UPI'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount',
            helperText: 'Pending ₹${fee.pending}. A smaller amount is a partial payment.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, int.tryParse(amount.text.trim())),
            child: const Text('Open UPI'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (chosen == null || chosen <= 0 || !context.mounted) return;
    final note = '${listing['title'] ?? 'Class'} · ${fee.attendeeName}';
    final link = upiLink(
      upiId: id,
      name: (listing['creatorName'] ?? 'Master').toString(),
      amount: chosen,
      note: note,
    );
    final opened = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No UPI app opened. Pay $id and then share the UTR.')),
      );
    }
    final utr = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share the UTR'),
        content: TextField(
          controller: utr,
          decoration: const InputDecoration(
            labelText: 'UTR or transaction reference',
            helperText: 'The master confirms this before the fee is marked paid.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, utr.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    utr.dispose();
    if (reference == null || reference.length < 4) return;
    await ClassRosterStore.instance.submitUtr(
      listingId: (listing['id'] ?? '').toString(),
      fee: fee,
      utr: reference,
      claimed: chosen,
    );
    onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    if (fee.pending <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _pay(context),
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: Text(fee.utrStatus == 'submitted' ? 'UTR sent · pay again' : 'Pay via UPI'),
      ),
    );
  }
}

Future<String> loadOwnUpiId() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '';
  final data = (await firestore.collection('profiles').doc(user.uid).get()).data();
  return (data?['upiId'] ?? '').toString();
}
