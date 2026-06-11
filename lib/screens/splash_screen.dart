import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import 'welcome_screen.dart';
import 'server_selection_screen.dart';

/// 启动决策页：
///  - 本地无服务器 → 欢迎页（首次引导）
///  - 已有服务器   → 服务器选择页（启动首页）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _accent = Color(0xFF007AFF);

  @override
  void initState() {
    super.initState();
    _decideStart();
  }

  Future<void> _decideStart() async {
    final servers = await QBitApi.loadServers();
    if (!mounted) return;

    // 首次启动 / 未配置过 → 欢迎页；否则进入服务器选择页（启动首页）
    if (servers.isEmpty) {
      Get.offAll(() => const WelcomeScreen());
    } else {
      Get.offAll(() => const ServerSelectionPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 品牌 logo，与欢迎/登录页一致
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A84FF), Color(0xFF0060DF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.cloud_download_fill,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 28),
            Text(
              "Orbix",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.of(AppColors.label),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            const CupertinoActivityIndicator(radius: 12),
          ],
        ),
      ),
    );
  }
}
