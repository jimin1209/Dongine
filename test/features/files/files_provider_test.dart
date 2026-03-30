import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/files/domain/files_provider.dart';
import 'package:dongine/shared/models/file_item_model.dart';

FileItemModel _file({
  required String name,
  int? size,
  DateTime? createdAt,
}) {
  return FileItemModel(
    id: 'id-$name',
    name: name,
    type: 'file',
    size: size,
    uploadedBy: 'u1',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

FileItemModel _folder({
  required String name,
  DateTime? createdAt,
}) {
  return FileItemModel(
    id: 'id-$name',
    name: name,
    type: 'folder',
    uploadedBy: 'u1',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // ── 기본 데이터 ──
  final folderA = _folder(name: 'Alpha', createdAt: DateTime(2026, 1, 1));
  final folderB = _folder(name: 'Beta', createdAt: DateTime(2026, 3, 1));
  final fileC = _file(
      name: 'charlie.pdf', size: 500, createdAt: DateTime(2026, 2, 1));
  final fileD =
      _file(name: 'delta.png', size: 3000, createdAt: DateTime(2026, 4, 1));
  final fileE =
      _file(name: 'echo.txt', size: 100, createdAt: DateTime(2026, 5, 1));

  final allItems = [fileD, folderB, fileC, folderA, fileE];

  // ── 타입 필터 ──
  group('타입 필터', () {
    test('all: 모든 항목 반환', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.length, 5);
    });

    test('foldersOnly: 폴더만 반환', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.foldersOnly,
      );
      expect(result.every((f) => f.isFolder), true);
      expect(result.length, 2);
    });

    test('filesOnly: 파일만 반환', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.filesOnly,
      );
      expect(result.every((f) => f.isFile), true);
      expect(result.length, 3);
    });
  });

  // ── 검색 ──
  group('검색 필터', () {
    test('검색어가 비어 있으면 필터 없음', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.length, 5);
    });

    test('대소문자 무관 검색', () {
      final result = applyFilesFilters(
        items: allItems,
        query: 'CHARLIE',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.length, 1);
      expect(result.first.name, 'charlie.pdf');
    });

    test('부분 문자열 매칭', () {
      final result = applyFilesFilters(
        items: allItems,
        query: 'lph',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.length, 1);
      expect(result.first.name, 'Alpha');
    });

    test('일치하는 항목이 없으면 빈 리스트', () {
      final result = applyFilesFilters(
        items: allItems,
        query: 'nonexistent',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result, isEmpty);
    });
  });

  // ── 정렬 ──
  group('정렬', () {
    test('name: 폴더 우선, 이름 오름차순', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.map((e) => e.name).toList(),
          ['Alpha', 'Beta', 'charlie.pdf', 'delta.png', 'echo.txt']);
    });

    test('newest: 폴더 우선, 최신 순', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.newest,
        typeFilter: FilesTypeFilter.all,
      );
      // 폴더: Beta(3월) > Alpha(1월), 파일: echo(5월) > delta(4월) > charlie(2월)
      expect(result.map((e) => e.name).toList(),
          ['Beta', 'Alpha', 'echo.txt', 'delta.png', 'charlie.pdf']);
    });

    test('oldest: 폴더 우선, 오래된 순', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.oldest,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.map((e) => e.name).toList(),
          ['Alpha', 'Beta', 'charlie.pdf', 'delta.png', 'echo.txt']);
    });

    test('largest: 폴더 우선, 파일 크기 내림차순', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.largest,
        typeFilter: FilesTypeFilter.all,
      );
      final fileNames = result.where((f) => f.isFile).map((e) => e.name);
      expect(fileNames.toList(), ['delta.png', 'charlie.pdf', 'echo.txt']);
    });

    test('largest: size가 null이면 0으로 취급', () {
      final noSize = _file(name: 'nosize.bin');
      final result = applyFilesFilters(
        items: [fileD, noSize],
        query: '',
        sort: FilesSortOption.largest,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.first.name, 'delta.png');
      expect(result.last.name, 'nosize.bin');
    });
  });

  // ── 검색 + 정렬 + 필터 조합 ──
  group('조합 테스트', () {
    test('filesOnly + 검색어 + newest 정렬', () {
      final result = applyFilesFilters(
        items: allItems,
        query: '.p',
        sort: FilesSortOption.newest,
        typeFilter: FilesTypeFilter.filesOnly,
      );
      // .p 매칭: charlie.pdf, delta.png → newest: delta(4월), charlie(2월)
      expect(
          result.map((e) => e.name).toList(), ['delta.png', 'charlie.pdf']);
    });

    test('foldersOnly + 검색어', () {
      final result = applyFilesFilters(
        items: allItems,
        query: 'bet',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.foldersOnly,
      );
      expect(result.length, 1);
      expect(result.first.name, 'Beta');
    });

    test('검색어가 폴더와 파일 모두 매칭 + name 정렬시 폴더 우선', () {
      final items = [
        _file(name: 'abc-file.txt'),
        _folder(name: 'abc-folder'),
      ];
      final result = applyFilesFilters(
        items: items,
        query: 'abc',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result.first.isFolder, true);
      expect(result.last.isFile, true);
    });

    test('filesOnly + largest + 검색어로 좁힌 결과만 정렬', () {
      final result = applyFilesFilters(
        items: allItems,
        query: 'e',
        sort: FilesSortOption.largest,
        typeFilter: FilesTypeFilter.filesOnly,
      );
      // 'e' 매칭 파일: charlie.pdf(500), delta.png(3000), echo.txt(100)
      expect(result.map((e) => e.name).toList(),
          ['delta.png', 'charlie.pdf', 'echo.txt']);
    });
  });

  // ── 빈 입력 / 엣지 케이스 ──
  group('엣지 케이스', () {
    test('빈 리스트 입력시 빈 리스트 반환', () {
      final result = applyFilesFilters(
        items: [],
        query: 'anything',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.all,
      );
      expect(result, isEmpty);
    });

    test('원본 리스트를 변경하지 않음', () {
      final original = List<FileItemModel>.from(allItems);
      applyFilesFilters(
        items: allItems,
        query: '',
        sort: FilesSortOption.newest,
        typeFilter: FilesTypeFilter.filesOnly,
      );
      expect(allItems.map((e) => e.name), original.map((e) => e.name));
    });

    test('폴더만 있을 때 filesOnly 필터는 빈 리스트', () {
      final folders = [_folder(name: 'X'), _folder(name: 'Y')];
      final result = applyFilesFilters(
        items: folders,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.filesOnly,
      );
      expect(result, isEmpty);
    });

    test('파일만 있을 때 foldersOnly 필터는 빈 리스트', () {
      final files = [_file(name: 'a.txt'), _file(name: 'b.txt')];
      final result = applyFilesFilters(
        items: files,
        query: '',
        sort: FilesSortOption.name,
        typeFilter: FilesTypeFilter.foldersOnly,
      );
      expect(result, isEmpty);
    });
  });
}
