import 'package:flutter/material.dart';

/// Desktop-first, port-centric chrome — not a phone Material skin.
class AppTheme {
  static const bg = Color(0xFF0F1115);
  static const surface = Color(0xFF161A21);
  static const surface2 = Color(0xFF1C222C);
  static const border = Color(0xFF2A3140);
  static const text = Color(0xFFE8ECF2);
  static const textMuted = Color(0xFF9AA3B2);
  static const accent = Color(0xFF5B8CFF);
  static const accentSoft = Color(0x335B8CFF);
  static const success = Color(0xFF3DDC97);
  static const danger = Color(0xFFFF6B6B);
  static const warn = Color(0xFFFFC857);
  static const dev = Color(0xFF7C5CFF);

  /// 界面主字体（Noto Sans SC 可变字重）
  static const fontFamily = 'NotoSansSC';
  /// 数据/等宽字体（端口、PID、地址、路径）
  static const mono = 'JetBrainsMono';

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        onPrimary: Colors.white,
        error: danger,
      ),
      scaffoldBackgroundColor: bg,
      dividerColor: border,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 12),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        dataTextStyle: TextStyle(color: text, fontSize: 12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: text, fontSize: 11),
      ),
    );
  }
}
