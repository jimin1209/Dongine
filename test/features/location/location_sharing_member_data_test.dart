import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/location/data/location_repository.dart';

void main() {
  group('locationSharingEnabledFromMemberData', () {
    test('문서가 없으면 false', () {
      expect(locationSharingEnabledFromMemberData(false, null), false);
    });

    test('데이터가 null이면 false', () {
      expect(locationSharingEnabledFromMemberData(true, null), false);
    });

    test('필드가 없으면 FamilyMember 기본과 같이 true', () {
      expect(
        locationSharingEnabledFromMemberData(true, {'role': 'member'}),
        true,
      );
    });

    test('명시적 false', () {
      expect(
        locationSharingEnabledFromMemberData(true, {
          'locationSharingEnabled': false,
        }),
        false,
      );
    });

    test('명시적 true', () {
      expect(
        locationSharingEnabledFromMemberData(true, {
          'locationSharingEnabled': true,
        }),
        true,
      );
    });
  });
}
