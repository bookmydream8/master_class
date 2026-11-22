import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'category_style.dart';
import 'home_illustrations.dart';
import 'seed/bangalore_demo.dart';

class _LanguageCard {
  const _LanguageCard(this.english, this.native, this.styleId);
  final String english;
  final String native;
  final String styleId;
}

const _languageCards = <_LanguageCard>[
  _LanguageCard('English', 'English', 'language'),
  _LanguageCard('Hindi', 'हिन्दी', 'language'),
  _LanguageCard('Kannada', 'ಕನ್ನಡ', 'language'),
  _LanguageCard('Tamil', 'தமிழ்', 'language'),
  _LanguageCard('Telugu', 'తెలుగు', 'language'),
  _LanguageCard('Malayalam', 'മലയാളം', 'language'),
  _LanguageCard('French', 'Français', 'foreign_languages'),
  _LanguageCard('German', 'Deutsch', 'foreign_languages'),
  _LanguageCard('Spanish', 'Español', 'foreign_languages'),
  _LanguageCard('Japanese', '日本語', 'foreign_languages'),
  _LanguageCard('Korean', '한국어', 'foreign_languages'),
];

/// Compact language rail. Light cards with a thin border, not gradient tiles.
class LanguageSection extends StatelessWidget {
  const LanguageSection({
    super.key,
    required this.onOpen,
    required this.listings,
  });

  final ValueChanged<String> onOpen;
  final List<Map<String, dynamic>> listings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const HomeIllustration('languages', size: 36),
            const SizedBox(width: 8),
            Text('Learn to speak a language', style: text.titleLarge),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'The class people ask for most',
          style: text.bodySmall?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _languageCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final card = _languageCards[index];
              final style = categoryStyleForId(card.styleId);
              final count = listings
                  .where((item) => listingMatchesLanguage(item, card.english))
                  .length;
              return Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: style.ink.withValues(alpha: 0.38)),
                ),
                child: InkWell(
                  onTap: () => onOpen(card.english),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    width: 176,
                    decoration: BoxDecoration(
                      color: style.tint,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Row(
                        children: [
                          HomeIllustration(
                            languageIllustration(card.english),
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  card.native,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall?.copyWith(
                                    color: style.ink,
                                  ),
                                ),
                                Text(
                                  card.english == card.native
                                      ? '$count ${count == 1 ? 'class' : 'classes'}'
                                      : card.english,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    color: colors.muted,
                                  ),
                                ),
                                Text(
                                  'Beginner',
                                  style: text.labelSmall?.copyWith(
                                    color: style.ink,
                                  ),
                                ),
                              ],
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
