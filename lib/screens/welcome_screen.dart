import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'login_screen.dart';

/// 首次启动欢迎页：发光 Logo + 标题 + 3 行特性 + 主操作按钮。
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final accent = AppColors.accent.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              _buildHeader(accent),
              const Spacer(flex: 2),
              _buildFeatures(),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildCta(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // —— 顶部发光 Logo + 主标题 + 副标题 ——
  Widget _buildHeader(Color accent) {
    return Column(
      children: [
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
                color: accent.withValues(alpha: 0.40),
                blurRadius: 32,
                spreadRadius: 4,
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
        const SizedBox(height: 32),
        Text('Orbix', style: AppTypography.largeTitle()),
        const SizedBox(height: 6),
        Text(
          'qBittorrent 客户端',
          style: AppTypography.subtitle().copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // —— 三行功能介绍：单 inset grouped section，无独立浮卡 ——
  Widget _buildFeatures() {
    return CupertinoListSection.insetGrouped(
      children: [
        _featureTile(
          CupertinoIcons.plus_app_fill,
          '添加服务器',
          '配置你的 qBittorrent 服务器地址',
        ),
        _featureTile(
          CupertinoIcons.link,
          '建立连接',
          '快速连接到远程或本地服务器',
        ),
        _featureTile(
          CupertinoIcons.arrow_down_doc_fill,
          '管理种子',
          '轻松管理和监控所有种子任务',
        ),
      ],
    );
  }

  Widget _featureTile(IconData icon, String title, String subtitle) {
    return CupertinoListTile.notched(
      leading: Icon(icon, color: AppColors.accent, size: 24),
      title: Text(
        title,
        style: AppTypography.body().copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: AppTypography.subtitle()),
    );
  }

  // —— 主 CTA：iOS 原生 filled 按钮，14pt 圆角，无阴影 ——
  Widget _buildCta() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 16),
        onPressed: () => Get.to(() => const LoginScreen()),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add_circled_solid,
                color: CupertinoColors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '添加服务器',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
