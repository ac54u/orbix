import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/app_lock_gate.dart';

void main() {
  runApp(const OrbixApp());
}

class OrbixApp extends StatelessWidget {
  const OrbixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetCupertinoApp(
      title: 'Orbix',
      // Dark Mode Only：CupertinoThemeData 比 ThemeData 简洁，没有
      // light/dark/themeMode 三件套——一锤定音 brightness: dark。
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.mainBg,
      ),
      defaultTransition: Transition.cupertino,
      popGesture: true,
      // 应用锁门套在所有路由之上：锁屏覆盖时仍保留下层 App 状态。
      builder: (context, child) =>
          AppLockGate(key: appLockGateKey, child: child ?? const SizedBox()),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
