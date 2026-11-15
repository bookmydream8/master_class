import 'package:flutter/material.dart';

/// Soft, distinct colour for each listing category.
///
/// Tints stay light enough for dark text. Dark mode uses deeper wells with
/// light icon ink so the same category is recognisable in both themes.
class CategoryStyle {
  const CategoryStyle({
    required this.tint,
    required this.ink,
    required this.darkTint,
    required this.darkInk,
    required this.icon,
    required this.gradient,
    required this.darkGradient,
  });

  final Color tint;
  final Color ink;
  final Color darkTint;
  final Color darkInk;
  final IconData icon;
  final List<Color> gradient;
  final List<Color> darkGradient;

  Color well(Brightness brightness) =>
      brightness == Brightness.dark ? darkTint : tint;

  Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? darkInk : ink;

  List<Color> wash(Brightness brightness) =>
      brightness == Brightness.dark ? darkGradient : gradient;
}

const _fallback = CategoryStyle(
  tint: Color(0xFFE5F4F5),
  ink: Color(0xFF0E4A52),
  darkTint: Color(0xFF1E3A3E),
  darkInk: Color(0xFFD7F3F4),
  icon: Icons.auto_stories_outlined,
  gradient: [Color(0xFF1A6B73), Color(0xFF3D8B92)],
  darkGradient: [Color(0xFF134E54), Color(0xFF1A6B73)],
);

const categoryStyles = <String, CategoryStyle>{
  'music': CategoryStyle(
    tint: Color(0xFFEDE4FF),
    ink: Color(0xFF5B21B6),
    darkTint: Color(0xFF2E2150),
    darkInk: Color(0xFFE9D5FF),
    icon: Icons.music_note_rounded,
    gradient: [Color(0xFF6D28D9), Color(0xFFDB2777)],
    darkGradient: [Color(0xFF4C1D95), Color(0xFF9D174D)],
  ),
  'language': CategoryStyle(
    tint: Color(0xFFE0F2FE),
    ink: Color(0xFF075985),
    darkTint: Color(0xFF163044),
    darkInk: Color(0xFFBAE6FD),
    icon: Icons.translate_rounded,
    gradient: [Color(0xFF0284C7), Color(0xFF0F766E)],
    darkGradient: [Color(0xFF075985), Color(0xFF115E59)],
  ),
  'foreign_languages': CategoryStyle(
    tint: Color(0xFFE0E7FF),
    ink: Color(0xFF3730A3),
    darkTint: Color(0xFF242448),
    darkInk: Color(0xFFC7D2FE),
    icon: Icons.public_rounded,
    gradient: [Color(0xFF4F46E5), Color(0xFF2563EB)],
    darkGradient: [Color(0xFF312E81), Color(0xFF1E3A8A)],
  ),
  'yoga': CategoryStyle(
    tint: Color(0xFFDCFCE7),
    ink: Color(0xFF166534),
    darkTint: Color(0xFF163226),
    darkInk: Color(0xFFBBF7D0),
    icon: Icons.self_improvement_rounded,
    gradient: [Color(0xFF059669), Color(0xFF65A30D)],
    darkGradient: [Color(0xFF065F46), Color(0xFF3F6212)],
  ),
  'meditation': CategoryStyle(
    tint: Color(0xFFCCFBF1),
    ink: Color(0xFF115E59),
    darkTint: Color(0xFF143332),
    darkInk: Color(0xFF99F6E4),
    icon: Icons.spa_rounded,
    gradient: [Color(0xFF0F766E), Color(0xFF0891B2)],
    darkGradient: [Color(0xFF115E59), Color(0xFF155E75)],
  ),
  'bhagavat_geeta': CategoryStyle(
    tint: Color(0xFFFEF3C7),
    ink: Color(0xFF92400E),
    darkTint: Color(0xFF3A2E16),
    darkInk: Color(0xFFFDE68A),
    icon: Icons.menu_book_rounded,
    gradient: [Color(0xFFD97706), Color(0xFFB45309)],
    darkGradient: [Color(0xFF92400E), Color(0xFF78350F)],
  ),
  'workshop': CategoryStyle(
    tint: Color(0xFFFFEDD5),
    ink: Color(0xFF9A3412),
    darkTint: Color(0xFF3A2418),
    darkInk: Color(0xFFFED7AA),
    icon: Icons.handyman_rounded,
    gradient: [Color(0xFFEA580C), Color(0xFFDB2777)],
    darkGradient: [Color(0xFF9A3412), Color(0xFF9D174D)],
  ),
  'arts': CategoryStyle(
    tint: Color(0xFFFCE7F3),
    ink: Color(0xFF9D174D),
    darkTint: Color(0xFF3A1C2C),
    darkInk: Color(0xFFFBCFE8),
    icon: Icons.palette_rounded,
    gradient: [Color(0xFFDB2777), Color(0xFF7C3AED)],
    darkGradient: [Color(0xFF9D174D), Color(0xFF5B21B6)],
  ),
  'adult': CategoryStyle(
    tint: Color(0xFFF3E8FF),
    ink: Color(0xFF6B21A8),
    darkTint: Color(0xFF2C2140),
    darkInk: Color(0xFFE9D5FF),
    icon: Icons.psychology_alt_rounded,
    gradient: [Color(0xFF7E22CE), Color(0xFF2563EB)],
    darkGradient: [Color(0xFF581C87), Color(0xFF1E3A8A)],
  ),
  'sports': CategoryStyle(
    tint: Color(0xFFFFE4E6),
    ink: Color(0xFF9F1239),
    darkTint: Color(0xFF3A1C24),
    darkInk: Color(0xFFFECDD3),
    icon: Icons.sports_soccer_rounded,
    gradient: [Color(0xFFE11D48), Color(0xFFEA580C)],
    darkGradient: [Color(0xFF9F1239), Color(0xFF9A3412)],
  ),
  'curriculum': CategoryStyle(
    tint: Color(0xFFDBEAFE),
    ink: Color(0xFF1E40AF),
    darkTint: Color(0xFF1A2744),
    darkInk: Color(0xFFBFDBFE),
    icon: Icons.school_rounded,
    gradient: [Color(0xFF2563EB), Color(0xFF0891B2)],
    darkGradient: [Color(0xFF1E3A8A), Color(0xFF155E75)],
  ),
  'trading': CategoryStyle(
    tint: Color(0xFFD1FAE5),
    ink: Color(0xFF065F46),
    darkTint: Color(0xFF143028),
    darkInk: Color(0xFFA7F3D0),
    icon: Icons.show_chart_rounded,
    gradient: [Color(0xFF047857), Color(0xFF0F766E)],
    darkGradient: [Color(0xFF064E3B), Color(0xFF115E59)],
  ),
  'ai_tools': CategoryStyle(
    tint: Color(0xFFEDE9FE),
    ink: Color(0xFF5B21B6),
    darkTint: Color(0xFF2A2148),
    darkInk: Color(0xFFDDD6FE),
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFF7C3AED), Color(0xFF2563EB)],
    darkGradient: [Color(0xFF4C1D95), Color(0xFF1E40AF)],
  ),
};

CategoryStyle categoryStyleForId(String? id) =>
    categoryStyles[id ?? ''] ?? _fallback;

CategoryStyle categoryStyleFor(Map<String, dynamic> data) =>
    categoryStyleForId((data['category'] ?? '').toString());
