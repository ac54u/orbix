import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'server_selection_screen.dart';
import 'welcome_screen.dart';

/// 启动决策页：
///  - 本地无服务器 → 欢迎页（首次引导）
///  - 已有服务器   → 服务器选择页（启动首页）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideStart();
  }

  Future<void> _decideStart() async {
    final servers = await QBitApi.loadServers();
    if (!mounted) return;
    if (servers.isEmpty) {
      Get.offAll(() => const WelcomeScreen());
    } else {
      Get.offAll(() => const ServerSelectionPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final accent = AppColors.accent.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 品牌 logo：渐变 + 柔光，跨欢迎/启动/登录三页一致。
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF366EF6), Color(0xFF0E52BA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.cloud_download_fill,
                color: CupertinoColors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 28),
            Text('Orbix', style: AppTypography.cardTitle()),
            const SizedBox(height: 32),
            const CupertinoActivityIndicator(radius: 12),
          ],
        ),
      ),
    );
  }
}
