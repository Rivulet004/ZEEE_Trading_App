import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true; // Default to Obsidian Dark Theme

  bool get isDark => _isDark;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('is_dark_theme') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_theme', _isDark);
    notifyListeners();
  }

  // 1. Premium Obsidian Dark Theme Colors
  static const Color darkCanvas = Color(0xFF0F0F11);
  static const Color darkSurface = Color(0xFF18181C);
  static const Color darkPrimaryAccent = Color(0xFF00FFC2); // Electric Cyan
  static const Color darkSecondaryAccent = Color(0xFF64748B); // Ghost Slate
  static const Color darkPrimaryTypography = Color(0xFFE2E8F0); // Read Silk
  static const Color darkError = Color(0xFFFF453A); // Crimson Warning

  // 2. Clinical Corporate Light Theme Colors
  static const Color lightCanvas = Color(0xFFF8FAFC); // Milk White
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightPrimaryAccent = Color(0xFF1E3A8A); // Deep Institutional Blue
  static const Color lightSecondaryAccent = Color(0xFFF97316); // Industrial Orange
  static const Color lightPrimaryTypography = Color(0xFF0F172A); // Charcoal Black
  static const Color lightMutedTypography = Color(0xFF475569); // Ash Slate

  // Dynamic getters based on settings
  Color get canvas => _isDark ? darkCanvas : lightCanvas;
  Color get surface => _isDark ? darkSurface : lightSurface;
  Color get primaryAccent => _isDark ? darkPrimaryAccent : lightPrimaryAccent;
  Color get secondaryAccent => _isDark ? darkSecondaryAccent : lightSecondaryAccent;
  Color get primaryTypography => _isDark ? darkPrimaryTypography : lightPrimaryTypography;
  Color get errorColor => _isDark ? darkError : Colors.red;

  Color get textPrimary => _isDark ? darkPrimaryTypography : lightPrimaryTypography;
  Color get textSecondary => _isDark ? darkSecondaryAccent : lightMutedTypography;

  ThemeData get themeData {
    return ThemeData(
      brightness: _isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: canvas,
      primaryColor: primaryAccent,
      cardColor: surface,
      dialogTheme: DialogThemeData(backgroundColor: surface),
      dividerColor: _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      colorScheme: ColorScheme(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        primary: primaryAccent,
        onPrimary: _isDark ? Colors.black : Colors.white,
        secondary: secondaryAccent,
        onSecondary: Colors.white,
        error: _isDark ? darkError : Colors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
