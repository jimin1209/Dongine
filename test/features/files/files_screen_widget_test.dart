import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/files/data/files_repository.dart';
import 'package:dongine/features/files/domain/files_provider.dart';
import 'package:dongine/features/files/presentation/files_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/file_item_model.dart';
import 'package:dongine/shared/models/family_model.dart';

const _testFamilyId = 'fam-files-widget';

final _testFamily = FamilyModel(
  id: _testFamilyId,
  name: '테스트 가족',
  createdBy: 'u1',
  inviteCode: 'INV1',
  createdAt: DateTime(2026, 1, 1),
);

FileItemModel _folder({
  required String id,
  required String name,
  String? parentId,
  DateTime? createdAt,
}) {
  final t = createdAt ?? DateTime(2026, 1, 1);
  return FileItemModel(
    id: id,
    name: name,
    type: 'folder',
    parentId: parentId,
    uploadedBy: 'u1',
    createdAt: t,
    updatedAt: t,
  );
}

FileItemModel _file({
  required String id,
  required String name,
  String? parentId,
  int? size,
  DateTime? createdAt,
}) {
  final t = createdAt ?? DateTime(2026, 1, 1);
  return FileItemModel(
    id: id,
    name: name,
    type: 'file',
    parentId: parentId,
    size: size,
    uploadedBy: 'u1',
    createdAt: t,
    updatedAt: t,
  );
}

/// Firebase 없이 목록·breadcrumb만 제공하는 저장소 스텁
class _FakeFilesRepository implements FilesRepository {
  _FakeFilesRepository(this._allItems);

  final List<FileItemModel> _allItems;

  Map<String?, List<FileItemModel>> get _byParent {
    final m = <String?, List<FileItemModel>>{};
    for (final i in _allItems) {
      m.putIfAbsent(i.parentId, () => []).add(i);
    }
    return m;
  }

