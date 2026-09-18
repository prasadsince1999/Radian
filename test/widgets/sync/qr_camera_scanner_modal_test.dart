import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/sync/qr_camera_scanner_modal.dart';

void main() {
  group('QrCameraScannerModal extractSyncKey Tests', () {
    test('extracts sync key from full web app URL with query parameter', () {
      const url =
          'https://ksmxtech.com/radian/app/?sync=RAD-7A4B-9E2C&theme=dark';
      final key = QrCameraScannerModal.extractSyncKey(url);
      expect(key, equals('RAD-7A4B-9E2C'));
    });

    test('extracts sync key from custom scheme URL', () {
      const url = 'http://localhost:8080/?sync=RAD-1111-2222';
      final key = QrCameraScannerModal.extractSyncKey(url);
      expect(key, equals('RAD-1111-2222'));
    });

    test('extracts direct raw key without URL formatting', () {
      const rawKey = 'RAD-ABCD-EF01';
      final key = QrCameraScannerModal.extractSyncKey(rawKey);
      expect(key, equals('RAD-ABCD-EF01'));
    });

    test('handles whitespace around input gracefully', () {
      const padded = '   RAD-9999-8888   \n';
      final key = QrCameraScannerModal.extractSyncKey(padded);
      expect(key, equals('RAD-9999-8888'));
    });

    test('returns null for empty or whitespace-only input', () {
      expect(QrCameraScannerModal.extractSyncKey(''), isNull);
      expect(QrCameraScannerModal.extractSyncKey('   '), isNull);
    });
  });
}
