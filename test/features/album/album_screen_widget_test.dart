import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/album/domain/album_provider.dart';
import 'package:dongine/features/album/presentation/album_screen.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/album_model.dart';
import 'package:dongine/shared/models/family_model.dart';

const _testFamilyId = 'fam-album-widget';

final _testFamily = FamilyModel(
  id: _testFamilyId,
  name: '테스트 가족',
  createdBy: 'u1',
  inviteCode: 'INV1',
  createdAt: DateTime(2026, 1, 1),
);

List<Override> _albumScreenOverrides({
  List<AlbumModel> albums = const [],
  List<PhotoModel> timeline = const [],
}) {
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    authStateProvider.overrideWith((ref) => Stream.value(null)),
    albumsProvider.overrideWith((ref, familyId) => Stream.value(albums)),
    timelineProvider.overrideWith((ref, familyId) => Stream.value(timeline)),
  ];
}

Future<void> _pumpAlbumScreen(
  WidgetTester tester, {
  List<AlbumModel> albums = const [],
  List<PhotoModel> timeline = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _albumScreenOverrides(albums: albums, timeline: timeline),
      child: const MaterialApp(
        locale: Locale('ko'),
        home: AlbumScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AlbumScreen 위젯 회귀', () {
    testWidgets('앨범이 없을 때 empty state 문구가 표시된다', (tester) async {
      await _pumpAlbumScreen(tester);

      expect(find.text('아직 앨범이 없어요'), findsOneWidget);
      expect(find.text('+ 버튼을 눌러 첫 앨범을 만들어보세요!'), findsOneWidget);
      expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    });

    testWidgets('타임라인 탭으로 전환하면 타임라인 empty state가 표시된다',
        (tester) async {
      await _pumpAlbumScreen(tester);

      expect(find.text('아직 앨범이 없어요'), findsOneWidget);

      await tester.tap(find.text('타임라인'));
      await tester.pumpAndSettle();

      expect(find.text('아직 사진이 없어요'), findsOneWidget);
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('타임라인 탭에서 앨범 탭으로 다시 돌아올 수 있다', (tester) async {
      await _pumpAlbumScreen(tester);

      await tester.tap(find.text('타임라인'));
      await tester.pumpAndSettle();
      expect(find.text('아직 사진이 없어요'), findsOneWidget);

      await tester.tap(find.text('앨범'));
      await tester.pumpAndSettle();
      expect(find.text('아직 앨범이 없어요'), findsOneWidget);
    });

    testWidgets('FAB를 탭하면 새 앨범 만들기 다이얼로그가 열린다', (tester) async {
      await _pumpAlbumScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('새 앨범 만들기'), findsOneWidget);
      expect(find.text('앨범 이름'), findsOneWidget);
      expect(find.text('설명 (선택)'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      expect(find.text('만들기'), findsOneWidget);
    });
  });
}
