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
  tint: Color(0xFFD5E6E8),
  ink: Color(0xFF0E4A52),
  icon: Icons.auto_stories_outlined,
  gradient: [Color(0xFFD5E6E8), Color(0xFFC3D9DC)],
);

/// Tints and gradients are about 16–24% of each category colour on white.
/// [ink] stays dark enough for text and icons on those surfaces.
const categoryStyles = <String, CategoryStyle>{
  'music': CategoryStyle(
    tint: Color(0xFFE4D6FB),
    ink: Color(0xFF5B21B6),
    icon: Icons.music_note_rounded,
    gradient: [Color(0xFFE4D6FB), Color(0xFFD4C2F6)],
  ),
  'language': CategoryStyle(
    tint: Color(0xFFD3ECF8),
    ink: Color(0xFF075985),
    icon: Icons.translate_rounded,
    gradient: [Color(0xFFD3ECF8), Color(0xFFBFE2F4)],
  ),
  'foreign_languages': CategoryStyle(
    tint: Color(0xFFDCDCFB),
    ink: Color(0xFF3730A3),
    icon: Icons.public_rounded,
    gradient: [Color(0xFFDCDCFB), Color(0xFFCBC8F8)],
  ),
  'yoga': CategoryStyle(
    tint: Color(0xFFD3F0E4),
    ink: Color(0xFF166534),
    icon: Icons.self_improvement_rounded,
    gradient: [Color(0xFFD3F0E4), Color(0xFFBDE6D2)],
  ),
  'meditation': CategoryStyle(
    tint: Color(0xFFD4EEEE),
    ink: Color(0xFF115E59),
    icon: Icons.spa_rounded,
    gradient: [Color(0xFFD4EEEE), Color(0xFFC0E4E3)],
  ),
  'bhagavat_geeta': CategoryStyle(
    tint: Color(0xFFF8E6CC),
    ink: Color(0xFF92400E),
    icon: Icons.menu_book_rounded,
    gradient: [Color(0xFFF8E6CC), Color(0xFFF4D7B0)],
  ),
  'workshop': CategoryStyle(
    tint: Color(0xFFFCE0D4),
    ink: Color(0xFF9A3412),
    icon: Icons.handyman_rounded,
    gradient: [Color(0xFFFCE0D4), Color(0xFFF9CDBA)],
  ),
  'arts': CategoryStyle(
    tint: Color(0xFFF8D6E6),
    ink: Color(0xFF9D174D),
    icon: Icons.palette_rounded,
    gradient: [Color(0xFFF8D6E6), Color(0xFFF4C2D8)],
  ),
  'adult': CategoryStyle(
    tint: Color(0xFFEAD6F8),
    ink: Color(0xFF6B21A8),
    icon: Icons.psychology_alt_rounded,
    gradient: [Color(0xFFEAD6F8), Color(0xFFDDC0F4)],
  ),
  'sports': CategoryStyle(
    tint: Color(0xFFF9D3DC),
    ink: Color(0xFF9F1239),
    icon: Icons.sports_soccer_rounded,
    gradient: [Color(0xFFF9D3DC), Color(0xFFF5BCC9)],
  ),
  'curriculum': CategoryStyle(
    tint: Color(0xFFD6E2FC),
    ink: Color(0xFF1E40AF),
    icon: Icons.school_rounded,
    gradient: [Color(0xFFD6E2FC), Color(0xFFC2D4FA)],
  ),
  'trading': CategoryStyle(
    tint: Color(0xFFD2EDE4),
    ink: Color(0xFF065F46),
    icon: Icons.show_chart_rounded,
    gradient: [Color(0xFFD2EDE4), Color(0xFFBBE3D6)],
  ),
  'ai_tools': CategoryStyle(
    tint: Color(0xFFE6D9FC),
    ink: Color(0xFF5B21B6),
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFFE6D9FC), Color(0xFFD5C4F8)],
  ),
};

CategoryStyle categoryStyleForId(String? id) =>
    categoryStyles[id ?? ''] ?? _fallback;

CategoryStyle categoryStyleFor(Map<String, dynamic> data) =>
    categoryStyleForId((data['category'] ?? '').toString());
