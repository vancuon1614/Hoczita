import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_constants.dart';
import 'core/services/supabase_service.dart';
import 'core/services/api_service.dart';
import 'features/onboarding/views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();

  // Khởi tạo Supabase nếu đã được cấu hình hợp lệ
  final service = SupabaseService.instance;
  if (service.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConstants.url,
        publishableKey: SupabaseConstants.anonKey,
      );
      debugPrint('Supabase initialized successfully!');
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  } else {
    debugPrint('Supabase is not configured yet. Falling back to local offline mode.');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App HocZiTa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
