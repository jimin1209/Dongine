import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dongine/core/constants/app_constants.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/location/data/location_repository.dart';
import 'package:dongine/shared/models/location_model.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

/// Geolocator 스냅샷(설정 복귀 후 `invalidate`로 갱신).
final locationPermissionSnapshotProvider =
    FutureProvider.autoDispose<LocationPermissionSnapshot>((ref) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  final permission = await Geolocator.checkPermission();
  return LocationPermissionSnapshot(
    serviceEnabled: serviceEnabled,
    permission: permission,
  );
});

/// 기기 위치 서비스 및 앱 위치 권한(요청 없이 조회만).
class LocationPermissionSnapshot {
  const LocationPermissionSnapshot({
    required this.serviceEnabled,
    required this.permission,
  });

  final bool serviceEnabled;
  final LocationPermission permission;

  bool get hasUsablePermission =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  /// `FamilyLocationTracker._locationSettings`와 동일한 기준: iOS는 always일 때만 백그라운드 갱신 플래그를 켠다.
  bool get isBackgroundSharingFullySupported => computeBackgroundSupport(
        isWeb: kIsWeb,
        serviceEnabled: serviceEnabled,
        permission: permission,
        platform: defaultTargetPlatform,
      );

  /// 플랫폼·권한 조합에서 백그라운드 위치 공유가 완전히 지원되는지 판정하는 순수 함수.
  static bool computeBackgroundSupport({
    required bool isWeb,
    required bool serviceEnabled,
    required LocationPermission permission,
    required TargetPlatform platform,
  }) {
    if (isWeb) return false;
    final usable = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (!serviceEnabled || !usable) return false;
    if (platform == TargetPlatform.iOS) {
      return permission == LocationPermission.always;
    }
    return true;
  }
}

/// 위치 공유·설정 CTA용 UI 문구(플랫폼별 분기는 테스트에서 검증).
class LocationPermissionUiModel {
  const LocationPermissionUiModel({
    required this.statusTitle,
    required this.statusSubtitle,
    required this.bannerMessage,
    required this.showBanner,
    required this.openAppSettingsCtaLabel,
    required this.openLocationSettingsCtaLabel,
    required this.showOpenAppSettingsCta,
    required this.showOpenLocationSettingsCta,
  });

  final String statusTitle;
  final String statusSubtitle;

  final String? bannerMessage;
  final bool showBanner;

  final String openAppSettingsCtaLabel;
  final String openLocationSettingsCtaLabel;
  final bool showOpenAppSettingsCta;
  final bool showOpenLocationSettingsCta;
}

