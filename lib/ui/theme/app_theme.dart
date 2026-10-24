import 'package:flutter/material.dart';

import 'tokens.dart';

/// Nunito at a weight. The bundled font is variable, so the weight is set
/// on its 'wght' axis as well as through [FontWeight].
TextStyle slipText(double size, int weight,
    {Color? color, bool tabular = false, bool mono = false, double? letterSpacing, double? height}) {
  return TextStyle(
    fontFamily: mono ? 'JetBrainsMono' : 'Nunito',
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Light theme = handoff variant a, dark theme = variant b.
ThemeData buildSlipTheme(Brightness brightness) {
  final t = brightness == Brightness.light ? SlipTokens.light : SlipTokens.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.acc,
    onPrimary: t.accInk,
    primaryContainer: t.accSoft,
    onPrimaryContainer: t.accText,
    secondary: t.accDeep,
    onSecondary: t.accInk,
    error: t.up,
    onError: t.accInk,
    surface: t.bg,
    onSurface: t.ink,
    onSurfaceVariant: t.ink2,
    surfaceContainerLowest: t.surf,
    surfaceContainerLow: t.surf,
    surfaceContainer: t.surf,
    surfaceContainerHigh: t.surf2,
    surfaceContainerHighest: t.surf2,
    outline: t.line,
    outlineVariant: t.line,
  );
  TextStyle s(double size, int w, [Color? c]) => slipText(size, w, color: c ?? t.ink);
  final text = TextTheme(
    displayLarge: s(40, 900),
    displayMedium: s(34, 900),
    displaySmall: s(28, 900),
    headlineLarge: s(28, 900),
    headlineMedium: s(22, 900),
    headlineSmall: s(20, 900),
    titleLarge: s(20, 900),
    titleMedium: s(17, 800),
    titleSmall: s(15, 800),
    bodyLarge: s(16, 700),
    bodyMedium: s(14, 700),
    bodySmall: s(12.5, 600, t.ink2),
    labelLarge: s(15, 800),
    labelMedium: s(13, 800),
    labelSmall: s(11, 800),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(t.rCard),
    side: t.outline ?? BorderSide.none,
  );
  final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.punchy ? 12 : 999),
      side: t.outline ?? BorderSide.none);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    fontFamily: 'Nunito',
    textTheme: text,
    extensions: [t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s(22, 900),
    ),
    cardTheme: CardThemeData(
      color: t.surf,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.acc,
        foregroundColor: t.accInk,
        minimumSize: const Size(0, 48),
        textStyle: slipText(15, 900),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        backgroundColor: t.surf2,
        side: t.outline ?? BorderSide.none,
        minimumSize: const Size(0, 44),
        textStyle: slipText(14, 800),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.accText, textStyle: slipText(14, 800)),
    ),
    dividerTheme: DividerThemeData(color: t.line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surf2,
      labelStyle: slipText(12, 700, color: t.ink2),
      floatingLabelStyle: slipText(12, 800, color: t.accText),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.rField), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.rField),
          borderSide: t.outline ?? BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.rField),
          borderSide: BorderSide(color: t.acc, width: 2)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surf,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.punchy ? 16 : 28)),
        side: t.outline ?? BorderSide.none,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surf,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      titleTextStyle: s(20, 900),
      contentTextStyle: s(14, 600, t.ink2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.punchy ? t.ink : t.ink,
      contentTextStyle: slipText(14, 800, color: t.punchy ? t.bg : Colors.white),
      actionTextColor: t.acc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.punchy ? 12 : 18)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.surf2,
      selectedColor: t.ink,
      labelStyle: slipText(13, 800, color: t.ink),
      side: t.outline ?? BorderSide.none,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: t.surf2,
        selectedBackgroundColor: t.punchy ? t.acc : t.surf,
        selectedForegroundColor: t.punchy ? t.accInk : t.ink,
        foregroundColor: t.ink2,
        textStyle: slipText(13, 800),
        side: t.outline ?? BorderSide.none,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surf,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      textStyle: s(14, 800),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.acc : null),
      checkColor: WidgetStatePropertyAll(t.accInk),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.acc, linearTrackColor: t.surf2),
  );
}
