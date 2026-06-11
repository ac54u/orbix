import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'main_screen.dart';

/// 服务器管理页：从设置页右滑进入。
/// 展示全部已保存的服务器，左滑可「连接 / 编辑 / 删除」，右上角「+」添加。
class ServerManagementPage extends StatefulWidget {
  /// 切换服务器成功后的回调：让主界面回到种子页并立即刷新。
  final VoidCallback? onSwitched;
  const ServerManagementPage({super.key, this.onSwitched});

  @override
  State<ServerManagementPage> createState() => _ServerManagementPageState();
}

class _ServerManagementPageState extends State<ServerManagementPage> {
  static const Color _accent = Color(0xFF007AFF);
  static const Color _inkMuted = Color(0xFF8E8E93);
  Color get _ink => AppColors.of(AppColors.label);

  List<ServerConfig> _servers = [];
  String? _activeUrl;
  String? _activeUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final servers = await QBitApi.loadServers();
    final active = await QBitApi.loadSavedConfig();
    if (!mounted) return;
    setState(() {
      _servers = servers;
      _activeUrl = active?.url;
      _activeUser = active?.username;
      _loading = false;
    });
  }

  bool _isActive(ServerConfig s) =>
      _activeUrl != null && s.url == _activeUrl && s.username == _activeUser;

  String _label(ServerConfig s) =>
      s.name.isNotEmpty ? s.name : s.url.replaceFirst(RegExp(r'^https?://'), '');

  // —— 连接（点击行或左滑「连接」都走这里） ——
  // 弹出「连接中」状态遮罩，接入真实结果：成功进主界面，失败提示。
  Future<void> _switchTo(ServerConfig s) async {
    await QBitApi.setActiveServer(s);
    final api = QBitApi();
    api.setServer(s);

    _showConnectingDialog();
    // 同时等待真实登录与最小展示时长，避免遮罩一闪而过
    final results = await Future.wait([
      api.connect(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 关闭连接遮罩

    final result = results[0] as ConnectResult;
    if (result.success) {
      if (widget.onSwitched != null) {
        // 来自设置页：返回并通知主界面回到种子页刷新
        Navigator.of(context).pop();
        widget.onSwitched!.call();
      } else {
        // 来自启动选择页：直接进入主界面
        Get.offAll(() => const MainScreen());
      }
    } else {
      _toast('连接失败：${result.message}', ok: false);
      await _load(); // 刷新「使用中」标记
    }
  }

  void _showConnectingDialog() {
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
                      fontSize: 13,
                      color: AppColors.of(AppColors.secondaryLabel))),
            ],
          ),
        ),
      ),
    );
  }

  // —— 以底部半屏弹出登录页：添加 / 编辑 ——
  Future<T?> _presentLoginSheet<T>({ServerConfig? editServer}) {
    return Get.bottomSheet<T>(
      LoginScreen(editServer: editServer, asSheet: true),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
    );
  }

  Future<void> _addServer() async {
    final added = await _presentLoginSheet<bool>();
    await _load();
    if (added == true && mounted) _toast('已添加', ok: true);
  }

  Future<void> _editServer(ServerConfig s) async {
    final changed = await _presentLoginSheet<bool>(editServer: s);
    await _load();
    if (changed == true && mounted) _toast('已更新 ${_label(s)}', ok: true);
  }

  Future<void> _confirmDelete(ServerConfig s) async {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除服务器'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('确定删除「${_label(s)}」？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await QBitApi.removeServer(s);
              await _load();
              if (mounted) _toast('已删除', ok: true);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      appBar: AppBar(
        backgroundColor: AppColors.of(AppColors.groupedBg),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, color: _accent),
        ),
        title: Text('服务器管理',
            style: TextStyle(
                color: _ink, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _addServer,
            child: const Icon(CupertinoIcons.add, color: _accent, size: 24),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _servers.isEmpty
                ? _buildEmpty()
                : _buildList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.cloud, size: 48, color: _inkMuted),
          const SizedBox(height: 12),
          const Text('暂无服务器',
              style: TextStyle(fontSize: 15, color: _inkMuted)),
          const SizedBox(height: 16),
          CupertinoButton(
            color: _accent,
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            onPressed: _addServer,
            child: const Text('添加服务器'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = _servers[index];
        return _buildSlidableRow(s);
      },
    );
  }

  Widget _buildSlidableRow(ServerConfig s) {
    final active = _isActive(s);
    // 当前服务器：编辑 + 删除（2 项）；其它：连接 + 编辑 + 删除（3 项）
    final actions = <Widget>[
      if (!active)
        SlidableAction(
          onPressed: (_) => _switchTo(s),
          backgroundColor: CupertinoColors.activeBlue,
          foregroundColor: Colors.white,
          icon: Icons.link,
          label: '连接',
        ),
      SlidableAction(
        onPressed: (_) => _editServer(s),
        backgroundColor: CupertinoColors.systemOrange,
        foregroundColor: Colors.white,
        icon: Icons.edit,
        label: '编辑',
      ),
      SlidableAction(
        onPressed: (_) => _confirmDelete(s),
        backgroundColor: CupertinoColors.destructiveRed,
        foregroundColor: Colors.white,
        icon: Icons.delete,
        label: '删除',
      ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Slidable(
        key: ValueKey('${s.url}|${s.username}'),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          // 每项约占 1/4 宽，按按钮数量分配滑出区域
          extentRatio: active ? 0.5 : 0.72,
          children: actions,
        ),
        child: _buildServerTile(s, active),
      ),
    );
  }

  Widget _buildServerTile(ServerConfig s, bool active) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTo(s), // 点击服务器行即连接
      child: Container(
        color: AppColors.of(AppColors.card),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              active
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: active ? _accent : AppColors.of(AppColors.placeholder),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(s),
                    style: TextStyle(
                        fontSize: 16,
                        color: _ink,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.url}  ·  ${s.username}',
                    style: const TextStyle(fontSize: 12, color: _inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (active)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('使用中',
                    style: TextStyle(
                        fontSize: 12,
                        color: _accent,
                        fontWeight: FontWeight.w600)),
              ),
          ],
          ),
        ),
      ),
    );
  }
}