LocationPermissionUiModel buildLocationPermissionUiModel({
  required bool serviceEnabled,
  required LocationPermission permission,
  required TargetPlatform platform,
}) {
  if (!serviceEnabled) {
    return const LocationPermissionUiModel(
      statusTitle: '위치 서비스 꺼짐',
      statusSubtitle: '기기에서 위치(GPS)를 켠 뒤 다시 시도해 주세요.',
      bannerMessage:
          '가족 위치 공유는 기기 위치 서비스가 켜져 있어야 합니다. 설정에서 위치를 켜 주세요.',
      showBanner: true,
      openAppSettingsCtaLabel: '앱 설정 열기',
      openLocationSettingsCtaLabel: '기기 위치 설정 열기',
      showOpenAppSettingsCta: false,
      showOpenLocationSettingsCta: true,
    );
  }

  switch (permission) {
    case LocationPermission.denied:
      return const LocationPermissionUiModel(
        statusTitle: '위치 권한 없음',
        statusSubtitle: '지도와 위치 공유를 위해 위치 접근을 허용해 주세요.',
        bannerMessage:
            '위치 권한을 허용해야 내 위치와 가족 공유가 동작합니다. 앱 설정에서 위치를 허용해 주세요.',
        showBanner: true,
        openAppSettingsCtaLabel: '앱 설정에서 권한 허용',
        openLocationSettingsCtaLabel: '기기 위치 설정 열기',
        showOpenAppSettingsCta: true,
        showOpenLocationSettingsCta: false,
      );
    case LocationPermission.deniedForever:
      return const LocationPermissionUiModel(
        statusTitle: '위치 권한 거부됨',
        statusSubtitle: '설정에서 이 앱의 위치 접근을 허용해야 합니다.',
        bannerMessage:
            '위치 권한이 꺼져 있습니다. 앱 설정에서 위치를 허용한 뒤 돌아와 주세요.',
        showBanner: true,
        openAppSettingsCtaLabel: '앱 설정 열기',
        openLocationSettingsCtaLabel: '기기 위치 설정 열기',
        showOpenAppSettingsCta: true,
        showOpenLocationSettingsCta: false,
      );
    case LocationPermission.unableToDetermine:
      return const LocationPermissionUiModel(
        statusTitle: '위치 권한 확인 불가',
        statusSubtitle: '잠시 후 다시 시도하거나 설정에서 위치 권한을 확인해 주세요.',
        bannerMessage: null,
        showBanner: false,
        openAppSettingsCtaLabel: '앱 설정 열기',
        openLocationSettingsCtaLabel: '기기 위치 설정 열기',
        showOpenAppSettingsCta: true,
        showOpenLocationSettingsCta: true,
      );
    case LocationPermission.whileInUse:
      if (platform == TargetPlatform.iOS) {
        return const LocationPermissionUiModel(
          statusTitle: '위치: 앱 사용 중만 허용',
          statusSubtitle:
              '앱이 백그라운드에 있을 때는 iOS가 위치 갱신을 제한할 수 있습니다.',
          bannerMessage:
              '백그라운드에서도 갱신하려면 설정에서 이 앱의 위치를 「항상」으로 바꿔 주세요.',
          showBanner: true,
          openAppSettingsCtaLabel: '설정에서 「항상 허용」으로 변경',
          openLocationSettingsCtaLabel: '기기 위치 설정 열기',
          showOpenAppSettingsCta: true,
          showOpenLocationSettingsCta: false,
        );
      }
      return const LocationPermissionUiModel(
        statusTitle: '위치: 앱 사용 중 허용',
        statusSubtitle:
            '전면 위치 알림이 표시되는 동안 백그라운드 갱신이 가능합니다. 기기마다 「항상 허용」이 더 안정적일 수 있습니다.',
        bannerMessage:
            '일부 기기에서는 백그라운드 공유가 더 잘 되도록 위치를 「항상 허용」으로 두는 것이 좋습니다.',
        showBanner: true,
        openAppSettingsCtaLabel: '앱 위치 권한 설정',
        openLocationSettingsCtaLabel: '기기 위치 설정 열기',
        showOpenAppSettingsCta: true,
        showOpenLocationSettingsCta: false,
      );
    case LocationPermission.always:
      return const LocationPermissionUiModel(
        statusTitle: '위치: 항상 허용',
        statusSubtitle: '앱이 백그라운드에 있을 때도 위치 갱신이 가능한 권한입니다.',
        bannerMessage: null,
        showBanner: false,
        openAppSettingsCtaLabel: '앱 설정 열기',
        openLocationSettingsCtaLabel: '기기 위치 설정 열기',
        showOpenAppSettingsCta: false,
        showOpenLocationSettingsCta: false,
      );
  }
}

final familyLocationsProvider =
    StreamProvider.family<List<LocationModel>, String>((ref, familyId) {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getFamilyLocationsStream(familyId);
});

/// Firestore `families/{id}/members/{uid}` 의 `locationSharingEnabled` 실시간 반영.
/// 로그인 전·가족 미선택·로딩·오류 시 `Stream.value(false)` 로 보수적으로 처리한다.
final locationSharingEnabledStreamProvider = StreamProvider<bool>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final familyAsync = ref.watch(currentFamilyProvider);

  return authAsync.when(
    data: (user) {
      if (user == null) return Stream.value(false);
      return familyAsync.when(
        data: (family) {
          if (family == null) return Stream.value(false);
          return ref
              .read(locationRepositoryProvider)
              .watchLocationSharingEnabled(family.id, user.uid);
        },
        loading: () => Stream.value(false),
        error: (error, stackTrace) => Stream.value(false),
      );
    },
    loading: () => Stream.value(false),
    error: (error, stackTrace) => Stream.value(false),
  );
});

