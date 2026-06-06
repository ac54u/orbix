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
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        primaryColor: CupertinoColors.activeBlue,
      ),
      home: const SplashScreen(), // 启动决策：自动登录 / 欢迎页 / 登录页
      debugShowCheckedModeBanner: false,
    );
  }
}
