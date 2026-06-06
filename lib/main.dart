import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const OrbixApp());
}

class OrbixApp extends StatelessWidget {
  const OrbixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Orbix',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system, // 跟随系统明暗
      // 给 Cupertino 控件一个与 Material 一致的亮度，避免默认配色各走各的
      builder: (context, child) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: CupertinoColors.activeBlue,
        ),
        child: child!,
      ),
      home: const SplashScreen(), // 启动决策：自动登录 / 欢迎页 / 登录页
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      primaryColor: CupertinoColors.activeBlue,
    );
  }
}