/// 멤버 문서와 동기화된 공유 여부(추적 bootstrap·화면에서 공통 사용).
final locationSharingEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(locationSharingEnabledStreamProvider);
  return async.when(
    data: (enabled) => enabled,
    loading: () => false,
    error: (error, stackTrace) => false,
  );
});

/// 전역 위치 추적에서 마지막으로 수신한 좌표(지도·내 위치 버튼 동기화용).
final lastTrackedPositionProvider = StateProvider<Position?>((ref) => null);

/// `MainShell`에서 watch 하여 로그인·가족·공유 토글에 맞춰 백그라운드까지 추적을 유지한다.
final familyLocationTrackingBootstrapProvider = Provider<void>((ref) {
  final tracker = FamilyLocationTracker(ref);
  ref.onDispose(tracker.dispose);

  void schedule() => tracker.sync();

  schedule();
  ref.listen(locationSharingEnabledStreamProvider, (previous, next) => schedule());
  ref.listen(authStateProvider, (previous, next) => schedule());
  ref.listen(currentFamilyProvider, (previous, next) => schedule());

  return;
});

class FamilyLocationTracker {
  FamilyLocationTracker(this._ref);

  final Ref _ref;
  StreamSubscription<Position>? _subscription;
  DateTime? _lastFirestoreUploadAt;
  String? _activeSessionKey;
  Future<void> _syncSequential = Future.value();

  void dispose() {
    _stopInternal();
  }

  void sync() {
    _syncSequential = _syncSequential.then((_) => _syncImpl());
  }

  void _stopInternal() {
    _subscription?.cancel();
    _subscription = null;
    _lastFirestoreUploadAt = null;
    _activeSessionKey = null;
    _ref.read(lastTrackedPositionProvider.notifier).state = null;
  }

  Future<void> _syncImpl() async {
    final sharing = _ref.read(locationSharingEnabledProvider);
    final user = _ref.read(authStateProvider).valueOrNull;
    final family = _ref.read(currentFamilyProvider).valueOrNull;

    if (!sharing || user == null || family == null) {
      _stopInternal();
      return;
    }

    final sessionKey = '${user.uid}|${family.id}';
    if (_subscription != null && _activeSessionKey == sessionKey) {
      return;
    }

    _activeSessionKey = sessionKey;
    _subscription?.cancel();
    _subscription = null;
    _lastFirestoreUploadAt = null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _stopInternal();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _stopInternal();
      return;
    }

    final settings = _locationSettings(permission);
    final stream = Geolocator.getPositionStream(locationSettings: settings);

    _subscription = stream.listen(
      (position) {
        unawaited(_handlePosition(position));
      },
      onError: (Object e, _) {
        debugPrint('가족 위치 스트림 오류: $e');
      },
    );
  }

  Future<void> _handlePosition(Position position) async {
    final sharing = _ref.read(locationSharingEnabledProvider);
    final user = _ref.read(authStateProvider).valueOrNull;
    final family = _ref.read(currentFamilyProvider).valueOrNull;

    if (!sharing || user == null || family == null) {
      _stopInternal();
      return;
    }

    _ref.read(lastTrackedPositionProvider.notifier).state = position;

    final now = DateTime.now();
    final minGap = Duration(seconds: AppConstants.locationUpdateIntervalSeconds);
    if (_lastFirestoreUploadAt != null &&
        now.difference(_lastFirestoreUploadAt!) < minGap) {
      return;
    }
    _lastFirestoreUploadAt = now;

    try {
      await _ref.read(locationRepositoryProvider).updateLocation(
            family.id,
            user.uid,
            position.latitude,
            position.longitude,
            accuracy: position.accuracy,
          );
    } catch (e, _) {
      debugPrint('가족 위치 Firestore 업로드 실패: $e');
    }
  }

  LocationSettings _locationSettings(LocationPermission permission) {
    final interval =
        Duration(seconds: AppConstants.locationUpdateIntervalSeconds);
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: AppConstants.appName,
          notificationText: '가족 위치를 공유하는 중입니다.',
          notificationChannelName: '가족 위치 공유',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final allowBg = permission == LocationPermission.always;
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: allowBg,
        allowBackgroundLocationUpdates: allowBg,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }
}
