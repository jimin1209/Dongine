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

/// 웹에서 파일 크기 가져오기
Future<int> getFileSize(String? filePath, Uint8List? bytes) async {
  return bytes?.length ?? 0;
}

/// 웹에서 파일 다운로드 (다운로드 URL 반환)
Future<String> downloadToTemp(Reference ref, String fileName) async {
  // 웹에서는 writeToFile을 사용할 수 없으므로 다운로드 URL 반환
  return ref.getDownloadURL();
}
