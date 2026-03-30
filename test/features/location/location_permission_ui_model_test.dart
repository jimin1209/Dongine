import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dongine/features/location/domain/location_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // buildLocationPermissionUiModel — 권한·서비스·플랫폼 조합별 UI 분기
  // ---------------------------------------------------------------------------
  group('buildLocationPermissionUiModel', () {
    // ---- serviceEnabled: false ----
    test('서비스 꺼짐: 기기 위치 설정 CTA만 노출', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: false,
        permission: LocationPermission.denied,
        platform: TargetPlatform.android,
      );
      expect(ui.showOpenLocationSettingsCta, isTrue);
      expect(ui.showOpenAppSettingsCta, isFalse);
      expect(ui.showBanner, isTrue);
      expect(ui.statusTitle, contains('서비스'));
    });

    test('서비스 꺼짐이면 permission 값에 무관하게 동일 UI', () {
      for (final perm in LocationPermission.values) {
        final ui = buildLocationPermissionUiModel(
          serviceEnabled: false,
          permission: perm,
          platform: TargetPlatform.iOS,
        );
        expect(ui.statusTitle, '위치 서비스 꺼짐',
            reason: 'permission=$perm 일 때도 서비스 꺼짐 우선');
        expect(ui.showOpenLocationSettingsCta, isTrue);
        expect(ui.showOpenAppSettingsCta, isFalse);
      }
    });

    // ---- denied ----
    test('denied: 앱 설정 CTA, 배너 노출', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.denied,
        platform: TargetPlatform.android,
      );
      expect(ui.statusTitle, contains('권한 없음'));
      expect(ui.showBanner, isTrue);
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.showOpenLocationSettingsCta, isFalse);
    });

    // ---- deniedForever ----
    test('deniedForever: 앱 설정 CTA, 배너 노출', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.deniedForever,
        platform: TargetPlatform.android,
      );
      expect(ui.statusTitle, contains('거부'));
      expect(ui.showBanner, isTrue);
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.showOpenLocationSettingsCta, isFalse);
    });

    // ---- unableToDetermine ----
    test('unableToDetermine: 배너 숨김, 양쪽 CTA 모두 노출', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.unableToDetermine,
        platform: TargetPlatform.android,
      );
      expect(ui.statusTitle, contains('확인 불가'));
      expect(ui.showBanner, isFalse);
      expect(ui.bannerMessage, isNull);
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.showOpenLocationSettingsCta, isTrue);
    });

    // ---- whileInUse — iOS ----
    test('iOS whileInUse: 배너에 「항상」 변경 안내', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: TargetPlatform.iOS,
      );
      expect(ui.showBanner, isTrue);
      expect(ui.bannerMessage, isNotNull);
      expect(ui.bannerMessage!, contains('항상'));
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.openAppSettingsCtaLabel, contains('항상'));
    });

    // ---- whileInUse — Android ----
    test('Android whileInUse: 권장 배너, 앱 설정 CTA', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: TargetPlatform.android,
      );
      expect(ui.showBanner, isTrue);
      expect(ui.showOpenAppSettingsCta, isTrue);
      expect(ui.statusSubtitle, contains('전면 위치 알림'));
    });

    // ---- always — iOS ----
    test('iOS always: 경고 배너 없음, CTA 숨김', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.always,
        platform: TargetPlatform.iOS,
      );
      expect(ui.showBanner, isFalse);
      expect(ui.bannerMessage, isNull);
      expect(ui.showOpenAppSettingsCta, isFalse);
      expect(ui.showOpenLocationSettingsCta, isFalse);
    });

    // ---- always — Android ----
    test('Android always: 경고 배너 없음, CTA 숨김', () {
      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.always,
        platform: TargetPlatform.android,
      );
      expect(ui.showBanner, isFalse);
      expect(ui.bannerMessage, isNull);
      expect(ui.showOpenAppSettingsCta, isFalse);
      expect(ui.showOpenLocationSettingsCta, isFalse);
    });

    // ---- whileInUse 플랫폼 분기: statusTitle 차이 ----
    test('whileInUse iOS vs Android statusTitle 텍스트가 다르다', () {
      final ios = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: TargetPlatform.iOS,
      );
      final android = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: TargetPlatform.android,
      );
      expect(ios.statusTitle, isNot(equals(android.statusTitle)));
    });

    // ---- 모든 서비스 ON 분기에서 반환 값이 non-null ----
    test('서비스 ON 일 때 모든 permission에서 CTA 라벨이 비어 있지 않다', () {
      for (final perm in LocationPermission.values) {
        for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
          final ui = buildLocationPermissionUiModel(
            serviceEnabled: true,
            permission: perm,
            platform: platform,
          );
          expect(ui.statusTitle.isNotEmpty, isTrue,
              reason: 'perm=$perm platform=$platform');
          expect(ui.statusSubtitle.isNotEmpty, isTrue);
          expect(ui.openAppSettingsCtaLabel.isNotEmpty, isTrue);
          expect(ui.openLocationSettingsCtaLabel.isNotEmpty, isTrue);
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // LocationPermissionSnapshot helpers
  // ---------------------------------------------------------------------------
  group('LocationPermissionSnapshot.hasUsablePermission', () {
    test('whileInUse는 사용 가능', () {
      expect(
        const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
        ).hasUsablePermission,
        isTrue,
      );
    });

    test('always는 사용 가능', () {
      expect(
        const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.always,
        ).hasUsablePermission,
        isTrue,
      );
    });

    test('denied는 사용 불가', () {
      expect(
        const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        ).hasUsablePermission,
        isFalse,
      );
    });

    test('deniedForever는 사용 불가', () {
      expect(
        const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        ).hasUsablePermission,
        isFalse,
      );
    });

    test('unableToDetermine는 사용 불가', () {
      expect(
        const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.unableToDetermine,
        ).hasUsablePermission,
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // computeBackgroundSupport — 순수 함수 단위 테스트
  // ---------------------------------------------------------------------------
  group('LocationPermissionSnapshot.computeBackgroundSupport', () {
    test('웹이면 항상 false', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: true,
          serviceEnabled: true,
          permission: LocationPermission.always,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('서비스 꺼짐이면 false', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: false,
          permission: LocationPermission.always,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('denied 이면 false', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.denied,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('deniedForever 이면 false', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
      );
    });

    test('iOS + whileInUse → false (always 필요)', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
      );
    });

    test('iOS + always → true', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.always,
          platform: TargetPlatform.iOS,
        ),
        isTrue,
      );
    });

    test('Android + whileInUse → true', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('Android + always → true', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.always,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('unableToDetermine → false (usable이 아님)', () {
      expect(
        LocationPermissionSnapshot.computeBackgroundSupport(
          isWeb: false,
          serviceEnabled: true,
          permission: LocationPermission.unableToDetermine,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isBackgroundSharingFullySupported getter (런타임 플랫폼 의존)
  // ---------------------------------------------------------------------------
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
