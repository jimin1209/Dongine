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
