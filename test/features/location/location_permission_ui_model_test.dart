import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dongine/features/location/domain/location_provider.dart';

void main() {
  group('buildLocationPermissionUiModel', () {
    test('서비스 꺼짐: 기기 위치 설정 CTA', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: false,
        permission: LocationPermission.denied,
        platform: TargetPlatform.android,
      );
      expect(ui.showOpenLocationSettingsCta, isTrue);
      expect(ui.showOpenAppSettingsCta, isFalse);
      expect(ui.statusTitle, contains('서비스'));
    });

    test('iOS 앱 사용 중: 백그라운드 안내 및 앱 설정 CTA', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: TargetPlatform.iOS,
      );
      expect(ui.showBanner, isTrue);
      expect(ui.bannerMessage, isNotNull);
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.openAppSettingsCtaLabel, contains('항상'));
    });

    test('Android 앱 사용 중: 권장 배너 및 앱 설정 CTA', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: TargetPlatform.android,
      );
      expect(ui.showBanner, isTrue);
      expect(ui.showOpenAppSettingsCta, isTrue);
    });

    test('항상 허용: 경고 배너 없음', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.always,
        platform: TargetPlatform.iOS,
      );
      expect(ui.showBanner, isFalse);
      expect(ui.bannerMessage, isNull);
      expect(ui.showOpenAppSettingsCta, isFalse);
    });

    test('거부 영구: 앱 설정 CTA', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.deniedForever,
        platform: TargetPlatform.android,
      );
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.showOpenLocationSettingsCta, isFalse);
    });
  });

  group('LocationPermissionSnapshot.isBackgroundSharingFullySupported', () {
    test(
      'iOS에서 앱 사용 중만 허용이면 백그라운드 완전 지원이 아니다',
      () {
        expect(
          const LocationPermissionSnapshot(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
          ).isBackgroundSharingFullySupported,
          isFalse,
        );
      },
      skip: kIsWeb || defaultTargetPlatform != TargetPlatform.iOS,
    );

    test(
      'Android에서 앱 사용 중 허용은 백그라운드 완전 지원으로 본다',
      () {
        expect(
          const LocationPermissionSnapshot(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
          ).isBackgroundSharingFullySupported,
          isTrue,
        );
      },
      skip: kIsWeb || defaultTargetPlatform != TargetPlatform.android,
    );
  });
}
