import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'app_theme.dart';

class NearbyClassesPage extends StatefulWidget {
  const NearbyClassesPage({super.key, required this.listings, required this.onOpen});

  final List<Map<String, dynamic>> listings;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  State<NearbyClassesPage> createState() => _NearbyClassesPageState();
}

class _NearbyClassesPageState extends State<NearbyClassesPage> {
  LatLng? here;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => here = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get places => widget.listings.where((item) {
    final type = (item['listing_type'] ?? item['type'] ?? '').toString();
    final lat = item['lat'];
    final lng = item['lng'];
    return (type == 'offline_class' || type == 'event' || type == 'physical') &&
        lat is num &&
        lng is num;
  }).toList();

  String _distance(Map<String, dynamic> item) {
    final origin = here;
    if (origin == null) return '';
    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      (item['lat'] as num).toDouble(),
      (item['lng'] as num).toDouble(),
    );
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final center = here ?? const LatLng(12.9716, 77.5946);
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby classes')),
      body: Column(
        children: [
          SizedBox(
            height: 320,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.c2c.app',
                ),
                MarkerLayer(
                  markers: [
                    if (here != null)
                      Marker(
                        point: here!,
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.my_location, color: Color(0xFF1A6B73)),
                      ),
                    for (final item in places)
                      Marker(
                        point: LatLng(
                          (item['lat'] as num).toDouble(),
                          (item['lng'] as num).toDouble(),
                        ),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => widget.onOpen(item),
                          child: const Icon(Icons.place, color: Color(0xFFE11D48), size: 32),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = places[index];
                final away = _distance(item);
                return ListTile(
                  tileColor: AppPalette.of(context).card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text((item['title'] ?? 'Class').toString()),
                  subtitle: Text(
                    [
                      (item['area'] ?? item['city'] ?? '').toString(),
                      if (away.isNotEmpty) away,
                    ].join(' · '),
                  ),
                  onTap: () => widget.onOpen(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
