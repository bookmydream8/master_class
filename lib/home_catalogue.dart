import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'category_style.dart';
import 'firestore_database.dart';
import 'madhura_board.dart' as board;
import 'seed/bangalore_demo.dart';

/// Image-led class card used on Home rails and the Classes list.
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.data,
    required this.onTap,
    this.width,
    this.rank,
  });

  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final double? width;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final style = categoryStyleFor(data);
    final ink = style.ink;
    final tint = style.tint;
    final title = (data['title'] ?? 'Class').toString();
    final educator = (data['creatorName'] ?? '').toString();
    final rating = ratingOf(data);
    final enrolled = enrolledCount(data);
    final price = board.listingPrice(data);
    final categoryId = (data['category'] ?? '').toString();
    final categoryName = board.categoryIds.entries
        .where((entry) => entry.value == categoryId)
        .map((entry) => entry.key)
        .firstOrNull ?? categoryId;
    final fresh = postedToday(data) || postedYesterday(data);
    final live = isLiveClass(data);
    final imageUrl = (data['image_url'] ?? '').toString();

    final card = Material(
      color: colors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: width == null ? 176 : 138,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(url: imageUrl, tint: tint, icon: style.icon, ink: ink),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _Pill(label: categoryName, background: tint, foreground: ink),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _Pill(
                      label: price,
                      background: colors.card,
                      foreground: colors.ink,
                    ),
                  ),
                  if (rank != null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.card,
                        child: Text(
                          '$rank',
                          style: text.labelLarge?.copyWith(color: ink),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        if (live)
                          const _Pill(
                            label: 'LIVE',
                            background: Color(0xFFE11D48),
                            foreground: Colors.white,
                          ),
                        if (live && fresh) const SizedBox(width: 6),
                        if (fresh)
                          _Pill(
                            label: 'NEW',
                            background: const Color(0xFFF59E0B),
                            foreground: const Color(0xFF451A03),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: tint,
                        child: Text(
                          educator.isEmpty ? 'M' : educator.characters.first.toUpperCase(),
                          style: text.labelSmall?.copyWith(color: ink, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          educator.isEmpty ? 'Master Class' : educator,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: colors.ink),
                        ),
                      ),
                      if (rating != null) ...[
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                        Text(
                          rating.toStringAsFixed(1),
                          style: text.labelSmall?.copyWith(color: colors.ink),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    enrolled == 1 ? '1 learner joined' : '$enrolled learners joined',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: card,
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.url,
    required this.tint,
    required this.icon,
    required this.ink,
  });

  final String url;
  final Color tint;
  final IconData icon;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: tint,
      child: Center(child: Icon(icon, color: ink, size: 36)),
    );
    if (url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(color: tint),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.onOpen});

  final void Function(String format, {String? focusCategory}) onOpen;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final controller = PageController(viewportFraction: 0.88);
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = [
      _Banner(
        kicker: 'THIS WEEK',
        title: 'Music, from first note\nto open mic',
        style: categoryStyleForId('music'),
        onTap: () => widget.onOpen('online', focusCategory: 'Music'),
      ),
      _Banner(
        kicker: 'NEAR YOU',
        title: 'Yoga and calm\nin Bangalore',
        style: categoryStyleForId('yoga'),
        onTap: () => widget.onOpen('physical', focusCategory: 'Yoga'),
      ),
      _Banner(
        kicker: 'SHOW UP',
        title: 'Ten competitions\nto enter',
        style: categoryStyleForId('sports'),
        onTap: () => widget.onOpen('competition'),
      ),
    ];
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: (value) => setState(() => page = value),
            itemBuilder: (context, index) {
              final banner = banners[index];
              final colors = banner.style.gradient;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: banner.onTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.kicker,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              banner.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const Spacer(),
                            const Row(
                              children: [
                                Text(
                                  'See classes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < banners.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: page == index ? 18 : 6,
                decoration: BoxDecoration(
                  color: page == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Banner {
  const _Banner({
    required this.kicker,
    required this.title,
    required this.style,
    required this.onTap,
  });

  final String kicker;
  final String title;
  final CategoryStyle style;
  final VoidCallback onTap;
}

class HomeCategoryRail extends StatelessWidget {
  const HomeCategoryRail({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final names = board.categories.keys.toList();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = names[index];
          final id = board.categoryIds[name] ?? '';
          final style = categoryStyleForId(id);
          final ink = style.ink;
          return Material(
            color: style.tint,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => onOpen(name),
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 92,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(style.icon, color: ink),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeCatalogue extends StatelessWidget {
  const HomeCatalogue({
    super.key,
    required this.onOpen,
    required this.onSeeAll,
  });

  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('listings')
          .orderBy('updatedAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (context, snapshot) {
        final live = (snapshot.data?.docs ?? [])
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        final source = catalogueOrDemo(live);
        final fresh = source.where(postedThisMonth).toList()
          ..sort((a, b) {
            final ad = postedAt(a) ?? DateTime(2000);
            final bd = postedAt(b) ?? DateTime(2000);
            return bd.compareTo(ad);
          });
        final top = [...source]..sort(
          (a, b) => enrolledCount(b).compareTo(enrolledCount(a)),
        );
        final leaders = top.take(10).toList();
        final learners = learnerCount(source);
        final masters = masterCount(source);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatStrip(learners: learners, masters: masters),
            const SizedBox(height: 22),
            AppSectionHeader(
              title: 'New this month',
              subtitle: 'Posted in ${DateTime.now().month == 11 ? 'November' : 'the last few weeks'}',
              action: 'See all',
              onAction: onSeeAll,
            ),
            const SizedBox(height: 12),
            _Rail(items: fresh.take(12).toList(), onOpen: onOpen),
            const SizedBox(height: 22),
            AppSectionHeader(
              title: 'Top 10 most joined',
              subtitle: 'Ranked by learners who joined',
              action: 'See all',
              onAction: onSeeAll,
            ),
            const SizedBox(height: 12),
            _Rail(items: leaders, onOpen: onOpen, ranked: true),
          ],
        );
      },
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.learners, required this.masters});

  final int learners;
  final int masters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Learners',
            value: '$learners',
            icon: Icons.groups_rounded,
            style: categoryStyleForId('language'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Masters',
            value: '$masters',
            icon: Icons.school_rounded,
            style: categoryStyleForId('arts'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.style,
  });

  final String label;
  final String value;
  final IconData icon;
  final CategoryStyle style;

  @override
  Widget build(BuildContext context) {
    final ink = style.ink;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: ink),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.items,
    required this.onOpen,
    this.ranked = false,
  });

  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Nothing new in this list yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppPalette.of(context).muted,
        ),
      );
    }
    return SizedBox(
      height: 292,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final data = items[index];
          return CourseCard(
            data: data,
            width: 236,
            rank: ranked ? index + 1 : null,
            onTap: () => onOpen(data),
          );
        },
      ),
    );
  }
}

class FreshPostsSheet extends StatelessWidget {
  const FreshPostsSheet({super.key, required this.controller, required this.onOpen});

  final ScrollController controller;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('listings').limit(40).snapshots(),
      builder: (context, snapshot) {
        final live = (snapshot.data?.docs ?? [])
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        final source = catalogueOrDemo(live);
        final today = source.where(postedToday).toList();
        final yesterday = source.where(postedYesterday).toList();
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Just posted', style: text.titleLarge),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Today'),
                  Tab(text: 'Yesterday'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _FreshList(items: today, controller: controller, onOpen: onOpen, empty: 'Nothing new today yet.'),
                    _FreshList(items: yesterday, controller: null, onOpen: onOpen, empty: 'Nothing was posted yesterday.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FreshList extends StatelessWidget {
  const _FreshList({
    required this.items,
    required this.controller,
    required this.onOpen,
    required this.empty,
  });

  final List<Map<String, dynamic>> items;
  final ScrollController? controller;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          empty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppPalette.of(context).muted,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = items[index];
        return CourseCard(data: data, onTap: () => onOpen(data));
      },
    );
  }
}
