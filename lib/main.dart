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

  final isDialEmbed =
      viewParam == 'dial' || viewParam == 'embed' || viewParam == 'widget';

  if (modeParam == '24h' ||
      presetParam == 'international' ||
      presetParam == 'intl') {
    await prefs.setBool('setting_is24h', true);
  } else if (modeParam == '12h' || presetParam == 'indian') {
    await prefs.setBool('setting_is24h', false);
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: SectographApp(home: isDialEmbed ? const DialEmbedScreen() : null),
    ),
  );
}

class SectographApp extends ConsumerWidget {
  final Widget? home;
  const SectographApp({super.key, this.home});

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
      themeMode: settings.themeMode,
      home: home ?? const SplashScreen(),
    );
  }
}
