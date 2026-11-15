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
  tint: Color(0xFFE5F4F5),
  ink: Color(0xFF0E4A52),
  icon: Icons.auto_stories_outlined,
  gradient: [Color(0xFF1A6B73), Color(0xFF3D8B92)],
);

const categoryStyles = <String, CategoryStyle>{
  'music': CategoryStyle(
    tint: Color(0xFFEDE4FF),
    ink: Color(0xFF5B21B6),
    icon: Icons.music_note_rounded,
    gradient: [Color(0xFF6D28D9), Color(0xFFDB2777)],
  ),
  'language': CategoryStyle(
    tint: Color(0xFFE0F2FE),
    ink: Color(0xFF075985),
    icon: Icons.translate_rounded,
    gradient: [Color(0xFF0284C7), Color(0xFF0F766E)],
  ),
  'foreign_languages': CategoryStyle(
    tint: Color(0xFFE0E7FF),
    ink: Color(0xFF3730A3),
    icon: Icons.public_rounded,
    gradient: [Color(0xFF4F46E5), Color(0xFF2563EB)],
  ),
  'yoga': CategoryStyle(
    tint: Color(0xFFDCFCE7),
    ink: Color(0xFF166534),
    icon: Icons.self_improvement_rounded,
    gradient: [Color(0xFF059669), Color(0xFF65A30D)],
  ),
  'meditation': CategoryStyle(
    tint: Color(0xFFCCFBF1),
    ink: Color(0xFF115E59),
    icon: Icons.spa_rounded,
    gradient: [Color(0xFF0F766E), Color(0xFF0891B2)],
  ),
  'bhagavat_geeta': CategoryStyle(
    tint: Color(0xFFFEF3C7),
    ink: Color(0xFF92400E),
    icon: Icons.menu_book_rounded,
    gradient: [Color(0xFFD97706), Color(0xFFB45309)],
  ),
  'workshop': CategoryStyle(
    tint: Color(0xFFFFEDD5),
    ink: Color(0xFF9A3412),
    icon: Icons.handyman_rounded,
    gradient: [Color(0xFFEA580C), Color(0xFFDB2777)],
  ),
  'arts': CategoryStyle(
    tint: Color(0xFFFCE7F3),
    ink: Color(0xFF9D174D),
    icon: Icons.palette_rounded,
    gradient: [Color(0xFFDB2777), Color(0xFF7C3AED)],
  ),
  'adult': CategoryStyle(
    tint: Color(0xFFF3E8FF),
    ink: Color(0xFF6B21A8),
    icon: Icons.psychology_alt_rounded,
    gradient: [Color(0xFF7E22CE), Color(0xFF2563EB)],
  ),
  'sports': CategoryStyle(
    tint: Color(0xFFFFE4E6),
    ink: Color(0xFF9F1239),
    icon: Icons.sports_soccer_rounded,
    gradient: [Color(0xFFE11D48), Color(0xFFEA580C)],
  ),
  'curriculum': CategoryStyle(
    tint: Color(0xFFDBEAFE),
    ink: Color(0xFF1E40AF),
    icon: Icons.school_rounded,
    gradient: [Color(0xFF2563EB), Color(0xFF0891B2)],
  ),
  'trading': CategoryStyle(
    tint: Color(0xFFD1FAE5),
    ink: Color(0xFF065F46),
    icon: Icons.show_chart_rounded,
    gradient: [Color(0xFF047857), Color(0xFF0F766E)],
  ),
  'ai_tools': CategoryStyle(
    tint: Color(0xFFEDE9FE),
    ink: Color(0xFF5B21B6),
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFF7C3AED), Color(0xFF2563EB)],
  ),
};

CategoryStyle categoryStyleForId(String? id) =>
    categoryStyles[id ?? ''] ?? _fallback;

CategoryStyle categoryStyleFor(Map<String, dynamic> data) =>
    categoryStyleForId((data['category'] ?? '').toString());
