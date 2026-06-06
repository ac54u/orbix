import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/qbit_api.dart';
import 'main_screen.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';

/// 启动决策页：
///  - 本地无凭据      → 欢迎页（首次引导）
///  - 有凭据且连接成功 → 直接进主页（记住已登录）
///  - 有凭据但连接失败 → 登录页（已预填，便于修正）
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
    final config = await QBitApi.loadSavedConfig();

    // 首次启动 / 未配置过 → 欢迎页
    if (config == null) {
      if (!mounted) return;
      Get.offAll(() => const WelcomeScreen());
      return;
    }

    // 有凭据：尝试自动登录
    final api = QBitApi();
    api.setServer(config);
    final result = await api.connect();

    if (!mounted) return;
    if (result.success) {
      Get.offAll(() => const MainScreen());
    } else {
      // 凭据失效或服务器不可达 → 登录页（已预填本地值，可直接修改重试）
      Get.offAll(() => const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            const Text(
              "Orbix",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1C1E),
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
