import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'server_management_screen.dart';

/// App 启动首页：服务器选择页。
/// 选择一个服务器 → 弹出「连接中」遮罩 → 进入主界面。
class ServerSelectionPage extends StatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  State<ServerSelectionPage> createState() => _ServerSelectionPageState();
}

class _ServerSelectionPageState extends State<ServerSelectionPage> {
  static const Color _accent = Color(0xFF007AFF);
  static const Color _iconBlue = Color(0xFF0060DF); // 深蓝服务器图标

  List<ServerConfig> _servers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final servers = await QBitApi.loadServers();
    if (!mounted) return;
    setState(() {
      _servers = servers;
      _loading = false;
    });
  }

  String _label(ServerConfig s) =>
      s.name.isNotEmpty ? s.name : s.url.replaceFirst(RegExp(r'^https?://'), '');

  // —— 选中服务器：弹出加载遮罩，真实连接成功才进入主界面 ——
  Future<void> _connect(ServerConfig s) async {
    await QBitApi.setActiveServer(s);
    final api = QBitApi();
    api.setServer(s);

    _showLoadingDialog();
    // 同时等待真实登录与一个最小展示时长，避免遮罩一闪而过
    final results = await Future.wait([
      api.connect(),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 关闭加载遮罩

    final result = results[0] as ConnectResult;
    if (result.success) {
      Get.offAll(() => const MainScreen()); // 进入主界面，清空返回栈
    } else {
      _showRetryDialog(s, result.message); // 失败：提示并可重试
    }
  }

  void _showRetryDialog(ServerConfig s, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('连接失败'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              _editAndRetry(s); // 当场改正凭据/地址
            },
            child: const Text('编辑'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _connect(s); // 重试
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // 半屏弹出编辑该服务器；保存后用最新配置自动重连
  Future<void> _editAndRetry(ServerConfig s) async {
    final saved = await Get.bottomSheet<bool>(
      LoginScreen(editServer: s, asSheet: true),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
    );
    await _load(); // 刷新列表（名称/地址可能已变）
    if (saved == true && mounted) {
      // 编辑保存后该服务器已设为活动，取最新配置重连
      final active = await QBitApi.loadSavedConfig();
      if (active != null && mounted) _connect(active);
    }
  }

  void _showLoadingDialog() {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.of(AppColors.card),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 14),
              Text('连接中...',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.of(AppColors.secondaryLabel))),
            ],
          ),
        ),
      ),
    );
  }

  void _openManagement() {
    Navigator.of(context)
        .push(
          CupertinoPageRoute(builder: (_) => const ServerManagementPage()),
        )
        .then((_) => _load()); // 返回后刷新列表（可能新增/编辑/删除）
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // —— 标题 ——
            Text('Orbix',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.of(AppColors.label),
                    letterSpacing: -0.5)),
            const SizedBox(height: 6),
            // —— 提示文本 ——
            Text('选择一个服务器连接',
                style: TextStyle(
                    fontSize: 13, color: AppColors.of(AppColors.secondaryLabel))),
            const SizedBox(height: 24),
            // —— 列表 ——
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _servers.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          itemCount: _servers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _buildServerCard(_servers[i]),
                        ),
            ),
            // —— 底部管理按钮 ——
            _buildManageButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(ServerConfig s) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _connect(s),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.of(AppColors.card),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // 淡蓝圆角方形 + 深蓝图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.of(AppColors.accentSoftBg),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dns, color: _iconBlue, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(s),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.of(AppColors.label)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(s.url,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(AppColors.secondaryLabel)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: AppColors.of(AppColors.placeholder), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined,
              size: 48, color: AppColors.of(AppColors.placeholder)),
          const SizedBox(height: 12),
          Text('暂无服务器，点击下方添加',
              style: TextStyle(
                  fontSize: 14, color: AppColors.of(AppColors.secondaryLabel))),
        ],
      ),
    );
  }

  Widget _buildManageButton() {
    return CupertinoButton(
      onPressed: _openManagement,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings, color: _accent, size: 18),
          SizedBox(width: 6),
          Text('管理服务器',
              style: TextStyle(
                  fontSize: 15, color: _accent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
