import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/text_measurement_service.dart';
import 'package:sectograph_mcp/engine/text_measurer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FastTextMeasurer (Pure Dart Script-Aware Estimator)', () {
    const measurer = FastTextMeasurer();

    test('returns zero for empty string', () {
      final dims = measurer.measure('');
      expect(dims.width, 0.0);
      expect(dims.height, 0.0);
    });

    test('CJK characters are measured with full wide pitch', () {
      final latinDims = measurer.measure('ABCD', fontSize: 12.0);
      final cjkDims = measurer.measure('会議日程', fontSize: 12.0);

      // CJK ideographs have wider em-box than standard Latin
      expect(cjkDims.width, greaterThan(latinDims.width));
      expect(cjkDims.height, equals(12.0 * 1.25));
    });

    test(
      'narrow punctuation and numbers measure narrower than uppercase Latin',
      () {
        final narrowDims = measurer.measure('.:1li', fontSize: 12.0);
        final wideDims = measurer.measure('MWMW', fontSize: 12.0);

        expect(narrowDims.width, lessThan(wideDims.width));
      },
    );

    test(
      'Indic and Arabic scripts are measured with appropriate proportions',
      () {
        final odiaDims = measurer.measure('ଯୋଗ', fontSize: 12.0);
        final arabicDims = measurer.measure('جلسة', fontSize: 12.0);

        expect(odiaDims.width, greaterThan(0.0));
        expect(arabicDims.width, greaterThan(0.0));
      },
    );
  });

  group('TextMeasurementService (Flutter TextPainter with LRU Cache)', () {
    final service = TextMeasurementService.instance;

    setUp(() {
      service.clearCache();
    });

    test('measures real text layout and populates cache', () {
      expect(service.cacheSize, 0);

      final dims1 = service.measure('Deep Work', fontSize: 12.0);
      expect(dims1.width, greaterThan(0.0));
      expect(dims1.height, greaterThan(0.0));
      expect(service.cacheSize, 1);

      // Second identical call returns cached result without expanding cache size
      final dims2 = service.measure('Deep Work', fontSize: 12.0);
      expect(dims2.width, equals(dims1.width));
      expect(dims2.height, equals(dims1.height));
      expect(service.cacheSize, 1);
    });

    test(
      'distinguishes font sizes, text strings, and font families in cache keys',
      () {
        service.measure('Focus', fontSize: 10.0);
        service.measure('Focus', fontSize: 12.0);
        service.measure('Rest', fontSize: 10.0);

        expect(service.cacheSize, 3);
      },
    );

    test('clearing cache resets cache size', () {
      service.measure('Meeting', fontSize: 12.0);
      expect(service.cacheSize, 1);

      service.clearCache();
      expect(service.cacheSize, 0);
    });
  });
}
