import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/data/family_preferences.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/family_model.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-selection-uid';
}

class _StreamFamilyRepository extends Fake implements FamilyRepository {
  _StreamFamilyRepository() {
    // 단일 구독: 리스너 연결 전에 add 한 이벤트는 버퍼되어 전달된다(StreamProvider 구독 순서와 무관).
    _controller = StreamController<List<FamilyModel>>();
  }

  late final StreamController<List<FamilyModel>> _controller;

  void emit(List<FamilyModel> families) {
    if (!_controller.isClosed) {
      _controller.add(families);
    }
  }

  @override
  Stream<List<FamilyModel>> getUserFamiliesStream(String uid) =>
      _controller.stream;

  Future<void> close() => _controller.close();
}

class _RecordingFamilyPreferences extends Fake implements FamilyPreferences {
  String? storedId;
  int clearCallCount = 0;

  @override
  Future<String?> getSelectedFamilyId() async => storedId;

  @override
  Future<void> setSelectedFamilyId(String familyId) async {
    storedId = familyId;
  }

  @override
  Future<void> clearSelectedFamilyId() async {
    clearCallCount++;
    storedId = null;
  }
}

FamilyModel _family(String id) {
  return FamilyModel(
    id: id,
    name: '테스트 가족 $id',
    createdBy: 'owner',
    memberIds: const ['owner'],
    inviteCode: 'CODE$id',
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<AsyncValue<String?>> _readCurrentFamilyIdWhenResolved(
  ProviderContainer container,
) async {
  for (var i = 0; i < 200; i++) {
    final v = container.read(currentFamilyIdProvider);
    if (v.hasValue) return v;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('currentFamilyIdProvider did not resolve to a value');
}

Future<AsyncValue<String?>> _waitForCurrentFamilyId(
  ProviderContainer container,
  bool Function(AsyncValue<String?> value) matches,
) async {
  for (var i = 0; i < 200; i++) {
    final v = container.read(currentFamilyIdProvider);
    if (matches(v)) return v;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('currentFamilyIdProvider did not reach the expected state');
}

Future<void> _waitUntilSelectedNotLoading(ProviderContainer container) async {
  for (var i = 0; i < 200; i++) {
    final v = container.read(selectedFamilyControllerProvider);
    if (!v.isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('selectedFamilyControllerProvider stayed loading');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('currentFamilyIdProvider – 선택/보정 회귀', () {
    test('저장된 가족 ID가 없으면 첫 가족 ID로 동기화된다', () async {
      final repo = _StreamFamilyRepository();
      final prefs = _RecordingFamilyPreferences()..storedId = null;

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          familyRepositoryProvider.overrideWithValue(repo),
          familyPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.close();
      });

      final first = _family('fam-first');
      repo.emit([first, _family('fam-second')]);

      await _waitUntilSelectedNotLoading(container);
      final resolved = await _readCurrentFamilyIdWhenResolved(container);
      expect(resolved.valueOrNull, first.id);

      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(prefs.storedId, first.id);
    });

    test('저장된 가족 ID가 목록에 없으면 첫 가족으로 자동 보정된다', () async {
      final repo = _StreamFamilyRepository();
      final prefs = _RecordingFamilyPreferences()
        ..storedId = 'deleted-family-id';

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          familyRepositoryProvider.overrideWithValue(repo),
          familyPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.close();
      });

      final survivor = _family('fam-survivor');
      repo.emit([survivor]);

      await _waitUntilSelectedNotLoading(container);
      final resolved = await _readCurrentFamilyIdWhenResolved(container);
      expect(resolved.valueOrNull, survivor.id);

      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(prefs.storedId, survivor.id);
    });

    test('가족 목록이 비면 currentFamilyId는 null이 되고 선택이 정리된다', () async {
      final repo = _StreamFamilyRepository();
      final prefs = _RecordingFamilyPreferences()..storedId = 'fam-a';

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          familyRepositoryProvider.overrideWithValue(repo),
          familyPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.close();
      });

      repo.emit([_family('fam-a')]);

      await _waitUntilSelectedNotLoading(container);
      await _readCurrentFamilyIdWhenResolved(container);
      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(prefs.storedId, 'fam-a');

      repo.emit(const <FamilyModel>[]);

      final afterEmpty = await _waitForCurrentFamilyId(
        container,
        (value) => value.hasValue && value.valueOrNull == null,
      );
      expect(afterEmpty.valueOrNull, isNull);

      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(prefs.clearCallCount, greaterThanOrEqualTo(1));
      expect(prefs.storedId, isNull);
      expect(
        container.read(selectedFamilyControllerProvider).valueOrNull,
        isNull,
      );
    });

    test('선택 중이던 가족이 목록에서 빠지면 남은 가족으로 선택이 보정된다', () async {
      final repo = _StreamFamilyRepository();
      final prefs = _RecordingFamilyPreferences()..storedId = 'fam-b';

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          familyRepositoryProvider.overrideWithValue(repo),
          familyPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.close();
      });

      final famA = _family('fam-a');
      final famB = _family('fam-b');
      repo.emit([famA, famB]);

      await _waitUntilSelectedNotLoading(container);
      await _readCurrentFamilyIdWhenResolved(container);
      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(container.read(currentFamilyIdProvider).valueOrNull, 'fam-b');

      repo.emit([famA]);

      final afterLeave = await _waitForCurrentFamilyId(
        container,
        (value) => value.hasValue && value.valueOrNull == 'fam-a',
      );
      expect(afterLeave.valueOrNull, 'fam-a');

      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(prefs.storedId, 'fam-a');
    });

    test('수동 selectFamily 로 다른 가족을 고르면 current 가 그 id 로 유지된다',
        () async {
      final repo = _StreamFamilyRepository();
      final prefs = _RecordingFamilyPreferences()..storedId = 'fam-a';

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          familyRepositoryProvider.overrideWithValue(repo),
          familyPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.close();
      });

      repo.emit([_family('fam-a'), _family('fam-b')]);

      await _waitUntilSelectedNotLoading(container);
      await _readCurrentFamilyIdWhenResolved(container);
      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(container.read(currentFamilyIdProvider).valueOrNull, 'fam-a');

      await container
          .read(selectedFamilyControllerProvider.notifier)
          .selectFamily('fam-b');
      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      final switched = await _waitForCurrentFamilyId(
        container,
        (value) => value.hasValue && value.valueOrNull == 'fam-b',
      );
      expect(switched.valueOrNull, 'fam-b');
      expect(prefs.storedId, 'fam-b');
    });

    test('맨 앞 가족을 나가 목록이 한 개로 줄면 그 가족이 현재 선택으로 유지된다',
        () async {
      final repo = _StreamFamilyRepository();
      final prefs = _RecordingFamilyPreferences()..storedId = 'fam-a';

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          familyRepositoryProvider.overrideWithValue(repo),
          familyPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.close();
      });

      final famA = _family('fam-a');
      final famB = _family('fam-b');
      repo.emit([famA, famB]);

      await _waitUntilSelectedNotLoading(container);
      await _readCurrentFamilyIdWhenResolved(container);
      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(container.read(currentFamilyIdProvider).valueOrNull, 'fam-a');

      repo.emit([famB]);

      final after = await _waitForCurrentFamilyId(
        container,
        (value) => value.hasValue && value.valueOrNull == 'fam-b',
      );
      expect(after.valueOrNull, 'fam-b');

      await _flushMicrotasks();
      await _waitUntilSelectedNotLoading(container);

      expect(prefs.storedId, 'fam-b');
    });
  });
}
