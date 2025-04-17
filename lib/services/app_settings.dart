import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  static const String _storageKey = 'linkhodl_settings';

  bool _isDarkMode = false;
  String _activityFilter = 'all'; // 'week', 'month', 'year', 'all'
  bool _didActivityFilterChange = false;
  int _dayFilterValue = 7;
  bool _showNotifications = true;

  bool get isDarkMode => _isDarkMode;
  String get activityFilter => _activityFilter;
  int get dayFilterValue => _dayFilterValue;
  bool get showNotifications => _showNotifications;

  bool get didActivityFilterChange {
    if (_didActivityFilterChange) {
      // Reset after reading
      _didActivityFilterChange = false;
      return true;
    }
    return false;
  }

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final Map<String, dynamic> settings = jsonDecode(settingsJson);
        _isDarkMode = settings['isDarkMode'] ?? false;
        _activityFilter = settings['activityFilter'] ?? 'all';
        _dayFilterValue = settings['dayFilterValue'] ?? 7;
        _showNotifications = settings['showNotifications'] ?? true;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Use default values if settings can't be loaded
      _isDarkMode = false;
      _activityFilter = 'all';
      _dayFilterValue = 7;
      _showNotifications = true;
    }
  }

  // Save settings to SharedPreferences
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> settings = {
        'isDarkMode': _isDarkMode,
        'activityFilter': _activityFilter,
        'dayFilterValue': _dayFilterValue,
        'showNotifications': _showNotifications,
      };

      await prefs.setString(_storageKey, jsonEncode(settings));
    } catch (e) {
      print('Error saving settings: $e');
      // Consider implementing retry logic or notifying the user
    }
  }

  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await saveSettings();
    notifyListeners();
  }

  // Set dark mode directly
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      await saveSettings();
      notifyListeners();
    }
  }

  // Set activity filter
  Future<void> setActivityFilter(String filter) async {
    if (_activityFilter != filter) {
      _activityFilter = filter;

      // Update day filter value based on the filter
      switch (filter) {
        case 'week':
          _dayFilterValue = 7;
          break;
        case 'month':
          _dayFilterValue = 30;
          break;
        case 'year':
          _dayFilterValue = 365;
          break;
        case 'all':
        default:
          _dayFilterValue = 0;
          break;
      }

      _didActivityFilterChange = true;
      await saveSettings();
      notifyListeners();
    }
  }

  // Set day filter value directly
  Future<void> setDayFilterValue(int days) async {
    if (_dayFilterValue != days) {
      _dayFilterValue = days;

      // Update activity filter based on day value
      if (days == 7) {
        _activityFilter = 'week';
      } else if (days == 30) {
        _activityFilter = 'month';
      } else if (days == 365) {
        _activityFilter = 'year';
      } else {
        _activityFilter = 'all';
      }

      _didActivityFilterChange = true;
      await saveSettings();
      notifyListeners();
    }
  }

  // Set notifications setting
  Future<void> setShowNotifications(bool value) async {
    if (_showNotifications != value) {
      _showNotifications = value;
      await saveSettings();
      notifyListeners();
    }
  }

  // Get a copy of settings with modified values
  AppSettings copyWith({
    bool? isDarkMode,
    String? activityFilter,
    int? dayFilterValue,
    bool? showNotifications,
  }) {
    // Since this is a singleton, we'll modify the instance
    // and return it (not actually creating a copy)
    if (isDarkMode != null) _isDarkMode = isDarkMode;
    if (activityFilter != null) _activityFilter = activityFilter;
    if (dayFilterValue != null) _dayFilterValue = dayFilterValue;
    if (showNotifications != null) _showNotifications = showNotifications;

    return this;
  }

  // Get theme data based on current settings
  ThemeData getThemeData() {
    if (_isDarkMode) {
      return ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple.shade200,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple.shade200,
          secondary: Colors.tealAccent,
          surface: Colors.grey.shade900,
          onSurface: Colors.white,
          error: Colors.redAccent,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onError: Colors.white,
          background: const Color(0xFF121212),
          onBackground: Colors.white,
        ),
        cardTheme: CardTheme(
          color: Colors.grey.shade800,
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.grey.shade800,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.deepPurple.shade200, width: 2),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey.shade900,
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: Colors.deepPurple.shade200,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple.shade200,
          ),
        ),
        dividerColor: Colors.grey.shade700,
      );
    } else {
      return ThemeData.light().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple.shade50,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.deepPurple,
          secondary: Colors.teal,
          surface: Colors.white,
          onSurface: Colors.black,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onError: Colors.white,
          background: Colors.grey.shade50,
          onBackground: Colors.black,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.deepPurple,
          contentTextStyle: TextStyle(color: Colors.white),
          actionTextColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
          ),
        ),
        dividerColor: Colors.grey.shade300,
      );
    }
  }
}
