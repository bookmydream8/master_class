/// FCM topic for a city. Keep this slug in step with `citySlug` in
/// `functions/index.js`.
String? cityTopicName(String? city) {
  final slug = (city ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.isEmpty) return null;
  return 'city_$slug';
}
