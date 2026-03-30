import 'package:flutter/material.dart';
import 'package:dongine/app/router.dart';
import 'package:dongine/app/theme.dart';

class DongineApp extends StatelessWidget {
  const DongineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '동이네',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
