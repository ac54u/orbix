import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/connecting_dialog.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'server_management_screen.dart';

/// App 启动首页：服务器选择页。
///
/// 选择一个服务器 → 弹出「连接中」遮罩 → 进入主界面。
class ServerSelectionPage extends StatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  State<ServerSelectionPage> createState() => _ServerSelectionPageState();
}

class _ServerSelectionPageState extends State<ServerSelectionPage> {
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
    if (!mounted) return;
    final api = QBitApi();
    api.setServer(s);

    showConnectingDialog(context);
    // 同时等待真实登录与一个最小展示时长，避免遮罩一闪而过
    final results = await Future.wait([
      api.connect(),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final result = results[0] as ConnectResult;
    if (result.success) {
      Get.offAll(() => const MainScreen());
    } else {
      _showRetryDialog(s, result.message);
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
              _editAndRetry(s);
            },
            child: const Text('编辑'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _connect(s);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // 半屏弹出编辑该服务器；保存后用最新配置自动重连
  Future<void> _editAndRetry(ServerConfig s) async {
    final saved = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (_) => LoginScreen(editServer: s, asSheet: true),
    );
    await _load();
    if (saved == true && mounted) {
      final active = await QBitApi.loadSavedConfig();
      if (active != null && mounted) _connect(active);
    }
  }

  void _openManagement() {
    Navigator.of(context)
        .push(
          CupertinoPageRoute(builder: (_) => const ServerManagementPage()),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final accent = AppColors.accent.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // —— 顶部发光图标（与启动 / 欢迎一致的光晕处理）——
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 36,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.arrow_down,
                color: CupertinoColors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text('Orbix', style: AppTypography.largeTitle()),
            const SizedBox(height: 4),
            Text(
              'qBittorrent 客户端',
              style: AppTypography.subtitle().copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: 32),
            // —— 列表区 ——
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _servers.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
            _buildManageButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 8, 20, 8),
          child: Text(
            '选择一个服务器连接',
            style: AppTypography.sectionHeader(),
          ),
        ),
        CupertinoListSection.insetGrouped(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          topMargin: 0,
          children: _servers.map(_buildServerTile).toList(),
        ),
      ],
    );
  }

  Widget _buildServerTile(ServerConfig s) {
    return CupertinoListTile.notched(
      onTap: () => _connect(s),
      leading: const Icon(
        CupertinoIcons.cloud_fill,
        color: AppColors.accent,
        size: 24,
      ),
      title: Text(
        _label(s),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body().copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        s.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption(),
      ),
      trailing: const CupertinoListTileChevron(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.cloud,
            size: 44,
            color: AppColors.of(AppColors.placeholder),
          ),
          const SizedBox(height: 14),
          Text(
            '暂无服务器，点击下方添加',
            style: AppTypography.subtitle(
              color: AppColors.of(AppColors.tertiaryLabel),
            ),
          ),
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
          Icon(
            CupertinoIcons.settings,
            color: AppColors.accent,
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
            '管理服务器',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
