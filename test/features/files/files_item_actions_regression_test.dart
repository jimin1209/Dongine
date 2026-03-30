import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/files/domain/files_provider.dart';
import 'package:dongine/shared/models/file_item_model.dart';

// ── 테스트 헬퍼 ──

FileItemModel _folder({
  required String id,
  required String name,
  String? parentId,
}) {
  return FileItemModel(
    id: id,
    name: name,
    type: 'folder',
    parentId: parentId,
    uploadedBy: 'u1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

FileItemModel _file({
  required String id,
  required String name,
  String? parentId,
  int? size,
  String? mimeType,
}) {
  return FileItemModel(
    id: id,
    name: name,
    type: 'file',
    parentId: parentId,
    size: size,
    mimeType: mimeType,
    uploadedBy: 'u1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  // 1. Breadcrumb 탐색 & 폴더 전환
  // ═══════════════════════════════════════════════════════════════

  group('computeNavigateBackTarget — breadcrumb 뒤로가기', () {
    test('breadcrumb이 비어 있으면 루트(null) 반환', () {
      expect(computeNavigateBackTarget([]), isNull);
    });

    test('breadcrumb이 1개(현재 폴더만)이면 루트(null) 반환', () {
      final crumbs = [_folder(id: 'f1', name: 'Docs')];
      expect(computeNavigateBackTarget(crumbs), isNull);
    });

    test('breadcrumb이 2개이면 첫 번째 폴더 ID 반환', () {
      final crumbs = [
        _folder(id: 'f1', name: 'Docs'),
        _folder(id: 'f2', name: 'Work', parentId: 'f1'),
      ];
      expect(computeNavigateBackTarget(crumbs), 'f1');
    });

    test('breadcrumb이 3개 이상이면 마지막에서 두 번째 ID 반환', () {
      final crumbs = [
        _folder(id: 'root', name: 'Root'),
        _folder(id: 'mid', name: 'Middle', parentId: 'root'),
        _folder(id: 'leaf', name: 'Leaf', parentId: 'mid'),
      ];
      expect(computeNavigateBackTarget(crumbs), 'mid');
    });

    test('깊은 중첩(5단계)에서도 직전 폴더를 정확히 반환', () {
      final crumbs = List.generate(
        5,
        (i) => _folder(
          id: 'f$i',
          name: 'Folder$i',
          parentId: i > 0 ? 'f${i - 1}' : null,
        ),
      );
      expect(computeNavigateBackTarget(crumbs), 'f3');
    });
  });

  group('breadcrumb 기반 폴더 전환 시나리오', () {
    test('루트에서 하위 폴더 진입 후 뒤로가기하면 루트 복귀', () {
      // 시뮬레이션: 루트 → f1 진입 → breadcrumb [f1]
      final crumbs = [_folder(id: 'f1', name: 'Photos')];
      final target = computeNavigateBackTarget(crumbs);
      expect(target, isNull, reason: '루트로 돌아가야 함');
    });

    test('2단계 진입 후 뒤로가기 → 1단계로 복귀', () {
      final crumbs = [
        _folder(id: 'f1', name: 'Photos'),
        _folder(id: 'f2', name: '2024', parentId: 'f1'),
      ];
      final target = computeNavigateBackTarget(crumbs);
      expect(target, 'f1');
    });

    test('breadcrumb 중간 항목 클릭 시나리오 — 해당 폴더 ID 사용', () {
      // UI에서는 breadcrumbs[i].id를 currentFolderProvider에 직접 설정
      // 여기서는 모델의 ID가 올바르게 설정되어 있는지 검증
      final crumbs = [
        _folder(id: 'a', name: 'A'),
        _folder(id: 'b', name: 'B', parentId: 'a'),
        _folder(id: 'c', name: 'C', parentId: 'b'),
      ];
      // 중간(B) 클릭 시 사용할 ID
      expect(crumbs[1].id, 'b');
      // 홈 클릭 시 null 설정 (루트)
      expect(crumbs[0].parentId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 2. 이름 변경 (Rename) 회귀 테스트
  // ═══════════════════════════════════════════════════════════════

  group('validateRename — 이름 변경 검증', () {
    test('유효한 새 이름이면 trimmed 값 반환', () {
      expect(validateRename('old.txt', 'new.txt'), 'new.txt');
    });

    test('앞뒤 공백이 있어도 trim 후 반환', () {
      expect(validateRename('old.txt', '  new.txt  '), 'new.txt');
    });

    test('빈 문자열이면 null 반환', () {
      expect(validateRename('old.txt', ''), isNull);
    });

    test('공백만 입력하면 null 반환', () {
      expect(validateRename('old.txt', '   '), isNull);
    });

    test('현재 이름과 동일하면 null 반환', () {
      expect(validateRename('same.txt', 'same.txt'), isNull);
    });

    test('현재 이름과 동일하지만 공백 포함 → trim 후 동일이면 null', () {
      expect(validateRename('same.txt', '  same.txt  '), isNull);
    });

    test('대소문자만 다르면 유효한 변경으로 인정', () {
      expect(validateRename('readme.md', 'README.md'), 'README.md');
    });

    test('확장자 변경도 유효', () {
      expect(validateRename('photo.jpg', 'photo.png'), 'photo.png');
    });

    test('한글 이름 변경', () {
      expect(validateRename('문서.pdf', '새문서.pdf'), '새문서.pdf');
    });

    test('특수문자 포함 이름', () {
      expect(validateRename('a.txt', 'a (1).txt'), 'a (1).txt');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 3. 삭제 (Delete) 회귀 테스트
  // ═══════════════════════════════════════════════════════════════

  group('deleteConfirmMessage — 삭제 확인 메시지', () {
    test('파일 삭제 메시지에 파일명 포함', () {
      final item = _file(id: 'f1', name: 'report.pdf');
      final msg = deleteConfirmMessage(item);
      expect(msg, contains('파일'));
      expect(msg, contains('report.pdf'));
      expect(msg, isNot(contains('폴더 안의 모든 파일')));
    });

    test('폴더 삭제 메시지에 재귀 삭제 경고 포함', () {
      final item = _folder(id: 'd1', name: 'Photos');
      final msg = deleteConfirmMessage(item);
      expect(msg, contains('폴더'));
      expect(msg, contains('Photos'));
      expect(msg, contains('폴더 안의 모든 파일도 함께 삭제됩니다'));
    });

    test('파일 삭제 메시지에 "삭제하시겠습니까?" 포함', () {
      final item = _file(id: 'f1', name: 'test.txt');
      expect(deleteConfirmMessage(item), contains('삭제하시겠습니까?'));
    });

    test('폴더 삭제 메시지에도 "삭제하시겠습니까?" 포함', () {
      final item = _folder(id: 'd1', name: 'Docs');
      expect(deleteConfirmMessage(item), contains('삭제하시겠습니까?'));
    });

    test('특수문자가 포함된 이름도 그대로 표시', () {
      final item = _file(id: 'f1', name: 'file (사본).txt');
      final msg = deleteConfirmMessage(item);
      expect(msg, contains('file (사본).txt'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 4. 이동 대상 폴더 필터링 (Move)
  // ═══════════════════════════════════════════════════════════════

  group('filterMoveTargets — 이동 대상 폴더 필터링', () {
    test('자기 자신을 제외하고 폴더만 반환', () {
      final items = [
        _folder(id: 'd1', name: 'Docs'),
        _folder(id: 'd2', name: 'Photos'),
        _file(id: 'f1', name: 'readme.txt'),
      ];
      final result = filterMoveTargets(items, 'd1');
      expect(result.length, 1);
      expect(result.first.id, 'd2');
    });

    test('파일만 있으면 빈 리스트 반환', () {
      final items = [
        _file(id: 'f1', name: 'a.txt'),
        _file(id: 'f2', name: 'b.txt'),
      ];
      expect(filterMoveTargets(items, 'f1'), isEmpty);
    });

    test('빈 목록이면 빈 리스트 반환', () {
      expect(filterMoveTargets([], 'any'), isEmpty);
    });

    test('자기 자신만 있는 폴더 목록이면 빈 리스트', () {
      final items = [_folder(id: 'self', name: 'Self')];
      expect(filterMoveTargets(items, 'self'), isEmpty);
    });

    test('자기 자신이 아닌 모든 폴더 반환', () {
      final items = [
        _folder(id: 'd1', name: 'A'),
        _folder(id: 'd2', name: 'B'),
        _folder(id: 'd3', name: 'C'),
        _file(id: 'f1', name: 'file.txt'),
      ];
      final result = filterMoveTargets(items, 'd2');
      expect(result.map((f) => f.id).toList(), ['d1', 'd3']);
    });

    test('excludeId가 파일 ID여도 폴더만 반환', () {
      final items = [
        _folder(id: 'd1', name: 'Docs'),
        _file(id: 'f1', name: 'test.txt'),
      ];
      final result = filterMoveTargets(items, 'f1');
      expect(result.length, 1);
      expect(result.first.id, 'd1');
    });

    test('이동 대상에 파일이 섞여 있어도 폴더만 필터링', () {
      final items = [
        _folder(id: 'd1', name: 'Folder1'),
        _file(id: 'f1', name: 'File1'),
        _folder(id: 'd2', name: 'Folder2'),
        _file(id: 'f2', name: 'File2'),
        _folder(id: 'd3', name: 'Folder3'),
      ];
      final result = filterMoveTargets(items, 'd2');
      expect(result.length, 2);
      expect(result.every((f) => f.isFolder), true);
      expect(result.any((f) => f.id == 'd2'), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 5. 통합 시나리오 — 복합 액션 흐름
  // ═══════════════════════════════════════════════════════════════

  group('통합 시나리오', () {
    test('폴더 진입 → 파일 이름 변경 → 뒤로가기 흐름', () {
      // 1. 루트 → "Docs" 진입 (breadcrumb: [Docs])
      final crumbsAfterEnter = [_folder(id: 'docs', name: 'Docs')];

      // 2. Docs 안의 파일 이름 변경
      final renamed = validateRename('old_report.pdf', '  new_report.pdf  ');
      expect(renamed, 'new_report.pdf');

      // 3. 뒤로가기 → 루트
      expect(computeNavigateBackTarget(crumbsAfterEnter), isNull);
    });

    test('깊은 폴더에서 삭제 후 이동 대상 확인', () {
      // breadcrumb: Root > Photos > 2024
      final crumbs = [
        _folder(id: 'photos', name: 'Photos'),
        _folder(id: '2024', name: '2024', parentId: 'photos'),
      ];

      // 삭제 확인 메시지
      final target = _file(id: 'pic1', name: 'sunset.jpg', parentId: '2024');
      expect(deleteConfirmMessage(target), contains('sunset.jpg'));

      // 이동 대상 폴더 (같은 레벨의 다른 폴더들)
      final siblings = [
        _folder(id: '2024', name: '2024', parentId: 'photos'),
        _folder(id: '2025', name: '2025', parentId: 'photos'),
        _file(id: 'pic2', name: 'other.jpg', parentId: 'photos'),
      ];
      final moveTargets = filterMoveTargets(siblings, '2024');
      expect(moveTargets.length, 1);
      expect(moveTargets.first.name, '2025');

      // 뒤로가기
      expect(computeNavigateBackTarget(crumbs), 'photos');
    });

    test('이름 변경 실패 케이스 연속 검증', () {
      // 빈 입력 → 동일 이름 → 유효한 이름 순서
      expect(validateRename('doc.txt', ''), isNull);
      expect(validateRename('doc.txt', 'doc.txt'), isNull);
      expect(validateRename('doc.txt', 'doc_v2.txt'), 'doc_v2.txt');
    });

    test('폴더와 파일의 삭제 메시지 차이 확인', () {
      final folder = _folder(id: 'd1', name: 'Archive');
      final file = _file(id: 'f1', name: 'data.csv');

      final folderMsg = deleteConfirmMessage(folder);
      final fileMsg = deleteConfirmMessage(file);

      // 폴더만 재귀 삭제 경고
      expect(folderMsg, contains('폴더 안의 모든 파일'));
      expect(fileMsg, isNot(contains('폴더 안의 모든 파일')));

      // 둘 다 삭제 확인 포함
      expect(folderMsg, contains('삭제하시겠습니까?'));
      expect(fileMsg, contains('삭제하시겠습니까?'));
    });
  });
}
