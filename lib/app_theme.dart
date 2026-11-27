import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A crisp, editorial learning-marketplace palette.
///
/// The app deliberately uses a warm paper canvas, ink-heavy type and one vivid
/// action colour. This keeps dense browse screens quiet while making booking
/// and publishing actions immediately scannable.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.onlineWell,
    required this.physicalWell,
    required this.competitionWell,
    required this.eventWell,
    required this.wellInk,
    required this.imageFallback,
    required this.shadow,
  });

  final Color canvas;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color onlineWell;
  final Color physicalWell;
  final Color competitionWell;
  final Color eventWell;
  final Color wellInk;
  final Color imageFallback;
  final Color shadow;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  static const light = AppPalette(
    canvas: Color(0xFFF8F7F4),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF151A2D),
    muted: Color(0xFF687083),
    line: Color(0xFFE7E7EC),
    accent: Color(0xFF5B36D6),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEEE9FF),
    onAccentSoft: Color(0xFF4526AA),
    onlineWell: Color(0xFFE9F1FF),
    physicalWell: Color(0xFFE7F6EF),
    competitionWell: Color(0xFFFFF1D5),
    eventWell: Color(0xFFFFE8ED),
    wellInk: Color(0xFF263252),
    imageFallback: Color(0xFFF0EFF7),
    shadow: Color(0x14151A2D),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? onlineWell,
    Color? physicalWell,
    Color? competitionWell,
    Color? eventWell,
    Color? wellInk,
    Color? imageFallback,
    Color? shadow,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      onlineWell: onlineWell ?? this.onlineWell,
      physicalWell: physicalWell ?? this.physicalWell,
      competitionWell: competitionWell ?? this.competitionWell,
      eventWell: eventWell ?? this.eventWell,
      wellInk: wellInk ?? this.wellInk,
      imageFallback: imageFallback ?? this.imageFallback,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      onlineWell: Color.lerp(onlineWell, other.onlineWell, t)!,
      physicalWell: Color.lerp(physicalWell, other.physicalWell, t)!,
      competitionWell: Color.lerp(competitionWell, other.competitionWell, t)!,
      eventWell: Color.lerp(eventWell, other.eventWell, t)!,
      wellInk: Color.lerp(wellInk, other.wellInk, t)!,
      imageFallback: Color.lerp(imageFallback, other.imageFallback, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

class AppTheme {
  static ThemeData light() => _build();

  static ThemeData _build() {
    const palette = AppPalette.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B36D6),
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentSoft,
      onPrimaryContainer: palette.onAccentSoft,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      secondaryContainer: palette.accentSoft,
      onSecondaryContainer: palette.onAccentSoft,
      surface: palette.canvas,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      outline: palette.line,
      outlineVariant: palette.line,
      surfaceTint: Colors.transparent,
      error: const Color(0xFFB42318),
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE4E2),
      onErrorContainer: const Color(0xFF7A271A),
    ).copyWith(
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.canvas,
      surfaceContainer: const Color(0xFFEEF3F3),
      surfaceContainerHigh: const Color(0xFFE6EEEE),
      surfaceContainerHighest: const Color(0xFFDCE6E6),
    );
    final seedText = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
    ).textTheme;
    final text = _textTheme(
      GoogleFonts.plusJakartaSansTextTheme(seedText),
      GoogleFonts.interTextTheme(seedText),
      palette.ink,
      palette.muted,
    );
    final radius = BorderRadius.circular(12);
    final outline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: palette.line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      dividerColor: palette.line,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.compact,
      extensions: [palette],
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.card,
        foregroundColor: palette.ink,
        elevation: 0,
        toolbarHeight: 60,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleMedium?.copyWith(color: palette.ink),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: text.titleLarge?.copyWith(color: palette.ink),
        contentTextStyle: text.bodyMedium?.copyWith(color: palette.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: palette.line,
        dragHandleSize: const Size(36, 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
        extendedTextStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: text.labelLarge,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 42),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: palette.line),
          foregroundColor: palette.ink,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: palette.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        hintStyle: text.bodyMedium?.copyWith(color: palette.muted),
        labelStyle: text.bodyMedium?.copyWith(color: palette.muted),
        helperStyle: text.bodySmall?.copyWith(color: palette.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: palette.accentSoft,
        disabledColor: palette.line,
        checkmarkColor: palette.onAccentSoft,
        labelStyle: text.labelMedium?.copyWith(color: palette.ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: palette.onAccentSoft),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: StadiumBorder(side: BorderSide(color: palette.line)),
        side: BorderSide(color: palette.line),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            color: selected ? palette.onAccentSoft : palette.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.onAccentSoft : palette.muted,
            size: 24,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: palette.muted,
        indicatorColor: scheme.primary,
        dividerColor: palette.line,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: palette.ink,
        titleTextStyle: text.titleSmall?.copyWith(color: palette.ink),
        subtitleTextStyle: text.bodySmall?.copyWith(color: palette.muted),
        tileColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.line),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
    );
  }

  static TextTheme _textTheme(
    TextTheme headings,
    TextTheme body,
    Color ink,
    Color muted,
  ) {
    TextStyle? paint(TextStyle? style, Color color) =>
        style?.copyWith(color: color);
    return headings.copyWith(
      displaySmall: paint(headings.displaySmall, ink)?.copyWith(
        fontSize: 25,
        height: 1.14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: paint(headings.headlineMedium, ink)?.copyWith(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: paint(headings.headlineSmall, ink)?.copyWith(
        fontSize: 18,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: paint(headings.titleLarge, ink)?.copyWith(
        fontSize: 16,
        height: 1.28,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: paint(headings.titleMedium, ink)?.copyWith(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: paint(headings.titleSmall, ink)?.copyWith(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: paint(body.bodyLarge, ink)?.copyWith(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: paint(body.bodyMedium, ink)?.copyWith(
        fontSize: 13,
        height: 1.42,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: paint(body.bodySmall, muted)?.copyWith(
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: paint(headings.labelLarge, ink)?.copyWith(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: paint(headings.labelMedium, ink)?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: paint(headings.labelSmall, muted)?.copyWith(
        fontSize: 10,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge?.copyWith(color: colors.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
              ],
            ],
          ),
        ),
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// Consistent editorial heading used at the top of full-screen flows.
class AppPageIntro extends StatelessWidget {
  const AppPageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
  });

  final String eyebrow;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(title, style: text.headlineSmall?.copyWith(color: colors.ink)),
        if (description != null) ...[
          const SizedBox(height: 5),
          Text(
            description!,
            style: text.bodySmall?.copyWith(color: colors.muted),
          ),
        ],
      ],
    );
  }
}

/// A compact, pressable row surface for settings and utility destinations.
class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: appCardDecoration(context, radius: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: colors.onAccentSoft),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmpty extends StatelessWidget {
  const AppEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_stories_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: colors.onAccentSoft),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: colors.muted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 14),
            Text(message, style: text.bodyMedium?.copyWith(color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

BoxDecoration appCardDecoration(BuildContext context, {double radius = 16}) {
  final colors = AppPalette.of(context);
  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.line),
    boxShadow: [
      BoxShadow(
        color: colors.shadow,
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
