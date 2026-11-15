import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'category_style.dart';
import 'seed/bangalore_demo.dart';

/// Prominent Home rail for the languages people ask to speak.
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key, required this.onOpen, required this.listings});

  final ValueChanged<String> onOpen;
  final List<Map<String, dynamic>> listings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AppPalette.of(context);
    final styles = [
      categoryStyleForId('language'),
      categoryStyleForId('foreign_languages'),
      categoryStyleForId('yoga'),
      categoryStyleForId('arts'),
      categoryStyleForId('music'),
      categoryStyleForId('workshop'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Learn to speak a language', style: text.titleLarge),
        const SizedBox(height: 4),
        Text(
          'The class people ask for most',
          style: text.bodySmall?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: speakLanguages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final language = speakLanguages[index];
              final style = styles[index % styles.length];
              final count = listings
                  .where((item) => listingMatchesLanguage(item, language))
                  .length;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpen(language),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    width: 132,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: style.gradient,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
                          const Spacer(),
                          Text(
                            language,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(color: Colors.white),
                          ),
                          Text(
                            count == 1 ? '1 class' : '$count classes',
                            style: text.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
