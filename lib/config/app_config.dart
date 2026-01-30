import 'package:flutter/foundation.dart';

/// Uygulama konfigürasyonu
class AppConfig {
  AppConfig._(); // Private constructor

  // --- ENVIRONMENT ---
  static bool get isProduction => kReleaseMode;
  static bool get isDevelopment => !kReleaseMode;
  static bool get isDebug => kDebugMode;

  // --- API CONFIGURATION ---
  static String get apiUrl {
    const apiUrl = String.fromEnvironment('API_URL');
    if (apiUrl.isNotEmpty) return apiUrl;
    
    if (isProduction) {
      // Production API URL - environment variable'dan alınmalı
      return 'https://your-production-api.com';
    }
    
    // Development default
    return 'http://localhost:3000';
  }

  // --- FIREBASE CONFIG ---
  static bool get enableCrashlytics => isProduction;
  static bool get enablePerformanceMonitoring => isProduction;
  static bool get enableAnalytics => true; // Her zaman aktif

  // --- LOGGING ---
  static bool get enableVerboseLogging => isDevelopment;
  static bool get enableDebugLogging => isDevelopment || isDebug;
  static bool get enableErrorLogging => true; // Her zaman aktif

  // --- CACHE ---
  static bool get enableImageCache => true;
  static int get imageCacheMaxSize => isProduction ? 100 : 50; // MB

  // --- FEATURE FLAGS ---
  static bool get enableExperimentalFeatures => isDevelopment;
  
  // --- PERFORMANCE ---
  static bool get enablePerformanceOverlay => isDebug;
  static bool get enableSlowAnimations => false; // Debug için
}
