import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/expressive_theme.dart';
import 'presentation/controllers/clock_controller.dart';
import 'presentation/controllers/cloud_sync_controller.dart';
import 'presentation/controllers/mcp_server_controller.dart';
import 'presentation/screens/dial_embed_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final queryParams = Uri.base.queryParameters;
  final modeParam = queryParams['mode']?.toLowerCase();
  final presetParam = queryParams['preset']?.toLowerCase();
  final viewParam = queryParams['view']?.toLowerCase();
  final themeParam = queryParams['theme']?.toLowerCase();

  final isDialEmbed =
      viewParam == 'dial' || viewParam == 'embed' || viewParam == 'widget';

  if (isDialEmbed || themeParam == 'dark') {
    await prefs.setString('setting_theme', 'dark');
  }

  if (modeParam == '24h' ||
      presetParam == 'international' ||
      presetParam == 'intl') {
    await prefs.setBool('setting_is24h', true);
  } else if (modeParam == '12h' || presetParam == 'indian') {
    await prefs.setBool('setting_is24h', false);
  }

  final syncParam = queryParams['sync']?.trim();
  if (syncParam != null && syncParam.isNotEmpty) {
    await prefs.setString('cloud_sync_key', syncParam);
    await prefs.setString('radian_sync_key', syncParam);
    await prefs.setBool('cloud_sync_enabled', true);
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: SectographApp(
        home: isDialEmbed ? const DialEmbedScreen() : null,
        isDialEmbed: isDialEmbed,
      ),
    ),
  );
}

class SectographApp extends ConsumerWidget {
  final Widget? home;
  final bool isDialEmbed;
  const SectographApp({super.key, this.home, this.isDialEmbed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mcpServerControllerProvider);
    ref.watch(cloudSyncControllerProvider);
    final settings = ref.watch(dialSettingsProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ExpressiveTheme.light(settings.seedColor),
      darkTheme: ExpressiveTheme.dark(settings.seedColor),
      themeMode: isDialEmbed ? ThemeMode.dark : settings.themeMode,
      home: home ?? const SplashScreen(),
    );
  }
}
