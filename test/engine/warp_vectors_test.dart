import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/engine/warp_map.dart';

void main() {
  group('Shared Warp Interpolation Vector Tests (Phase 6 Parity)', () {
    test('WarpMap.forward matches all shared test vector suites', () {
      final file = File('test/fixtures/warp_interpolation_vectors.json');
      expect(file.existsSync(), isTrue, reason: 'Test vector file must exist');

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final suites = json['testSuites'] as List;

      for (final suite in suites) {
        final suiteMap = suite as Map<String, dynamic>;
        final name = suiteMap['name'] as String;
        final rawBreakpoints = suiteMap['breakpoints'] as List;
        final cases = suiteMap['cases'] as List;

        final breakpoints = rawBreakpoints.map((bp) {
          final pair = bp as List;
          return WarpBreakpoint(
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          );
        }).toList();

        final warp = WarpMap(breakpoints);

        for (final c in cases) {
          final caseMap = c as Map<String, dynamic>;
          final input = (caseMap['inputNaturalDeg'] as num).toDouble();
          final expected = (caseMap['expectedDisplayDeg'] as num).toDouble();

          final actual = warp.forward(input);
          expect(
            actual,
            closeTo(expected, 0.001),
            reason: 'Suite "$name" failed for natural angle $input°: expected $expected°, got $actual°',
          );
        }
      }
    });
  });
}
