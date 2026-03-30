import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/location/domain/location_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // locationSharingEnabledProvider — 스트림 → 동기 bool 변환 검증
  // ---------------------------------------------------------------------------
  group('locationSharingEnabledProvider', () {
    test('스트림이 true를 방출하면 provider도 true', () async {
      final container = ProviderContainer(
        overrides: [
          locationSharingEnabledStreamProvider
              .overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);

      // 스트림이 전파될 때까지 대기
      await container.read(locationSharingEnabledStreamProvider.future);
      expect(container.read(locationSharingEnabledProvider), isTrue);
    });

    test('스트림이 false를 방출하면 provider도 false', () async {
      final container = ProviderContainer(
        overrides: [
          locationSharingEnabledStreamProvider
              .overrideWith((ref) => Stream.value(false)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(locationSharingEnabledStreamProvider.future);
      expect(container.read(locationSharingEnabledProvider), isFalse);
    });

    test('스트림이 아직 로딩 중이면 provider는 false', () {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          locationSharingEnabledStreamProvider
              .overrideWith((ref) => controller.stream),
        ],
      );
      addTearDown(container.dispose);

      // 아직 값을 방출하지 않았으므로 loading 상태
      expect(container.read(locationSharingEnabledProvider), isFalse);
    });

    test('스트림이 에러를 방출하면 provider는 false', () async {
      final container = ProviderContainer(
        overrides: [
          locationSharingEnabledStreamProvider
              .overrideWith((ref) => Stream.error(Exception('test'))),
        ],
      );
      addTearDown(container.dispose);

      // 에러가 전파될 때까지 잠시 대기
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationSharingEnabledProvider), isFalse);
    });

    test('스트림 값이 true→false로 바뀌면 provider도 동기화된다', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          locationSharingEnabledStreamProvider
              .overrideWith((ref) => controller.stream),
        ],
      );
      addTearDown(container.dispose);

      // 구독 활성화
      container.listen(locationSharingEnabledProvider, (prev, next) {});

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationSharingEnabledProvider), isTrue);

      controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationSharingEnabledProvider), isFalse);
    });

    test('스트림 값이 false→true로 바뀌면 provider도 동기화된다', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          locationSharingEnabledStreamProvider
              .overrideWith((ref) => controller.stream),
        ],
      );
      addTearDown(container.dispose);

      container.listen(locationSharingEnabledProvider, (prev, next) {});

      controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationSharingEnabledProvider), isFalse);

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationSharingEnabledProvider), isTrue);
    });
  });
}
