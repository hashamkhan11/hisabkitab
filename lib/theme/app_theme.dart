import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens beyond what [ColorScheme] covers - category tag colors and
/// muted/border/soft variants used throughout the redesigned screens.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color textColor;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color onAccent;
  final Color danger;
  final Color dangerSoft;
  final Color tagBlue;
  final Color tagBlueSoft;
  final Color tagAmber;
  final Color tagAmberSoft;
  final Color tagPurple;
  final Color tagPurpleSoft;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.textColor,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.onAccent,
    required this.danger,
    required this.dangerSoft,
    required this.tagBlue,
    required this.tagBlueSoft,
    required this.tagAmber,
    required this.tagAmberSoft,
    required this.tagPurple,
    required this.tagPurpleSoft,
  });

  static const light = AppColors(
    bg: Color(0xFFF6F8F4),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF4EC),
    textColor: Color(0xFF152016),
    textMuted: Color(0xFF65756A),
    border: Color(0xFFCFE6D7),
    accent: Color(0xFF1E8E52),
    accentStrong: Color(0xFF146B3D),
    accentSoft: Color(0xFFDFF3E6),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD64541),
    dangerSoft: Color(0xFFFBE4E2),
    tagBlue: Color(0xFF3E6FBF),
    tagBlueSoft: Color(0xFFE3EBFA),
    tagAmber: Color(0xFFC98A1B),
    tagAmberSoft: Color(0xFFFBEED9),
    tagPurple: Color(0xFF7C5CC4),
    tagPurpleSoft: Color(0xFFEEE6FA),
  );

  static const dark = AppColors(
    bg: Color(0xFF0E1512),
    surface: Color(0xFF16211B),
    surfaceAlt: Color(0xFF1C2921),
    textColor: Color(0xFFE8F1E9),
    textMuted: Color(0xFF8FA396),
    border: Color(0xFF2E4A3A),
    accent: Color(0xFF3FCB7C),
    accentStrong: Color(0xFF33A868),
    accentSoft: Color(0xFF193825),
    onAccent: Color(0xFF08150D),
    danger: Color(0xFFFF6E64),
    dangerSoft: Color(0xFF3A1A18),
    tagBlue: Color(0xFF7FA6F2),
    tagBlueSoft: Color(0xFF17253F),
    tagAmber: Color(0xFFE8B65B),
    tagAmberSoft: Color(0xFF3A2C13),
    tagPurple: Color(0xFFB79AEA),
    tagPurpleSoft: Color(0xFF2A2140),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? textColor,
    Color? textMuted,
    Color? border,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? onAccent,
    Color? danger,
    Color? dangerSoft,
    Color? tagBlue,
    Color? tagBlueSoft,
    Color? tagAmber,
    Color? tagAmberSoft,
    Color? tagPurple,
    Color? tagPurpleSoft,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textColor: textColor ?? this.textColor,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      tagBlue: tagBlue ?? this.tagBlue,
      tagBlueSoft: tagBlueSoft ?? this.tagBlueSoft,
      tagAmber: tagAmber ?? this.tagAmber,
      tagAmberSoft: tagAmberSoft ?? this.tagAmberSoft,
      tagPurple: tagPurple ?? this.tagPurple,
      tagPurpleSoft: tagPurpleSoft ?? this.tagPurpleSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      tagBlue: Color.lerp(tagBlue, other.tagBlue, t)!,
      tagBlueSoft: Color.lerp(tagBlueSoft, other.tagBlueSoft, t)!,
      tagAmber: Color.lerp(tagAmber, other.tagAmber, t)!,
      tagAmberSoft: Color.lerp(tagAmberSoft, other.tagAmberSoft, t)!,
      tagPurple: Color.lerp(tagPurple, other.tagPurple, t)!,
      tagPurpleSoft: Color.lerp(tagPurpleSoft, other.tagPurpleSoft, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color color, Color muted) {
    return TextTheme(
      displayLarge: GoogleFonts.sora(fontSize: 34, fontWeight: FontWeight.w700, color: color, height: 1.15),
      displayMedium: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: color, height: 1.2),
      headlineMedium: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: color),
      headlineSmall: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w600, color: color),
      titleLarge: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600, color: color),
      titleMedium: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: color),
      titleSmall: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      bodyLarge: GoogleFonts.inter(fontSize: 15, color: color),
      bodyMedium: GoogleFonts.inter(fontSize: 13.5, color: color),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: muted),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
    );
  }

  static ThemeData _build(AppColors c, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accentStrong,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.textColor,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: colorScheme,
      textTheme: _textTheme(c.textColor, c.textMuted),
      fontFamily: GoogleFonts.inter().fontFamily,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textColor),
        titleTextStyle: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: c.textColor),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: GoogleFonts.inter(color: c.textMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: c.textMuted, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.accent.withValues(alpha: .4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentStrong,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      iconTheme: IconThemeData(color: c.textColor),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 3,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.accentStrong,
        unselectedItemColor: c.textMuted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textColor,
        contentTextStyle: GoogleFonts.inter(color: c.bg, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: [c],
    );
  }

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
}
