import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'class_reminders.dart';
import 'firestore_database.dart';
import 'member_id.dart';
import 'upi_payment.dart';

class MasterContact {
  const MasterContact({
    required this.name,
    required this.phone,
    required this.email,
    required this.upiId,
    required this.sessionLink,
  });

  final String name;
  final String phone;
  final String email;
  final String upiId;
  final String sessionLink;
}

Future<MasterContact> loadMasterContact(
  String listingId,
  Map<String, dynamic>? listing,
) async {
  Map<String, dynamic> privateData = const {};
  if (!listingId.startsWith('demo_')) {
    try {
      privateData =
          (await firestore.collection('listings_contact').doc(listingId).get())
              .data() ??
          const {};
    } catch (_) {}
  }
  var name = (privateData['masterName'] ?? listing?['creatorName'] ?? 'Master')
      .toString();
  var phone = (privateData['masterPhone'] ?? privateData['contactNumber'] ?? '')
      .toString();
  var email = (privateData['masterEmail'] ?? '').toString();
  var upi =
      (privateData['upiId'] ?? listing?['upi_id'] ?? listing?['upiId'] ?? '')
          .toString();
  final session = (privateData['sessionLink'] ?? '').toString();
  final masterId = (listing?['creatorId'] ?? '').toString();
  if (masterId.isNotEmpty && !masterId.startsWith('demo_')) {
    try {
      final profile = await firestore
          .collection('profiles')
          .doc(masterId)
          .get();
      final data = profile.data() ?? const {};
      if (name.trim().isEmpty || name == 'Master') {
        name = (data['name'] ?? name).toString();
      }
      if (phone.trim().isEmpty) phone = (data['phoneNumber'] ?? '').toString();
      if (email.trim().isEmpty) email = (data['email'] ?? '').toString();
      if (upi.trim().isEmpty) upi = (data['upiId'] ?? '').toString();
    } catch (_) {}
  }
  if (email.trim().isEmpty) {
    email = (listing?['creatorEmail'] ?? '').toString();
  }
  return MasterContact(
    name: name.trim().isEmpty ? 'Master' : name.trim(),
    phone: phone.trim(),
    email: email.trim(),
    upiId: upi.trim(),
    sessionLink: session.trim(),
  );
}

Future<void> showClassInterestSheet({
  required BuildContext context,
  required String listingId,
  required String title,
  required Map<String, dynamic>? listing,
  required bool joining,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _InterestSheet(
      listingId: listingId,
      title: title,
      listing: listing,
      joining: joining,
    ),
  );
}

class _InterestSheet extends StatefulWidget {
  const _InterestSheet({
    required this.listingId,
    required this.title,
    required this.listing,
    required this.joining,
  });

  final String listingId;
  final String title;
  final Map<String, dynamic>? listing;
  final bool joining;

  @override
  State<_InterestSheet> createState() => _InterestSheetState();
}

class _InterestSheetState extends State<_InterestSheet> {
  final contact = TextEditingController();
  bool joining = true;
  bool saving = false;
  bool loadingContact = false;
  String? error;
  MasterContact? master;

  @override
  void initState() {
    super.initState();
    joining = widget.joining;
    if (!joining) {
      _loadContact();
    } else {
      _prefill();
    }
  }

  @override
  void dispose() {
    contact.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final data = (await firestore.collection('profiles').doc(user.uid).get())
          .data();
      final phone = (data?['phoneNumber'] ?? '').toString();
      if (mounted && phone.isNotEmpty && contact.text.isEmpty) {
        contact.text = phone;
      }
    } catch (_) {}
  }

  Future<void> _loadContact() async {
    setState(() {
      loadingContact = true;
      error = null;
    });
    final loaded = await loadMasterContact(widget.listingId, widget.listing);
    if (!mounted) return;
    setState(() {
      master = loaded;
      loadingContact = false;
    });
  }

  Future<void> join() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final contactValue = contact.text.trim();
    if (contactValue.isNotEmpty && contactValue.length < 5) {
      setState(
        () => error = 'Enter a valid contact number, or leave it empty.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      var mcId = '';
      var name = user.displayName ?? '';
      try {
        mcId = await ensureMemberId(user);
      } catch (_) {}
      try {
        final data =
            (await firestore.collection('profiles').doc(user.uid).get()).data();
        final storedName = (data?['name'] ?? '').toString().trim();
        if (storedName.isNotEmpty) name = storedName;
        final storedMc = (data?['mcId'] ?? '').toString().trim();
        if (mcId.isEmpty) mcId = storedMc;
      } catch (_) {}
      await firestore
          .collection('listings')
          .doc(widget.listingId)
          .collection('interests')
          .doc(user.uid)
          .set({
            'listingId': widget.listingId,
            'listingTitle': widget.title,
            'userId': user.uid,
            'userName': name,
            'userEmail': user.email ?? '',
            if (mcId.isNotEmpty) 'mcId': mcId,
            if (contactValue.isNotEmpty) 'contactNumber': contactValue,
            'status': 'interested',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'interestedAt': FieldValue.serverTimestamp(),
          });
      if (widget.listing != null) {
        await scheduleClassReminders(widget.listing!);
      }
      if (!mounted) return;
      setState(() => joining = false);
      await _loadContact();
    } on FirebaseException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not record interest: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final publicName = (widget.listing?['creatorName'] ?? 'the master')
        .toString();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Contact Master before making payment',
                style: text.titleMedium?.copyWith(
                  color: colors.onAccentSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.title, style: text.titleLarge),
            const SizedBox(height: 6),
            Text(
              joining
                  ? 'Join $publicName. Your name, MC ID, and contact are shared with the master.'
                  : 'These details are for you and the master.',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
            if (joining) ...[
              const SizedBox(height: 14),
              TextField(
                controller: contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Your WhatsApp / contact number (optional)',
                  helperText: 'Shared only with the class master.',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: saving ? null : join,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_border),
                label: const Text('Interested / Join'),
              ),
            ] else ...[
              const SizedBox(height: 14),
              if (loadingContact)
                const LinearProgressIndicator()
              else if (master != null)
                _ContactCard(contact: master!),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  error!,
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final MasterContact contact;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MASTER',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(letterSpacing: 1.1, color: colors.muted),
          ),
          const SizedBox(height: 8),
          Text(contact.name, style: Theme.of(context).textTheme.titleMedium),
          if (contact.phone.isNotEmpty)
            _CopyLine(label: 'Phone', value: contact.phone),
          if (contact.email.isNotEmpty)
            _CopyLine(label: 'Email', value: contact.email),
          if (contact.phone.isEmpty && contact.email.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This master has not added a phone or email yet.',
                style: TextStyle(color: colors.muted),
              ),
            ),
          if (contact.sessionLink.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(contact.sessionLink),
            ),
          UpiIdCard(
            upiId: contact.upiId,
            name: contact.name,
            heading: 'MASTER UPI',
          ),
          if (contact.upiId.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No UPI ID yet. Contact the master before paying.',
                style: TextStyle(color: colors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: SelectableText('$label: $value')),
          IconButton(
            tooltip: 'Copy $label',
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}
