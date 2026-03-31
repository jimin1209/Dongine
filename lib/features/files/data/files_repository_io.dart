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

/// 모바일에서 파일 크기 가져오기
Future<int> getFileSize(String? filePath, Uint8List? bytes) async {
  return File(filePath!).length();
}

/// 모바일에서 파일 다운로드
Future<String> downloadToTemp(Reference ref, String fileName) async {
  final tempDir = Directory.systemTemp;
  final localFile = File('${tempDir.path}/$fileName');
  await ref.writeToFile(localFile);
  return localFile.path;
}
