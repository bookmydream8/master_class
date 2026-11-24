import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firestore_database.dart';
import 'member_id.dart';

const attendanceAwayMetres = 200;

/// Where the person was when they saved physical attendance.
class AttendancePlace {
  const AttendancePlace({
    required this.locationStatus,
    required this.address,
    required this.away,
    this.lat,
    this.lng,
    this.accuracy,
    this.distanceMeters,
  });

  final String locationStatus;
  final String address;
  final bool away;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final int? distanceMeters;

  Map<String, dynamic> toMap({
    required String markedByUid,
    required String mcId,
    required String date,
    String batchId = '',
  }) => {
    'markedByUid': markedByUid,
    'mcId': mcId,
    'date': date,
    if (batchId.isNotEmpty) 'batchId': batchId,
    'locationStatus': locationStatus,
    'address': address,
    'away': away,
    'markedAt': FieldValue.serverTimestamp(),
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (accuracy != null) 'accuracy': accuracy,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
  };
}

Future<AttendancePlace> captureAttendancePlace({
  double? placeLat,
  double? placeLng,
  String placeAddress = '',
}) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  final denied =
      permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever ||
      permission == LocationPermission.unableToDetermine;
  if (denied) {
    return const AttendancePlace(
      locationStatus: 'denied',
      address: 'Location denied',
      away: false,
    );
  }
  try {
    final position = await Geolocator.getCurrentPosition();
    var address = '';
    try {
      final marks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (marks.isNotEmpty) {
        final place = marks.first;
        address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
      }
    } catch (_) {}
    var targetLat = placeLat;
    var targetLng = placeLng;
    if ((targetLat == null || targetLng == null) && placeAddress.trim().isNotEmpty) {
      try {
        final found = await locationFromAddress(placeAddress);
        if (found.isNotEmpty) {
          targetLat = found.first.latitude;
          targetLng = found.first.longitude;
        }
      } catch (_) {}
    }
    int? distance;
    if (targetLat != null && targetLng != null) {
      distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      ).round();
    }
    return AttendancePlace(
      locationStatus: 'recorded',
      address: address.isEmpty ? 'Address unavailable' : address,
      away: distance != null && distance > attendanceAwayMetres,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      distanceMeters: distance,
    );
  } catch (_) {
    return const AttendancePlace(
      locationStatus: 'denied',
      address: 'Location denied',
      away: false,
    );
  }
}

Future<void> saveListingAttendancePlace({
  required String listingId,
  required String date,
  double? placeLat,
  double? placeLng,
  String placeAddress = '',
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final ref = firestore
      .collection('listings')
      .doc(listingId)
      .collection('attendancePlaces')
      .doc(date);
  if ((await ref.get()).exists) return;
  var mcId = '';
  try {
    mcId = await ensureMemberId(user);
  } catch (_) {}
  final place = await captureAttendancePlace(
    placeLat: placeLat,
    placeLng: placeLng,
    placeAddress: placeAddress,
  );
  await ref.set(place.toMap(markedByUid: user.uid, mcId: mcId, date: date));
}

Future<void> saveAcademyAttendancePlace({
  required String academyId,
  required String batchId,
  required String date,
  double? placeLat,
  double? placeLng,
  String placeAddress = '',
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final ref = firestore
      .collection('academies')
      .doc(academyId)
      .collection('attendancePlaces')
      .doc('${batchId}_$date');
  if ((await ref.get()).exists) return;
  var mcId = '';
  try {
    mcId = await ensureMemberId(user);
  } catch (_) {}
  final place = await captureAttendancePlace(
    placeLat: placeLat,
    placeLng: placeLng,
    placeAddress: placeAddress,
  );
  await ref.set(
    place.toMap(
      markedByUid: user.uid,
      mcId: mcId,
      date: date,
      batchId: batchId,
    ),
  );
}

const attendanceLocationNotice =
    'Your location is recorded when you mark attendance for a physical class.';

class AttendancePlaceCard extends StatelessWidget {
  const AttendancePlaceCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final denied = data['locationStatus'] == 'denied';
    final away = data['away'] == true;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final when = data['markedAt'];
    final stamp = when is Timestamp ? when.toDate().toLocal().toString() : (data['date'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((data['mcId'] ?? data['markedByUid'] ?? 'Teacher').toString()),
            Text(stamp),
            Text(denied ? 'Location denied' : (data['address'] ?? '').toString()),
            if (away)
              const Text(
                'Away from the class',
                style: TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700),
              ),
            if (!denied && lat != null && lng != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: FlutterMap(
                  options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.c2c.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on, color: Color(0xFF9F1239)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Open in Google Maps'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AcademyAttendancePlaces extends StatelessWidget {
  const AcademyAttendancePlaces({super.key, required this.academyId});

  final String academyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('academies')
          .doc(academyId)
          .collection('attendancePlaces')
          .limit(40)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No physical attendance locations yet.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final doc in docs) AttendancePlaceCard(data: doc.data()),
          ],
        );
      },
    );
  }
}
