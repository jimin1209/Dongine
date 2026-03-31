import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/files/data/files_repository.dart';
import 'package:dongine/shared/models/file_item_model.dart';

import 'memory_files_repository.dart';

FileItemModel _file({
  required String id,
  required String name,
  String? parentId,
  DateTime? at,
}) {
  final t = at ?? DateTime.utc(2026, 1, 1);
  return FileItemModel(
    id: id,
    name: name,
    type: 'file',
    parentId: parentId,
    size: 10,
    uploadedBy: 'u1',
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  const familyId = 'fam-core-flow';
  const userId = 'user-1';

  group('filesMoveItemUpdateData — move Firestore 계약', () {
    test('newParentId가 null이면 parentId 필드가 null(루트)', () {
      final at = DateTime.utc(2026, 3, 15, 8, 30);
      final data = filesMoveItemUpdateData(null, at);
      expect(data.containsKey('parentId'), isTrue);
      expect(data['parentId'], isNull);
      expect(data['updatedAt'], isA<Timestamp>());
      expect((data['updatedAt'] as Timestamp).toDate(), at);
    });

    test('newParentId가 설정되면 동일 값이 parentId로 기록', () {
      final at = DateTime.utc(2026, 1, 2);
      final data = filesMoveItemUpdateData('parent-xyz', at);
      expect(data['parentId'], 'parent-xyz');
      expect((data['updatedAt'] as Timestamp).toDate(), at);
    });

    test('키 집합이 parentId·updatedAt만 포함', () {
      final data = filesMoveItemUpdateData('p1', DateTime(2026, 6, 1));
      expect(data.keys.toSet(), {'parentId', 'updatedAt'});
    });
  });

  group('MemoryFilesRepository — 폴더 생성·부모 ID', () {
    test('루트 폴더는 parentId가 null', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final folder = await repo.createFolder(familyId, 'RootBox', null, userId);
      expect(folder.parentId, isNull);
      expect(folder.type, 'folder');
      expect(folder.name, 'RootBox');
      expect(folder.uploadedBy, userId);
      final again = await repo.getItem(familyId, folder.id);
      expect(again?.parentId, isNull);
    });

    test('하위 폴더는 parentId가 부모 폴더 id', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final parent =
          await repo.createFolder(familyId, 'Parent', null, userId);
      final child =
          await repo.createFolder(familyId, 'Child', parent.id, userId);
      expect(child.parentId, parent.id);
      final stored = await repo.getItem(familyId, child.id);
      expect(stored?.parentId, parent.id);
    });
  });

  group('MemoryFilesRepository — move(파일·폴더) parentId', () {
    test('파일을 루트에서 하위 폴더로 옮기면 parentId가 바뀐다', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final folder = await repo.createFolder(familyId, 'F', null, userId);
      repo.seedItem(
        familyId,
        _file(id: 'file-1', name: 'a.txt', parentId: null),
      );
      await repo.moveItem(familyId, 'file-1', folder.id);
      final moved = await repo.getItem(familyId, 'file-1');
      expect(moved?.parentId, folder.id);
    });

    test('파일을 하위에서 루트로 옮기면 parentId가 null', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final folder = await repo.createFolder(familyId, 'Box', null, userId);
      repo.seedItem(
        familyId,
        _file(id: 'f2', name: 'b.pdf', parentId: folder.id),
      );
      await repo.moveItem(familyId, 'f2', null);
      final moved = await repo.getItem(familyId, 'f2');
      expect(moved?.parentId, isNull);
    });

    test('폴더 이동 시에도 parentId만 갱신된다', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final a = await repo.createFolder(familyId, 'A', null, userId);
      final b = await repo.createFolder(familyId, 'B', null, userId);
      final sub = await repo.createFolder(familyId, 'Sub', a.id, userId);
      await repo.moveItem(familyId, sub.id, b.id);
      final again = await repo.getItem(familyId, sub.id);
      expect(again?.parentId, b.id);
      expect(again?.name, 'Sub');
    });
  });

  group('MemoryFilesRepository — 삭제·재귀', () {
    test('파일만 삭제하면 해당 id만 제거', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      repo.seedItem(familyId, _file(id: 'x', name: 'only.txt'));
      await repo.deleteItem(familyId, 'x');
      expect(await repo.getItem(familyId, 'x'), isNull);
    });

    test('폴더 삭제 시 자손 파일·폴더가 모두 제거된다', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final root = await repo.createFolder(familyId, 'R', null, userId);
      final inner = await repo.createFolder(familyId, 'Inner', root.id, userId);
      repo.seedItem(
        familyId,
        _file(id: 'deep', name: 'n.txt', parentId: inner.id),
      );
      await repo.deleteItem(familyId, root.id);
      expect(await repo.getItem(familyId, root.id), isNull);
      expect(await repo.getItem(familyId, inner.id), isNull);
      expect(await repo.getItem(familyId, 'deep'), isNull);
    });

    test('없는 항목 삭제는 무해', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      await repo.deleteItem(familyId, 'no-such');
    });
  });

  group('MemoryFilesRepository — getFilesStream·경로', () {
    test('폴더 생성 후 루트 스트림에 반영된다', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final events = <List<FileItemModel>>[];
      final sub = repo.getFilesStream(familyId, null).listen(events.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(events.first, isEmpty);
      await repo.createFolder(familyId, 'New', null, userId);
      await pumpEventQueue();
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.length, 1);
      expect(events.last.single.name, 'New');
      expect(events.last.single.parentId, isNull);
    });

    test('buildBreadcrumb이 parentId 체인을 루트부터 반환', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final a = await repo.createFolder(familyId, 'A', null, userId);
      final b = await repo.createFolder(familyId, 'B', a.id, userId);
      final c = await repo.createFolder(familyId, 'C', b.id, userId);
      final crumbs = await repo.buildBreadcrumb(familyId, c.id);
      expect(crumbs.map((e) => e.id).toList(), [a.id, b.id, c.id]);
      expect(crumbs.first.parentId, isNull);
      expect(crumbs[1].parentId, a.id);
      expect(crumbs[2].parentId, b.id);
    });
  });

  group('createFolder toFirestore 계약(프로덕션과 동일 필드)', () {
    test('루트 폴더 맵에 parentId null', () async {
      final repo = MemoryFilesRepository();
      addTearDown(repo.dispose);
      final folder = await repo.createFolder(familyId, 'X', null, userId);
      final map = folder.toFirestore();
      expect(map['parentId'], isNull);
      expect(map['type'], 'folder');
    });
  });
}
