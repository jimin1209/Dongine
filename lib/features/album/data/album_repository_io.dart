import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// 모바일/데스크톱에서 File 객체로 업로드
UploadTask putFileOrData(
  Reference ref,
  String? filePath,
  Uint8List? bytes,
  SettableMetadata? metadata,
) {
  return ref.putFile(File(filePath!), metadata);
}

/// 모바일에서 파일 존재 확인
bool fileExists(String? filePath) {
  if (filePath == null) return false;
  return File(filePath).existsSync();
}
