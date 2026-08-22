import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/root_shell.dart';

void main() {
  runApp(const CsdoAssetApp());
}

class CsdoAssetApp extends StatelessWidget {
  const CsdoAssetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSDO Asset System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RootShell(),
    );
  }
}
