import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/qbit_api.dart';
import 'login_screen.dart';
import 'add_torrent_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;
  String _filter = 'all'; // 当前筛选：all/downloading/seeding/active/paused/completed

  // 动态数据源
  List<dynamic> _torrents = [];
  int _totalDlSpeed = 0; // 全局下载速度 (Bytes/s)
  int _totalUpSpeed = 0; // 全局上传速度 (Bytes/s)
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchData(); // 初始拉取一次
    // 每 2 秒刷新一次，保持与服务器实时同步
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // —— 核心网络请求逻辑 ——
  Future<void> _fetchData() async {
    final api = QBitApi();
    try {
      final torrents = await api.getTorrents();
      final transferInfo = await api.getTransferInfo();
      if (mounted) {
        setState(() {
          _torrents = torrents;
          _totalDlSpeed = transferInfo['dl_info_speed'] ?? 0;
          _totalUpSpeed = transferInfo['up_info_speed'] ?? 0;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint("获取数据失败: $e");
    }
  }

  // —— 数据格式化工具 ——

  String _formatSpeed(int bytes) {
    if (bytes == 0) return "0 B/s";
    if (bytes < 1024) return "$bytes B/s";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB/s";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB/s";
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return "0 B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  String _formatEta(int seconds) {
    if (seconds == 8640000 || seconds < 0) return "∞"; // qBittorrent 用 8640000 表示无限
    int d = seconds ~/ 86400;
    int h = (seconds % 86400) ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (d > 0) return "${d}d ${h}h";
    if (h > 0) return "${h}h ${m}m";
    if (m > 0) return "${m}m ${s}s";
    return "${s}s";
  }

  // 将 qBittorrent 状态码转为 UI 文本/颜色/图标（兼容新版 stopped* / 旧版 paused*）
  Map<String, dynamic> _parseState(String state) {
    const blue = Color(0xFF007AFF);
    const green = Color(0xFF34C759);
    const grey = Color(0xFF8E8E93);
    const orange = Color(0xFFFF9500);
    const red = Color(0xFFFF3B30);
    switch (state) {
      case 'downloading':
      case 'metaDL':
      case 'forcedDL':
        return {"text": "下载中", "color": blue, "icon": CupertinoIcons.arrow_down_circle_fill};
      case 'stalledDL':
        return {"text": "等待下载", "color": blue, "icon": CupertinoIcons.arrow_down_circle};
      case 'uploading':
      case 'forcedUP':
        return {"text": "上传中", "color": green, "icon": CupertinoIcons.arrow_up_circle_fill};
      case 'stalledUP':
        return {"text": "做种中", "color": green, "icon": CupertinoIcons.arrow_up_circle_fill};
      case 'pausedDL':
      case 'stoppedDL':
        // 暂停：用暂停图标，而非向下箭头
        return {"text": "已暂停", "color": grey, "icon": CupertinoIcons.pause_circle_fill};
      case 'pausedUP':
      case 'stoppedUP':
        return {"text": "已完成", "color": grey, "icon": CupertinoIcons.checkmark_circle_fill};
      case 'checkingUP':
      case 'checkingDL':
      case 'checkingResumeData':
        return {"text": "校验中", "color": orange, "icon": CupertinoIcons.arrow_2_circlepath_circle_fill};
      case 'queuedDL':
      case 'queuedUP':
        return {"text": "排队中", "color": grey, "icon": CupertinoIcons.time};
      case 'error':
      case 'missingFiles':
        return {"text": "错误", "color": red, "icon": CupertinoIcons.exclamationmark_circle_fill};
      default:
        return {"text": state, "color": grey, "icon": CupertinoIcons.circle};
    }
  }

  // —— 筛选 ——

  String _filterLabel(String key) {
    switch (key) {
      case 'downloading':
        return '下载中';
      case 'seeding':
        return '做种中';
      case 'active':
        return '活动中';
      case 'paused':
        return '已暂停';
      case 'completed':
        return '已完成';
      default:
        return '全部';
    }
  }

  bool _matchesFilter(dynamic t) {
    if (_filter == 'all') return true;
    final s = (t['state'] ?? '').toString();
    switch (_filter) {
      case 'downloading':
        return ['downloading', 'metaDL', 'forcedDL', 'stalledDL', 'queuedDL',
                'checkingDL'].contains(s);
      case 'seeding':
        return ['uploading', 'forcedUP', 'stalledUP', 'queuedUP', 'checkingUP']
            .contains(s);
      case 'paused':
        return s.startsWith('stopped') || s.startsWith('paused');
      case 'completed':
        return (t['progress'] ?? 0.0).toDouble() >= 1.0;
      case 'active':
        return ((t['dlspeed'] ?? 0) as int) > 0 ||
            ((t['upspeed'] ?? 0) as int) > 0;
      default:
        return true;
    }
  }

  // —— 长按种子的操作菜单 ——

  bool _isPaused(String state) =>
      state.startsWith('stopped') || state.startsWith('paused');

  /// 用 CupertinoContextMenu 包裹种子卡片：长按后卡片浮起放大、背景模糊，
  /// 操作项从卡片处展开（iOS 原生「3D Touch / Haptic Touch」效果）。
  Widget _wrapWithContextMenu({
    required String hash,
    required String name,
    required String state,
    required Widget card,
  }) {
    final paused = _isPaused(state);
    return CupertinoContextMenu(
      actions: [
        if (paused)
          CupertinoContextMenuAction(
            trailingIcon: CupertinoIcons.play_fill,
            onPressed: () {
              Navigator.pop(context);
              _runAction(() => QBitApi().startTorrent(hash), '已启动');
            },
            child: const Text('启动'),
          )
        else
          CupertinoContextMenuAction(
            trailingIcon: CupertinoIcons.pause_fill,
            onPressed: () {
              Navigator.pop(context);
              _runAction(() => QBitApi().stopTorrent(hash), '已暂停');
            },
            child: const Text('暂停'),
          ),
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.bolt_fill,
          onPressed: () {
            Navigator.pop(context);
            _runAction(() => QBitApi().forceStartTorrent(hash), '已强制启动');
          },
          child: const Text('强制启动'),
        ),
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.checkmark_shield,
          onPressed: () {
            Navigator.pop(context);
            _runAction(() => QBitApi().recheckTorrent(hash), '已开始重新校验');
          },
          child: const Text('强制重新校验'),
        ),
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.antenna_radiowaves_left_right,
          onPressed: () {
            Navigator.pop(context);
            _runAction(() => QBitApi().reannounceTorrent(hash), '已重新汇报');
          },
          child: const Text('强制重新汇报'),
        ),
        CupertinoContextMenuAction(
          isDestructiveAction: true,
          trailingIcon: CupertinoIcons.delete,
          onPressed: () {
            Navigator.pop(context);
            _confirmDelete(hash, name);
          },
          child: const Text('删除'),
        ),
      ],
      // 关键：浮层中补一层透明 Material，提供完整 DefaultTextStyle，
      // 否则长按放大时卡片文字会出现黄色下划线（缺省文本样式标志）。
      child: Material(
        type: MaterialType.transparency,
        child: card,
      ),
    );
  }

  // 删除二次确认：居中弹窗，可选择是否连同文件一起删
  void _confirmDelete(String hash, String name) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除任务'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(name, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              _runAction(
                  () => QBitApi().deleteTorrent(hash, deleteFiles: false),
                  '已删除任务（保留文件）');
            },
            child: const Text('仅删任务'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _runAction(
                  () => QBitApi().deleteTorrent(hash, deleteFiles: true),
                  '已删除任务和文件');
            },
            child: const Text('删任务和文件'),
          ),
        ],
      ),
    );
  }

  // 执行操作 → 立即刷新 → 反馈
  Future<void> _runAction(Future<bool> Function() action, String okMsg) async {
    final ok = await action();
    if (!mounted) return;
    await _fetchData(); // 操作后立刻刷新列表
    if (!mounted) return;
    _toast(ok ? okMsg : '操作失败，请重试', ok: ok);
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
      backgroundColor: const Color(0xFFF4F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // 按底部 tab 切换页面（统计/搜索/设置为占位）
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildTorrentPage(),
                  _buildSimplePage("统计", CupertinoIcons.chart_bar_alt_fill),
                  _buildSimplePage("搜索", CupertinoIcons.search),
                  ServerSettingsPage(
                    // 切换服务器后回到「种子」页并立即刷新，给出直观反馈
                    onSwitched: () {
                      setState(() => _currentIndex = 0);
                      _fetchData();
                    },
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.withOpacity(0.1)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // 各页统一的大标题样式
  static const TextStyle _pageTitleStyle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1C1C1E),
    letterSpacing: -0.5,
  );

  // 占位页（统计/搜索）：同样固定标题，内容居中
  Widget _buildSimplePage(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: _pageTitleStyle),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: const Color(0xFFC7C7CC)),
                const SizedBox(height: 12),
                Text("$title · 开发中",
                    style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 种子主页面：顶部（筛选/添加 + 标题 + 速度总览）固定，仅列表滚动
  Widget _buildTorrentPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // —— 固定头部 ——
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 + 添加
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("种子", style: _pageTitleStyle),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await Get.to(() => const AddTorrentScreen());
                      _fetchData(); // 返回后立即刷新
                    },
                    child: _buildCircleButton(CupertinoIcons.add, isOutlined: false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFilterBar(),
              const SizedBox(height: 16),
              _buildSpeedSummary(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // —— 可滚动列表 ——
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _buildDynamicTorrentList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 顶部横向胶囊筛选栏：点一下即切换，选中蓝底白字
  Widget _buildFilterBar() {
    const options = [
      ['all', '全部'],
      ['downloading', '下载中'],
      ['seeding', '做种中'],
      ['active', '活动中'],
      ['paused', '已暂停'],
      ['completed', '已完成'],
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final key = options[i][0];
          final label = options[i][1];
          final selected = _filter == key;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF007AFF) : Colors.white,
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF6E6E73),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, {required bool isOutlined}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOutlined ? Colors.transparent : const Color(0xFF007AFF),
        border: isOutlined ? Border.all(color: const Color(0xFF007AFF), width: 1.5) : null,
      ),
      child: Icon(icon, color: isOutlined ? const Color(0xFF007AFF) : Colors.white, size: 22),
    );
  }

  // 全局速度总览
  Widget _buildSpeedSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildSpeedCard(
            title: "上传",
            speedStr: _formatSpeed(_totalUpSpeed),
            icon: CupertinoIcons.arrow_up_circle_fill,
            color: const Color(0xFF007AFF),
            gradientColors: [const Color(0xFF007AFF), const Color(0xFF007AFF).withOpacity(0.1)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSpeedCard(
            title: "下载",
            speedStr: _formatSpeed(_totalDlSpeed),
            icon: CupertinoIcons.arrow_down_circle_fill,
            color: const Color(0xFF5AC8FA),
            gradientColors: [const Color(0xFF5AC8FA), const Color(0xFF5AC8FA).withOpacity(0.1)],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedCard({
    required String title,
    required String speedStr,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
  }) {
    final parts = speedStr.split(' ');
    final number = parts[0];
    final unit = parts.length > 1 ? parts[1] : "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(number, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(colors: gradientColors, begin: Alignment.centerLeft, end: Alignment.centerRight),
            ),
          )
        ],
      ),
    );
  }

  // —— 动态渲染服务器返回的种子列表 ——
  Widget _buildDynamicTorrentList() {
    // 按添加时间倒序：最新添加的排在最前
    final list = _torrents.where(_matchesFilter).toList()
      ..sort((a, b) => ((b['added_on'] ?? 0) as int)
          .compareTo((a['added_on'] ?? 0) as int));

    if (list.isEmpty) {
      final String emptyText;
      if (!_loaded) {
        emptyText = "加载中…";
      } else if (_torrents.isEmpty) {
        emptyText = "暂无种子任务";
      } else {
        emptyText = "「${_filterLabel(_filter)}」下暂无任务";
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            emptyText,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: list.map((t) {
        final name = t['name'] ?? "未知任务";
        final hash = (t['hash'] ?? "").toString();
        final rawState = (t['state'] ?? "").toString();
        final totalSize = (t['total_size'] ?? 0) as int;
        final progress = (t['progress'] ?? 0.0).toDouble();
        final stateInfo = _parseState(rawState);
        final dlspeed = (t['dlspeed'] ?? 0) as int;
        final upspeed = (t['upspeed'] ?? 0) as int;
        final ratio = (t['ratio'] ?? 0.0).toDouble();
        final eta = (t['eta'] ?? 8640000) as int;

        final card = _buildTorrentCard(
          title: name,
          size: _formatSize(totalSize),
          progress: progress,
          progressText: "${(progress * 100).toStringAsFixed(1)}%",
          statusText: stateInfo["text"],
          themeColor: stateInfo["color"],
          statusIcon: stateInfo["icon"],
          downSpeed: _formatSpeed(dlspeed),
          upSpeed: _formatSpeed(upspeed),
          ratio: ratio.toStringAsFixed(2),
          eta: _formatEta(eta),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: hash.isEmpty
              ? card
              : _wrapWithContextMenu(
                  hash: hash, name: name, state: rawState, card: card),
        );
      }).toList(),
    );
  }

  Widget _buildTorrentCard({
    required String title,
    required String size,
    required double progress,
    required String progressText,
    required String statusText,
    required Color themeColor,
    required IconData statusIcon,
    required String downSpeed,
    required String upSpeed,
    required String ratio,
    required String eta,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                statusIcon,
                color: themeColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(size, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progressText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 6,
                width: constraints.maxWidth,
                decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(3)),
                child: Row(
                  children: [
                    Container(
                      width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                      decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(3)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(CupertinoIcons.arrow_down_circle_fill, downSpeed, const Color(0xFF007AFF)),
              _buildStatItem(CupertinoIcons.arrow_up_circle_fill, upSpeed, const Color(0xFF34C759)),
              _buildStatItem(CupertinoIcons.graph_square, ratio, const Color(0xFFFF9500)),
              _buildStatItem(CupertinoIcons.time, eta, const Color(0xFF8E8E93)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, CupertinoIcons.arrow_down_circle_fill, "种子"),
          _buildNavItem(1, CupertinoIcons.chart_bar_alt_fill, "统计"),
          _buildNavItem(2, CupertinoIcons.search, "搜索"),
          _buildNavItem(3, CupertinoIcons.gear_alt, "设置"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF007AFF) : const Color(0xFF8E8E93);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

/// 设置页：服务器管理（列表 / 切换 / 添加 / 删除）
class ServerSettingsPage extends StatefulWidget {
  /// 切换服务器成功后的回调，让主界面立即刷新数据
  final VoidCallback? onSwitched;
  const ServerSettingsPage({super.key, this.onSwitched});

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  static const Color _accent = Color(0xFF007AFF);
  static const Color _ink = Color(0xFF1C1C1E);
  static const Color _inkMuted = Color(0xFF8E8E93);

  List<ServerConfig> _servers = [];
  // 当前活动服务器用 url + username 共同标识（同地址可能多个账号）
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

  Future<void> _switchTo(ServerConfig s) async {
    if (_isActive(s)) return;
    await QBitApi.setActiveServer(s);
    final api = QBitApi();
    api.setServer(s);
    // 清旧会话并登录新服务器（失败也无妨，主界面轮询会自愈）
    unawaited(api.connect());
    await _load(); // 重新读取，刷新「使用中」标记
    if (!mounted) return;
    _toast('已切换到 ${_label(s)}', ok: true);
    widget.onSwitched?.call();
  }

  Future<void> _confirmDelete(ServerConfig s) async {
    if (_isActive(s)) {
      _toast('当前使用中的服务器无法删除', ok: false);
      return;
    }
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

  Future<void> _addServer() async {
    // 进入登录页添加；保存后它会 upsert 并 Get.offAll 到新的 MainScreen
    await Get.to(() => const LoginScreen());
    // 返回后（取消的情况）刷新一次列表
    await _load();
  }

  String _label(ServerConfig s) =>
      s.name.isNotEmpty ? s.name : s.url.replaceFirst(RegExp(r'^https?://'), '');

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
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 固定标题 ——
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '设置',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          // —— 可滚动内容 ——
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('服务器',
                      style: TextStyle(fontSize: 13, color: _inkMuted)),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                else
                  _buildServerCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    final rows = <Widget>[];
    for (var i = 0; i < _servers.length; i++) {
      final s = _servers[i];
      rows.add(_buildServerRow(s));
      rows.add(_hairline());
    }
    // 末尾「添加服务器」行
    rows.add(_buildAddRow());
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _hairline() =>
      Container(height: 0.5, color: const Color(0xFFE5E5EA), margin: const EdgeInsets.only(left: 16));

  Widget _buildServerRow(ServerConfig s) {
    final active = _isActive(s);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTo(s),
      onLongPress: () => _confirmDelete(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              active
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: active ? _accent : const Color(0xFFC7C7CC),
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
    );
  }

  Widget _buildAddRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _addServer,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(CupertinoIcons.add_circled_solid, color: _accent, size: 22),
            SizedBox(width: 12),
            Text('添加服务器',
                style: TextStyle(
                    fontSize: 16, color: _accent, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
