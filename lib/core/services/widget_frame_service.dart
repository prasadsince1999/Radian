import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/dial_settings.dart';
import '../../engine/dial_model.dart';
import '../../engine/widget_frame_planner.dart';
import '../../presentation/widgets/dial/dial_painter.dart';
import '../theme/expressive_theme.dart';
import 'android_widget_service.dart';

/// Renders, caches, and atomically deploys precomputed 720x720 widget dial frames (§6.1, RC5, RC6, RC10).
///
/// Features:
/// 1. Renders light & dark theme variants for every interval in a [WidgetFrameStripPlan].
/// 2. Atomic writes: builds in `<version>_tmp/`, renames to `<version>/`, and updates `current.json`.
/// 3. Signals native Android via [AndroidWidgetService] to load new frames.
class WidgetFrameService {
  const WidgetFrameService._();

  static const double widgetBitmapSize = 720.0;
  static Directory? baseDirOverride;

  /// Renders a single [DialModel] to a 720x720 PNG byte array (needle & center clock omitted).
  static Future<Uint8List?> renderFramePng({
    required DialModel model,
    required DialSettings settings,
    required ThemeData theme,
    double size = widgetBitmapSize,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintSize = Size(size, size);

    final painter = DialPainter(
      model: model,
      settings: settings,
      theme: theme,
      colorScheme: theme.colorScheme,
      showNeedle: false,
      showCenterClock: false,
    );

    painter.paint(canvas, paintSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Writes and deploys the full frame strip atomically to the filesystem.
  static Future<bool> deployFrameStrip({
    required WidgetFrameStripPlan plan,
    required DialSettings settings,
    Directory? customBaseDir,
  }) async {
    try {
      final baseDir = customBaseDir ?? await _getWidgetFramesBaseDir();
      if (baseDir == null) return false;

      final targetDir = Directory('${baseDir.path}/${plan.dataVersion}');
      final stagingDir = Directory('${baseDir.path}/${plan.dataVersion}_tmp');

      if (stagingDir.existsSync()) {
        stagingDir.deleteSync(recursive: true);
      }
      stagingDir.createSync(recursive: true);

      final lightDir = Directory('${stagingDir.path}/light');
      final darkDir = Directory('${stagingDir.path}/dark');
      lightDir.createSync(recursive: true);
      darkDir.createSync(recursive: true);

      final lightTheme = ExpressiveTheme.light(settings.seedColor);
      final darkTheme = ExpressiveTheme.dark(settings.seedColor);

      // Render each frame for both light and dark variants
      for (final frame in plan.frames) {
        final lightBytes = await renderFramePng(
          model: frame.model,
          settings: settings,
          theme: lightTheme,
        );
        if (lightBytes != null) {
          final lightFile = File('${lightDir.path}/${frame.fileName}');
          await lightFile.writeAsBytes(lightBytes, flush: true);
        }

        final darkBytes = await renderFramePng(
          model: frame.model,
          settings: settings,
          theme: darkTheme,
        );
        if (darkBytes != null) {
          final darkFile = File('${darkDir.path}/${frame.fileName}');
          await darkFile.writeAsBytes(darkBytes, flush: true);
        }
      }

      // Write frames.json into staging directory
      final framesJsonFile = File('${stagingDir.path}/frames.json');
      await framesJsonFile.writeAsString(
        jsonEncode(plan.toJson()),
        flush: true,
      );

      // Atomic rename
      if (targetDir.existsSync()) {
        targetDir.deleteSync(recursive: true);
      }
      stagingDir.renameSync(targetDir.path);

      // Write current.json pointer
      final currentPointerFile = File('${baseDir.path}/current.json');
      await currentPointerFile.writeAsString(
        jsonEncode({
          'currentVersion': plan.dataVersion,
          'tzid': plan.tzid,
          'validUntilMs': plan.validUntilMs,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        }),
        flush: true,
      );

      // Clean up older version directories
      _cleanupOldVersions(baseDir, plan.dataVersion);

      // Notify native Android widget provider
      await AndroidWidgetService.notifyFrameStripUpdated(
        dataVersion: plan.dataVersion,
        tzid: plan.tzid,
        validUntilMs: plan.validUntilMs,
        framesCount: plan.frames.length,
      );

      return true;
    } catch (e, st) {
      debugPrint('WidgetFrameService.deployFrameStrip error: $e\n$st');
      return false;
    }
  }

  static Future<Directory?> _getWidgetFramesBaseDir() async {
    if (baseDirOverride != null) {
      if (!baseDirOverride!.existsSync()) {
        baseDirOverride!.createSync(recursive: true);
      }
      return baseDirOverride;
    }
    try {
      final appSupport = await getApplicationSupportDirectory();
      final framesDir = Directory('${appSupport.path}/widget_frames');
      if (!framesDir.existsSync()) {
        framesDir.createSync(recursive: true);
      }
      return framesDir;
    } catch (_) {
      return null;
    }
  }

  static void _cleanupOldVersions(Directory baseDir, String activeVersion) {
    try {
      final entries = baseDir.listSync();
      for (final entry in entries) {
        if (entry is Directory) {
          final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
          if (name != activeVersion && !name.endsWith('_tmp')) {
            try {
              entry.deleteSync(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
