import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login_screen.dart';
import '../theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // 与登录页一致的设计令牌（强调色固定，其余结构色随明暗动态解析）
  static const Color _accent = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              _buildHeader(),
              const Spacer(flex: 2),
              _buildFeatureList(),
              const Spacer(flex: 3),
              _buildBottomButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // —— 顶部发光 Logo 与标题 ——
  Widget _buildHeader() {
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
              colors: [Color(0xFF0A84FF), Color(0xFF0060DF)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.40),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.cloud_download_fill,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Orbix",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppColors.of(AppColors.label),
            letterSpacing: -0.5, // 大字号收紧字距更精致
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "qBittorrent 客户端",
          style: TextStyle(
            fontSize: 15,
            color: AppColors.of(AppColors.secondaryLabel),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // —— 中间功能介绍列表（纯信息展示）——
  Widget _buildFeatureList() {
    return Column(
      children: const [
        _FeatureTile(
          icon: CupertinoIcons.plus_app_fill,
          title: "添加服务器",
          subtitle: "配置你的 qBittorrent 服务器地址",
        ),
        SizedBox(height: 16),
        _FeatureTile(
          icon: CupertinoIcons.link,
          title: "建立连接",
          subtitle: "快速连接到远程或本地服务器",
        ),
        SizedBox(height: 16),
        _FeatureTile(
          icon: CupertinoIcons.arrow_down_doc_fill,
          title: "管理种子",
          subtitle: "轻松管理和监控所有种子任务",
        ),
      ],
    );
  }

  // —— 底部主操作按钮（唯一明确入口）——
  Widget _buildBottomButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Get.to(() => const LoginScreen()),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.add_circled_solid, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              "添加服务器",
              style: TextStyle(
                color: Colors.white,
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

// 单个功能卡片
class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.of(AppColors.card),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.of(AppColors.accentSoftBg),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: WelcomeScreen._accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(AppColors.label),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(AppColors.secondaryLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
