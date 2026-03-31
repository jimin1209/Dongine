import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// 웹에서 bytes로 업로드
UploadTask putFileOrData(
  Reference ref,
  String? filePath,
  Uint8List? bytes,
  SettableMetadata? metadata,
) {
  return ref.putData(bytes!, metadata);
}

/// 웹에서 파일 존재 확인 (bytes가 있으면 존재)
bool fileExists(String? filePath) {
  // 웹에서는 filePath 기반 확인 불가, 항상 true 반환 (bytes 확인은 호출부에서)
  return true;
}
