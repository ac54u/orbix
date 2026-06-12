import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const OrbixApp());
}

class OrbixApp extends StatelessWidget {
  const OrbixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetCupertinoApp(
      title: 'Orbix',
      // Dark Mode Only：CupertinoThemeData 比 ThemeData 简洁，没有
      // light/dark/themeMode 三件套——一锤定音 brightness: dark。
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.mainBg,
      ),
      defaultTransition: Transition.cupertino,
      popGesture: true,
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
