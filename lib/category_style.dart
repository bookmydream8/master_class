import 'package:flutter/material.dart';

/// Soft, distinct colour for each listing category.
///
/// Tints stay light enough for dark text. The app is light-only.
class CategoryStyle {
  const CategoryStyle({
    required this.tint,
    required this.ink,
    required this.icon,
    required this.gradient,
  });

  final Color tint;
  final Color ink;
  final IconData icon;
  final List<Color> gradient;
}

const _fallback = CategoryStyle(
  tint: Color(0xFFE8F0F1),
  ink: Color(0xFF0E4A52),
  icon: Icons.auto_stories_outlined,
  gradient: [Color(0xFFE8F0F1), Color(0xFFDAE7E9)],
);

/// Tints and gradients are about 8–16% of each category colour on white.
/// [ink] stays dark enough for text and icons on those surfaces.
const categoryStyles = <String, CategoryStyle>{
  'music': CategoryStyle(
    tint: Color(0xFFF0EAFB),
    ink: Color(0xFF5B21B6),
    icon: Icons.music_note_rounded,
    gradient: [Color(0xFFF0EAFB), Color(0xFFE8DDF7)],
  ),
  'language': CategoryStyle(
    tint: Color(0xFFE6F3F9),
    ink: Color(0xFF075985),
    icon: Icons.translate_rounded,
    gradient: [Color(0xFFE6F3F9), Color(0xFFD7EDF7)],
  ),
  'foreign_languages': CategoryStyle(
    tint: Color(0xFFEDEDFD),
    ink: Color(0xFF3730A3),
    icon: Icons.public_rounded,
    gradient: [Color(0xFFEDEDFD), Color(0xFFE3E1FC)],
  ),
  'yoga': CategoryStyle(
    tint: Color(0xFFE6F5F0),
    ink: Color(0xFF166534),
    icon: Icons.self_improvement_rounded,
    gradient: [Color(0xFFE6F5F0), Color(0xFFD7EEE7)],
  ),
  'meditation': CategoryStyle(
    tint: Color(0xFFE7F1F1),
    ink: Color(0xFF115E59),
    icon: Icons.spa_rounded,
    gradient: [Color(0xFFE7F1F1), Color(0xFFD9E9E8)],
  ),
  'bhagavat_geeta': CategoryStyle(
    tint: Color(0xFFFBF1E6),
    ink: Color(0xFF92400E),
    icon: Icons.menu_book_rounded,
    gradient: [Color(0xFFFBF1E6), Color(0xFFF9E9D7)],
  ),
  'workshop': CategoryStyle(
    tint: Color(0xFFFDEEE7),
    ink: Color(0xFF9A3412),
    icon: Icons.handyman_rounded,
    gradient: [Color(0xFFFDEEE7), Color(0xFFFCE4D8)],
  ),
  'arts': CategoryStyle(
    tint: Color(0xFFFBEAF2),
    ink: Color(0xFF9D174D),
    icon: Icons.palette_rounded,
    gradient: [Color(0xFFFBEAF2), Color(0xFFF9DCE9)],
  ),
  'adult': CategoryStyle(
    tint: Color(0xFFF2E9FA),
    ink: Color(0xFF6B21A8),
    icon: Icons.psychology_alt_rounded,
    gradient: [Color(0xFFF2E9FA), Color(0xFFEADCF7)],
  ),
  'sports': CategoryStyle(
    tint: Color(0xFFFCE8EC),
    ink: Color(0xFF9F1239),
    icon: Icons.sports_soccer_rounded,
    gradient: [Color(0xFFFCE8EC), Color(0xFFFADBE2)],
  ),
  'curriculum': CategoryStyle(
    tint: Color(0xFFE9EFFD),
    ink: Color(0xFF1E40AF),
    icon: Icons.school_rounded,
    gradient: [Color(0xFFE9EFFD), Color(0xFFDCE6FC)],
  ),
  'trading': CategoryStyle(
    tint: Color(0xFFE6F2EE),
    ink: Color(0xFF065F46),
    icon: Icons.show_chart_rounded,
    gradient: [Color(0xFFE6F2EE), Color(0xFFD7E9E5)],
  ),
  'ai_tools': CategoryStyle(
    tint: Color(0xFFF2EBFD),
    ink: Color(0xFF5B21B6),
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFFF2EBFD), Color(0xFFEADFFC)],
  ),
};

CategoryStyle categoryStyleForId(String? id) =>
    categoryStyles[id ?? ''] ?? _fallback;

CategoryStyle categoryStyleFor(Map<String, dynamic> data) =>
    categoryStyleForId((data['category'] ?? '').toString());
