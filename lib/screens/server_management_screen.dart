import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/connecting_dialog.dart';
import '../widgets/toast.dart';
import 'login_screen.dart';
import 'main_screen.dart';

/// 服务器管理页：从设置页 / 启动选择页进入。
///
/// 展示全部已保存的服务器，左滑可「连接 / 编辑 / 删除」，右上角「+」添加。
class ServerManagementPage extends StatefulWidget {
  /// 切换服务器成功后的回调：让主界面回到种子页并立即刷新。
  final VoidCallback? onSwitched;
  const ServerManagementPage({super.key, this.onSwitched});

  @override
  State<ServerManagementPage> createState() => _ServerManagementPageState();
}

class _ServerManagementPageState extends State<ServerManagementPage> {
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
  Future<void> _switchTo(ServerConfig s) async {
    await QBitApi.setActiveServer(s);
    if (!mounted) return;
    final api = QBitApi();
    api.setServer(s);

    showConnectingDialog(context);
    final results = await Future.wait([
      api.connect(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final result = results[0] as ConnectResult;
    if (result.success) {
      if (widget.onSwitched != null) {
        Navigator.of(context).pop();
        widget.onSwitched!.call();
      } else {
        Get.offAll(() => const MainScreen());
      }
    } else {
      _toast('连接失败：${result.message}', ok: false);
      await _load();
    }
  }

  // 半屏弹出登录页：添加 / 编辑（Cupertino 原生 modal popup，自带底部 Align + 滑入动效）
  Future<T?> _presentLoginSheet<T>({ServerConfig? editServer}) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (_) => LoginScreen(editServer: editServer, asSheet: true),
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
    Toast.show(context, msg, type: ok ? ToastType.success : ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      navigationBar: CupertinoNavigationBar(
        backgroundColor:
            AppColors.of(AppColors.groupedBg).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: AppColors.of(AppColors.separator),
            width: 0.0,
          ),
        ),
        previousPageTitle: '设置',
        middle: Text('服务器管理', style: AppTypography.navTitle()),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _addServer,
          child: const Icon(
            CupertinoIcons.add,
            color: CupertinoColors.systemBlue,
            size: 24,
          ),
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _servers.isEmpty
              ? _buildEmpty()
              : _buildList(),
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
            '暂无服务器',
            style: AppTypography.subtitle(
              color: AppColors.of(AppColors.tertiaryLabel),
            ),
          ),
          const SizedBox(height: 18),
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(14),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            onPressed: _addServer,
            child: const Text('添加服务器'),
          ),
        ],
      ),
    );
  }

  // 单 inset 容器 + 行间 0.5pt hairline；外层 Clip 让左滑揭示在圆角内。
  Widget _buildList() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.of(AppColors.card),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                for (var i = 0; i < _servers.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Container(
                        height: 0.5,
                        color: AppColors.of(AppColors.separator),
                      ),
                    ),
                  _buildSlidableRow(_servers[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidableRow(ServerConfig s) {
    final active = _isActive(s);
    // 当前服务器：编辑 + 删除（2 项）；其它：连接 + 编辑 + 删除（3 项）
    final actions = <Widget>[
      if (!active)
        SlidableAction(
          onPressed: (_) => _switchTo(s),
          backgroundColor: CupertinoColors.systemBlue,
          foregroundColor: CupertinoColors.white,
          icon: CupertinoIcons.link,
          label: '连接',
        ),
      SlidableAction(
        onPressed: (_) => _editServer(s),
        backgroundColor: CupertinoColors.systemOrange,
        foregroundColor: CupertinoColors.white,
        icon: CupertinoIcons.pencil,
        label: '编辑',
      ),
      SlidableAction(
        onPressed: (_) => _confirmDelete(s),
        backgroundColor: CupertinoColors.systemRed,
        foregroundColor: CupertinoColors.white,
        icon: CupertinoIcons.delete,
        label: '删除',
      ),
    ];
    return Slidable(
      key: ValueKey('${s.url}|${s.username}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: active ? 0.5 : 0.72,
        children: actions,
      ),
      child: _buildServerTile(s, active),
    );
  }

  Widget _buildServerTile(ServerConfig s, bool active) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTo(s),
      child: ColoredBox(
        color: AppColors.of(AppColors.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                active
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: active
                    ? CupertinoColors.systemBlue
                    : AppColors.of(AppColors.placeholder),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body().copyWith(
                        fontSize: 16,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.url}  ·  ${s.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ),
              if (active)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '使用中',
                    style: AppTypography.caption(
                      color: CupertinoColors.systemBlue,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
