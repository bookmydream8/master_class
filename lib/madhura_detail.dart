import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'madhura_board.dart' as board;

void showMadhuraDetails(BuildContext context, Map<String, dynamic> data) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => MadhuraDetailPage(data: data)));
}

class MadhuraDetailPage extends StatelessWidget {
  const MadhuraDetailPage({super.key, required this.data});
  final Map<String, dynamic> data;

  Future<void> copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openInMaps(BuildContext context, String link) async {
    final location = Uri.tryParse(link);
    if (location == null || !location.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This class has an invalid Maps link.')),
        );
      }
      return;
    }
    final opened = await launchUrl(
      location,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Maps location.')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final format = board.listingFormat(data);
    final image = (data['image_url'] ?? '').toString();
    final imageBase64 = (data['image_base64'] ?? '').toString();
    final title = (data['title'] ?? 'Class details').toString();
    final category =
        board.categories.keys
            .where((key) => board.categoryIds[key] == data['category'])
            .firstOrNull ??
        'Class';
    final start = (data['start_date'] ?? '').toString();
    final end = (data['end_date'] ?? '').toString();
    final dates = start.isEmpty
        ? 'Dates to be announced'
        : end.isNotEmpty && end != start
        ? '$start – $end'
        : start;
    final place = format == 'online'
        ? 'Online'
        : (data['city'] ?? 'Bangalore').toString();
    final map = (data['map_location'] ?? '').toString();
    return Scaffold(
      backgroundColor: board.cream,
      appBar: AppBar(
        backgroundColor: board.paper,
        foregroundColor: board.ink,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'serif', fontSize: 17),
            ),
            Text(
              board.formats[format] ?? 'Class',
              style: const TextStyle(fontSize: 10, color: board.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy listing title',
            onPressed: () => copy(context, title, 'Listing title copied'),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 245,
            width: double.infinity,
            child: imageBase64.isNotEmpty
                ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                : image.isEmpty
                ? Container(
                    color: const Color(0xFFEEDFCB),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: board.clay,
                      size: 74,
                    ),
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFFEEDFCB),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: board.clay,
                        size: 74,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 17, 16, 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${board.formats[format] ?? 'Class'} · $category${data['subcategory'] == null ? '' : ' · ${data['subcategory']}'}'
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: board.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 27,
                    height: 1.13,
                    fontWeight: FontWeight.w700,
                    color: board.ink,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _Stat('PRICE', board.listingPrice(data))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _Stat(
                        format == 'competition' ? 'WINDOW' : 'DATES',
                        dates,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: _Stat('WHERE', place)),
                  ],
                ),
                const SizedBox(height: 15),
                if ((data['description'] ?? '').toString().isNotEmpty)
                  _Section(
                    format == 'competition'
                        ? 'ABOUT THIS COMPETITION'
                        : 'ABOUT THIS CLASS',
                    data['description'].toString(),
                  ),
                if ((data['about_master'] ?? '').toString().isNotEmpty)
                  _Section('ABOUT THE MASTER', data['about_master'].toString()),
                if (map.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(bottom: 13),
                    decoration: BoxDecoration(
                      color: board.paper,
                      border: Border.all(color: board.border),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VENUE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: board.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        OutlinedButton.icon(
                          onPressed: () => openInMaps(context, map),
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Open in Maps'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: board.paper,
      border: Border.all(color: board.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: board.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: board.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    margin: const EdgeInsets.only(bottom: 13),
    decoration: BoxDecoration(
      color: board.paper,
      border: Border.all(color: board.border),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: board.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.5, color: board.ink),
        ),
      ],
    ),
  );
}
