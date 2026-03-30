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

final locationSharingEnabledProvider = StateProvider<bool>((ref) => true);

/// 전역 위치 추적에서 마지막으로 수신한 좌표(지도·내 위치 버튼 동기화용).
final lastTrackedPositionProvider = StateProvider<Position?>((ref) => null);

/// `MainShell`에서 watch 하여 로그인·가족·공유 토글에 맞춰 백그라운드까지 추적을 유지한다.
final familyLocationTrackingBootstrapProvider = Provider<void>((ref) {
  final tracker = FamilyLocationTracker(ref);
  ref.onDispose(tracker.dispose);

  void schedule() => tracker.sync();

  schedule();
  ref.listen(locationSharingEnabledProvider, (previous, next) => schedule());
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
