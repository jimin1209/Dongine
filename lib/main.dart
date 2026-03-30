import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dongine/firebase_options.dart';
import 'package:dongine/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 한국어 로케일 초기화 (TableCalendar 등에서 사용)
  await initializeDateFormatting('ko_KR');

  runApp(
    const ProviderScope(
      child: DongineApp(),
    ),
  );
}