  List<FileItemModel> _sortedAt(String? parentId) {
    final list = List<FileItemModel>.from(_byParent[parentId] ?? []);
    list.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Stream<List<FileItemModel>> getFilesStream(
      String familyId, String? parentId) {
    return Stream.value(_sortedAt(parentId));
  }

  @override
  Future<FileItemModel?> getItem(String familyId, String fileId) async {
    for (final i in _allItems) {
      if (i.id == fileId) return i;
    }
    return null;
  }

  @override
  Future<List<FileItemModel>> buildBreadcrumb(
      String familyId, String? folderId) async {
    if (folderId == null) return [];
    final path = <FileItemModel>[];
    String? currentId = folderId;
    while (currentId != null) {
      final item = await getItem(familyId, currentId);
      if (item == null) break;
      path.insert(0, item);
      currentId = item.parentId;
    }
    return path;
  }

  @override
  Future<FileItemModel> createFolder(
    String familyId,
    String name,
    String? parentId,
    String userId,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteItem(String familyId, String fileId) async {}

  @override
  Future<String> downloadFile(
    FileItemModel item, {
    void Function(double progress)? onProgress,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> getStorageUsage(String familyId) async => 0;

  @override
  Future<void> moveItem(
      String familyId, String fileId, String? newParentId) async {}

  @override
  Future<void> renameItem(
      String familyId, String fileId, String newName) async {}

  @override
  Future<FileItemModel> uploadFile(
    String familyId,
    String? parentId,
    String userId,
    String filePath,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async =>
      throw UnimplementedError();
}

List<FileItemModel> _sampleTree() {
  final folderAlpha = _folder(
    id: 'id-alpha',
    name: 'Alpha',
    createdAt: DateTime(2026, 1, 1),
  );
  final folderBeta = _folder(
    id: 'id-beta',
    name: 'Beta',
    createdAt: DateTime(2026, 3, 1),
  );
  final fileCharlie = _file(
    id: 'id-charlie',
    name: 'charlie.pdf',
    size: 500,
    createdAt: DateTime(2026, 2, 1),
  );
  final fileDelta = _file(
    id: 'id-delta',
    name: 'delta.png',
    size: 3000,
    createdAt: DateTime(2026, 4, 1),
  );
  final fileEcho = _file(
    id: 'id-echo',
    name: 'echo.txt',
    size: 100,
    createdAt: DateTime(2026, 5, 1),
  );
  final fileInner = _file(
    id: 'id-inner',
    name: 'inner-note.txt',
    parentId: 'id-alpha',
    createdAt: DateTime(2026, 1, 15),
  );
  return [
    fileDelta,
    folderBeta,
    fileCharlie,
    folderAlpha,
    fileEcho,
    fileInner,
  ];
}

/// Alpha 하위에 Beta 폴더와 파일 — 브레드크럼 상위 복귀 검증용
List<FileItemModel> _breadcrumbNestedTree() {
  final folderAlpha = _folder(
    id: 'id-alpha',
    name: 'Alpha',
    createdAt: DateTime(2026, 1, 1),
  );
  final folderBeta = _folder(
    id: 'id-beta-nested',
    name: 'BetaNested',
    parentId: 'id-alpha',
    createdAt: DateTime(2026, 2, 1),
  );
  final fileInAlpha = _file(
    id: 'id-in-alpha',
    name: 'in-alpha.txt',
    parentId: 'id-alpha',
    createdAt: DateTime(2026, 1, 10),
  );
  final fileInBeta = _file(
    id: 'id-in-beta',
    name: 'in-beta.txt',
    parentId: 'id-beta-nested',
    createdAt: DateTime(2026, 2, 10),
  );
  return [folderAlpha, folderBeta, fileInAlpha, fileInBeta];
}

/// 자식 없는 단일 폴더만 루트에 둠 — 빈 폴더 안내 UI 검증용
List<FileItemModel> _emptyLeafFolderTree() {
  return [
    _folder(
      id: 'id-empty-leaf',
      name: 'EmptyLeaf',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
}

List<Override> _filesScreenOverrides(List<FileItemModel> items) {
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    filesRepositoryProvider.overrideWithValue(_FakeFilesRepository(items)),
  ];
}

Future<void> _pumpFilesScreen(
  WidgetTester tester, {
  required List<FileItemModel> items,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _filesScreenOverrides(items),
      child: const MaterialApp(
        locale: Locale('ko'),
        home: FilesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FilesScreen 위젯 회귀', () {
    testWidgets('검색어 입력 시 목록이 검색어에 맞게 필터링된다', (tester) async {
      await _pumpFilesScreen(tester, items: _sampleTree());

      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'charlie');
      await tester.pumpAndSettle();

      expect(find.text('charlie.pdf'), findsOneWidget);
      expect(find.text('echo.txt'), findsNothing);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('정렬을 최신순으로 바꾸면 목록 순서가 갱신된다', (tester) async {
      await _pumpFilesScreen(tester, items: _sampleTree());

      await tester.tap(find.text('이름순'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('최신순'));
      await tester.pumpAndSettle();

      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text?)?.data)
          .whereType<String>()
          .toList();

      expect(titles, [
        'Beta',
        'Alpha',
        'echo.txt',
        'delta.png',
        'charlie.pdf',
      ]);
    });

    testWidgets('타입 필터에서 파일만 선택하면 폴더 행이 사라진다', (tester) async {
      await _pumpFilesScreen(tester, items: _sampleTree());

      final filesOnly = find.widgetWithText(ChoiceChip, '파일');
      await tester.ensureVisible(filesOnly);
      await tester.tap(filesOnly);
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('charlie.pdf'), findsOneWidget);
      expect(find.text('delta.png'), findsOneWidget);
      expect(find.text('echo.txt'), findsOneWidget);
    });

    testWidgets('폴더를 탭하면 breadcrumb에 해당 폴더명이 표시된다', (tester) async {
      await _pumpFilesScreen(tester, items: _sampleTree());

      expect(find.text('Alpha'), findsOneWidget);
      await tester.tap(find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(ListTile),
      ));
      await tester.pumpAndSettle();

      expect(find.text('inner-note.txt'), findsOneWidget);
      expect(find.text('홈'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('자식이 없는 폴더에 들어가면 빈 폴더 안내가 일관되게 표시된다', (tester) async {
      await _pumpFilesScreen(tester, items: _emptyLeafFolderTree());

      await tester.tap(find.ancestor(
        of: find.text('EmptyLeaf'),
        matching: find.byType(ListTile),
      ));
      await tester.pumpAndSettle();

      expect(find.text('빈 폴더입니다'), findsOneWidget);
      expect(find.text('파일을 업로드하거나 폴더를 만들어보세요!'), findsOneWidget);
      expect(find.text('검색 결과가 없습니다'), findsNothing);
    });

    testWidgets(
        '항목은 있는데 검색어로 걸러지면 검색 결과 없음 안내이고 빈 폴더 문구는 아니다',
        (tester) async {
      await _pumpFilesScreen(tester, items: _sampleTree());

      await tester.tap(find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(ListTile),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '__no_match__');
      await tester.pumpAndSettle();

      expect(find.text('검색 결과가 없습니다'), findsOneWidget);
      expect(find.text('필터 초기화'), findsOneWidget);
      expect(find.text('빈 폴더입니다'), findsNothing);
    });

    testWidgets(
        '타입 필터만으로 목록이 비면 검색 무결과 안내이고 빈 폴더 문구는 아니다',
        (tester) async {
      await _pumpFilesScreen(tester, items: _sampleTree());

      await tester.tap(find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(ListTile),
      ));
      await tester.pumpAndSettle();

      final foldersOnly = find.widgetWithText(ChoiceChip, '폴더');
      await tester.ensureVisible(foldersOnly);
      await tester.tap(foldersOnly);
      await tester.pumpAndSettle();

      expect(find.text('검색 결과가 없습니다'), findsOneWidget);
      expect(find.text('빈 폴더입니다'), findsNothing);
      expect(find.text('폴더만'), findsOneWidget);
    });

    testWidgets('하위 폴더 진입 후 브레드크럼으로 상위 폴더로 돌아오면 목록이 상위 기준으로 갱신된다',
        (tester) async {
      await _pumpFilesScreen(tester, items: _breadcrumbNestedTree());

      await tester.tap(find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(ListTile),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: find.text('BetaNested'),
        matching: find.byType(ListTile),
      ));
      await tester.pumpAndSettle();

      expect(find.text('in-beta.txt'), findsOneWidget);
      expect(find.text('in-alpha.txt'), findsNothing);

      final crumbRow = find.byKey(const Key('files_breadcrumb_row'));
      await tester.tap(
        find.descendant(of: crumbRow, matching: find.text('Alpha')),
      );
      await tester.pumpAndSettle();

      expect(find.text('in-alpha.txt'), findsOneWidget);
      expect(find.text('BetaNested'), findsOneWidget);
      expect(find.text('in-beta.txt'), findsNothing);
    });
  });
}
