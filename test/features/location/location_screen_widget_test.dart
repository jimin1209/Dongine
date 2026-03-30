import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/location/data/location_repository.dart';
import 'package:dongine/features/location/domain/location_provider.dart';
import 'package:dongine/features/location/presentation/location_screen.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/location_model.dart';

const _familyId = 'fam-loc-widget';
const _userId = 'user-loc-widget';

final _testFamily = FamilyModel(
  id: _familyId,
  name: '위치 위젯 테스트',
  createdBy: _userId,
  inviteCode: 'LOCWT1',
  createdAt: DateTime(2026, 3, 1),
);

class _FakeUser extends Fake implements User {
  @override
  String get uid => _userId;
}

class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository(this._sharingEvents);

  final StreamController<bool> _sharingEvents;
  int toggleCallCount = 0;
  bool? lastToggleEnabled;

  @override
  Future<void> updateLocation(
    String familyId,
    String userId,
    double lat,
    double lng, {
    String? address,
    double? battery,
    double? accuracy,
  }) async {}

  @override
  Stream<List<LocationModel>> getFamilyLocationsStream(String familyId) {
    return Stream.value(const <LocationModel>[]);
  }

  @override
  Stream<LocationModel?> getLocationStream(String familyId, String userId) {
    return Stream.value(null);
  }

  @override
  Stream<bool> watchLocationSharingEnabled(String familyId, String userId) {
    return _sharingEvents.stream;
  }

  @override
  Future<void> toggleLocationSharing(
    String familyId,
    String userId,
    bool enabled,
  ) async {
    toggleCallCount++;
    lastToggleEnabled = enabled;
    _sharingEvents.add(enabled);
  }
}

