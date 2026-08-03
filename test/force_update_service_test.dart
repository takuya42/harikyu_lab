import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/update/force_update_service.dart';

void main() {
  group('compareVersions', () {
    test('compares every numeric segment', () {
      expect(compareVersions('1.0.2', '1.0.3'), isNegative);
      expect(compareVersions('1.10.0', '1.9.9'), isPositive);
    });

    test('treats missing segments and build metadata correctly', () {
      expect(compareVersions('1.0+12', '1.0.0'), 0);
      expect(compareVersions('2.0.0', '2.0'), 0);
    });
  });
}