Position _testPosition() {
  return Position(
    latitude: 37.5665,
    longitude: 126.978,
    timestamp: DateTime.utc(2026, 3, 31, 12),
    accuracy: 4,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  Future<void> setGeolocatorOpenSettingsMocks() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (call) async {
      switch (call.method) {
        case 'openAppSettings':
        case 'openLocationSettings':
          return null;
        default:
          return null;
      }
    });
  }

  void clearGeolocatorMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
  }

  List<Override> baseOverrides({
    required StreamController<bool> sharingController,
    required LocationRepository repo,
    LocationScreenInitOverride? initOverride,
    LocationPermissionSnapshot? permissionSnapshot,
    bool skipNaverInit = true,
    bool mapPlaceholder = true,
  }) {
    final snap = permissionSnapshot ??
        const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.always,
        );

    return [
      authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
      currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
      familyMembersProvider(_familyId)
          .overrideWith((ref) => Stream.value(const <FamilyMember>[])),
      locationRepositoryProvider.overrideWithValue(repo),
      locationScreenInitOverrideProvider.overrideWithValue(initOverride),
      locationSkipNaverMapSdkInitProvider.overrideWithValue(skipNaverInit),
      locationUseNaverMapPlaceholderProvider.overrideWithValue(mapPlaceholder),
      locationPermissionSnapshotProvider.overrideWith((ref) async => snap),
      locationSharingEnabledStreamProvider
          .overrideWith((ref) => sharingController.stream),
    ];
  }

  group('LocationScreen 권한 안내 UI', () {
    testWidgets('서비스 꺼짐: 기기 위치 설정 CTA·가이드 문구 노출', (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(() {
        sharing.close();
        clearGeolocatorMocks();
      });
      await setGeolocatorOpenSettingsMocks();

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withError(
              '위치 서비스를 켜주세요.',
            ),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: false,
              permission: LocationPermission.denied,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(false);
      await tester.pumpAndSettle();

      expect(find.text('위치 서비스를 켜주세요.'), findsOneWidget);
      expect(find.text('위치 서비스 꺼짐'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, '기기 위치 설정 열기'),
        findsOneWidget,
      );
      expect(find.textContaining('가족 위치 공유는 기기 위치 서비스'), findsOneWidget);
    });

    testWidgets('권한 거부(denied): 앱 설정 CTA·배너 가이드 노출', (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(() {
        sharing.close();
        clearGeolocatorMocks();
      });
      await setGeolocatorOpenSettingsMocks();

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withError(
              '앱 사용 중 위치 권한이 필요합니다.',
            ),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: true,
              permission: LocationPermission.denied,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(false);
      await tester.pumpAndSettle();

      expect(find.text('위치 권한 없음'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, '앱 설정에서 권한 허용'),
        findsOneWidget,
      );
      expect(find.textContaining('위치 권한을 허용해야'), findsOneWidget);
    });

    testWidgets('앱 설정 CTA 탭 시 Geolocator.openAppSettings 호출 경로가 크래시 없이 동작',
        (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(() {
        sharing.close();
        clearGeolocatorMocks();
      });
      await setGeolocatorOpenSettingsMocks();

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withError('설정에서 위치 권한을 허용해주세요.'),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: true,
              permission: LocationPermission.deniedForever,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(false);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '앱 설정 열기'));
      await tester.pumpAndSettle();
    });

    testWidgets('기기 위치 설정 CTA 탭 시 openLocationSettings 경로가 크래시 없이 동작',
        (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(() {
        sharing.close();
        clearGeolocatorMocks();
      });
      await setGeolocatorOpenSettingsMocks();

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withError('위치 서비스를 켜주세요.'),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: false,
              permission: LocationPermission.denied,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(false);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '기기 위치 설정 열기'));
      await tester.pumpAndSettle();
    });
  });

  group('LocationScreen 공유 토글·상태 배너', () {
    testWidgets('공유 꺼짐: 스위치 off·라벨 꺼짐', (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(sharing.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withPosition(_testPosition()),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: true,
              permission: LocationPermission.always,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(false);
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byKey(const ValueKey('location_sharing_switch')));
      expect(sw.value, isFalse);
      expect(find.text('꺼짐'), findsOneWidget);
    });

    testWidgets('공유 켜짐: 토글 탭 시 저장 호출·라벨이 공유 중으로 갱신', (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(sharing.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withPosition(_testPosition()),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: true,
              permission: LocationPermission.always,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(false);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('location_sharing_switch')));
      await tester.pumpAndSettle();

      expect(repo.toggleCallCount, 1);
      expect(repo.lastToggleEnabled, isTrue);
      expect(find.text('공유 중'), findsOneWidget);
    });

    testWidgets('지도 모드: 권한 스냅샷 배너·플레이스홀더 지도 노출', (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(sharing.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withPosition(_testPosition()),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: true,
              permission: LocationPermission.whileInUse,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('location_permission_status_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('location_naver_map_placeholder')), findsOneWidget);

      final ui = buildLocationPermissionUiModel(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        platform: defaultTargetPlatform,
      );
      expect(find.text(ui.statusTitle), findsOneWidget);
      expect(find.text(ui.statusSubtitle), findsOneWidget);
    });

    testWidgets('iOS whileInUse: 항상 허용 안내·설정 CTA가 배너에 보인다', (tester) async {
      final sharing = StreamController<bool>.broadcast();
      final repo = _FakeLocationRepository(sharing);
      addTearDown(sharing.close);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            sharingController: sharing,
            repo: repo,
            initOverride: LocationScreenInitOverride.withPosition(_testPosition()),
            permissionSnapshot: const LocationPermissionSnapshot(
              serviceEnabled: true,
              permission: LocationPermission.whileInUse,
            ),
          ),
          child: const MaterialApp(home: LocationScreen()),
        ),
      );
      sharing.add(true);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('항상'),
        findsWidgets,
      );
      expect(
        find.widgetWithText(OutlinedButton, '설정에서 「항상 허용」으로 변경'),
        findsOneWidget,
      );
    });
  });
}
