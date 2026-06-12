import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import '../services/qbit_api.dart';
import '../services/update_service.dart';
import '../services/app_lock.dart';
import 'add_torrent_screen.dart';
import 'torrent_detail_screen.dart';
import 'server_management_screen.dart';
import 'stats_screen.dart';
import 'search_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';
import '../widgets/app_lock_gate.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;
  String _filter = 'all'; // 当前筛选：all/downloading/seeding/active/paused/completed
  // 服务器代次：每切换一次服务器 +1。用作统计/搜索页的 key，
  // 强制重建这两个 IndexedStack 子树，丢弃上一个服务器的缓存数据。
  int _serverEpoch = 0;

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
    final blue = AppColors.accent.resolveFrom(context);
    final green = AppColors.success.resolveFrom(context);
    final grey = AppColors.of(AppColors.secondaryLabel);
    final orange = AppColors.warning.resolveFrom(context);
    final red = AppColors.danger.resolveFrom(context);
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
      case 'missingFiles':
        return {"text": "文件丢失", "color": red, "icon": CupertinoIcons.exclamationmark_triangle_fill};
      case 'error':
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

  // 点按卡片 → 打开详情页；返回后刷新列表（详情页可能已删除/改动该任务）。
  // 卡片不再长按弹操作菜单——所有操作都在详情页内，点进去即可。
  Future<void> _openDetail(dynamic t) async {
    if (t is! Map) return;
    final map = Map<String, dynamic>.from(t);
    await Get.to(() => TorrentDetailScreen(torrent: map));
    if (mounted) _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.mainBg),
      child: Column(
        children: [
          // 按底部 tab 切换页面
          Expanded(
            child: SafeArea(
              bottom: false, // 底部留给 _buildBottomNav 自己的 SafeArea
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildTorrentPage(),
                  StatsScreen(key: ValueKey('stats-$_serverEpoch')),
                  SearchScreen(key: ValueKey('search-$_serverEpoch')),
                  ServerSettingsPage(
                    // 切换服务器后回到「种子」页并立即刷新；同时 +1 服务器代次，
                    // 让统计/搜索页丢弃上一个服务器的缓存、按新服务器重建。
                    onSwitched: () {
                      setState(() {
                        _currentIndex = 0;
                        _serverEpoch++;
                      });
                      _fetchData();
                    },
                  ),
                ],
              ),
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  // 种子主页面：标题 + 添加按钮 + 筛选 + 行内速度 + 列表（Cupertino sliver refresh）。
  Widget _buildTorrentPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // —— 顶部：标题 + 添加按钮 ——
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('种子', style: AppTypography.largeTitle()),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () async {
                  await Get.to(() => const AddTorrentScreen());
                  _fetchData();
                },
                child: const Icon(
                  CupertinoIcons.add,
                  size: 28,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        // —— 筛选下划线 tabs ——
        _buildFilterBar(),
        // —— 行内全局速度（仅活动时显示） ——
        _buildSpeedInline(),
        const SizedBox(height: 8),
        // —— 列表 ——
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _fetchData),
              SliverToBoxAdapter(child: _buildDynamicTorrentList()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ],
    );
  }

  // 筛选下划线 tabs：选中态文本加粗 + 底部 systemBlue 极细线；无任何色块底。
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
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (_, i) {
          final key = options[i][0];
          final label = options[i][1];
          final selected = _filter == key;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _filter = key),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: AppTypography.subtitle(
                      color: selected
                          ? AppColors.of(AppColors.label)
                          : AppColors.of(AppColors.secondaryLabel),
                    ).copyWith(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  height: 1.5,
                  width: selected ? 24 : 0,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.all(Radius.circular(1)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 全局速度：行内细文字，空闲时整段折叠。
  Widget _buildSpeedInline() {
    final showDl = _totalDlSpeed > 0;
    final showUp = _totalUpSpeed > 0;
    final show = showDl || showUp;
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  if (showDl) ...[
                    Icon(CupertinoIcons.arrow_down,
                        size: 12,
                        color: AppColors.of(AppColors.secondaryLabel)),
                    const SizedBox(width: 4),
                    Text(_formatSpeed(_totalDlSpeed),
                        style: AppTypography.caption()),
                  ],
                  if (showDl && showUp) const SizedBox(width: 18),
                  if (showUp) ...[
                    Icon(CupertinoIcons.arrow_up,
                        size: 12,
                        color: AppColors.of(AppColors.secondaryLabel)),
                    const SizedBox(width: 4),
                    Text(_formatSpeed(_totalUpSpeed),
                        style: AppTypography.caption()),
                  ],
                ],
              ),
            ),
    );
  }

  // 列表：整组放入单个 inset grouped 卡，行间用 2pt 进度线划分。
  Widget _buildDynamicTorrentList() {
    final list = _torrents.where(_matchesFilter).toList()
      ..sort((a, b) => ((b['added_on'] ?? 0) as int)
          .compareTo((a['added_on'] ?? 0) as int));

    if (list.isEmpty) {
      final String emptyText;
      if (!_loaded) {
        emptyText = '加载中…';
      } else if (_torrents.isEmpty) {
        emptyText = '暂无种子任务';
      } else {
        emptyText = '「${_filterLabel(_filter)}」下暂无任务';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text(
            emptyText,
            style: AppTypography.subtitle(
                color: AppColors.of(AppColors.tertiaryLabel)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.of(AppColors.card),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children:
            List.generate(list.length, (i) => _buildTorrentRow(list[i])),
      ),
    );
  }

  // 单行：状态图标 + 标题/大小 + 元信息一行 + 底部 2pt 极细进度线。
  Widget _buildTorrentRow(dynamic t) {
    final name = (t['name'] ?? '未知任务') as String;
    final hash = (t['hash'] ?? '').toString();
    final rawState = (t['state'] ?? '').toString();
    final totalSize = (t['total_size'] ?? 0) as int;
    final progress = ((t['progress'] ?? 0.0) as num).toDouble();
    final stateInfo = _parseState(rawState);
    final dlspeed = (t['dlspeed'] ?? 0) as int;
    final upspeed = (t['upspeed'] ?? 0) as int;
    final eta = (t['eta'] ?? 8640000) as int;

    final themeColor = stateInfo['color'] as Color;
    final statusText = stateInfo['text'] as String;
    final statusIcon = stateInfo['icon'] as IconData;

    // —— meta：状态 · ↓速 · ↑速 · 百分比 · ETA，按需出现 ——
    final dotStyle =
        AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel));
    final spans = <InlineSpan>[];
    void addSpan(String text, {Color? color}) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '  ·  ', style: dotStyle));
      }
      spans.add(TextSpan(
        text: text,
        style: AppTypography.caption(color: color),
      ));
    }

    addSpan(statusText, color: themeColor);
    if (dlspeed > 0) addSpan('↓ ${_formatSpeed(dlspeed)}');
    if (upspeed > 0) addSpan('↑ ${_formatSpeed(upspeed)}');
    addSpan('${(progress * 100).toStringAsFixed(1)}%');
    if (eta > 0 && eta < 8640000 && progress < 1.0) {
      addSpan(_formatEta(eta));
    }

    // 0.5pt 真实 hairline：把原来 2pt 的进度/分隔线减细到与统计页一致的厚度，
    // 但仍保留进度——左侧按比例上色，右侧走 separator 灰，兼当行间分隔。
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final row = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(statusIcon, color: themeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body().copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _formatSize(totalSize),
                            style: AppTypography.caption(
                                color: AppColors.of(AppColors.tertiaryLabel)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: spans),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: hairline,
          child: Stack(
            children: [
              Container(color: AppColors.of(AppColors.separator)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(color: themeColor),
              ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hash.isEmpty ? null : () => _openDetail(t),
      child: row,
    );
  }

  // 底部 Tab：去阴影，仅 0.5pt 顶部细线；选中走 systemBlue。
  // 自带 SafeArea bottom 以适配 Home Indicator（CupertinoPageScaffold 不会代管）。
  Widget _buildBottomNav() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.of(AppColors.card),
        border: Border(
          top: BorderSide(
            color: AppColors.of(AppColors.separator),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              _buildNavItem(0, CupertinoIcons.arrow_down_circle_fill, '种子'),
              _buildNavItem(1, CupertinoIcons.chart_bar_alt_fill, '统计'),
              _buildNavItem(2, CupertinoIcons.search, '搜索'),
              _buildNavItem(3, CupertinoIcons.gear_alt, '设置'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? AppColors.accent
        : AppColors.of(AppColors.secondaryLabel);
    // 每格占 1/4 宽并整格可点（含按钮间空隙），消除原 spaceAround 的死区。
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentIndex != index) setState(() => _currentIndex = index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
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
  ServerConfig? _active;
  String? _version;
  bool _loading = true;

  // —— 应用自更新 ——
  String? _appVersion; // 当前 app 版本（package_info）
  UpdateCheck? _update; // 最近一次 GitHub 检查结果
  bool _checking = false;

  // —— 应用锁（Face ID）——
  bool _lockEnabled = false; // 开关当前状态
  bool _lockSupported = false; // 设备是否支持生物识别/设备密码
  bool _hasFaceId = false; // 是否含 Face ID（决定文案）
  bool _lockBusy = false; // 正在切换，避免重复触发验证

  @override
  void initState() {
    super.initState();
    _load();
    _loadAppVersion();
    _loadLock();
    _checkUpdate(silent: true); // 启动静默检查，有新版自动在设置页提示
  }

  Future<void> _loadLock() async {
    final supported = await AppLock.instance.canAuthenticate();
    final enabled = await AppLock.instance.isEnabled();
    final face = supported ? await AppLock.instance.hasFaceId() : false;
    if (!mounted) return;
    setState(() {
      _lockSupported = supported;
      _lockEnabled = enabled;
      _hasFaceId = face;
    });
  }

  // 切换应用锁：开启时先验证一次本人，确保不会把自己锁在门外。
  Future<void> _toggleLock(bool value) async {
    if (_lockBusy) return;
    setState(() => _lockBusy = true);
    try {
      if (value) {
        final ok = await AppLock.instance
            .authenticate('验证身份以开启应用锁');
        if (!ok) {
          if (mounted) {
            Toast.show(context, '验证未通过，未开启', type: ToastType.error);
          }
          return;
        }
      }
      await AppLock.instance.setEnabled(value);
      appLockGateKey.currentState?.syncEnabled(value);
      if (!mounted) return;
      setState(() => _lockEnabled = value);
    } finally {
      if (mounted) setState(() => _lockBusy = false);
    }
  }

  Future<void> _loadAppVersion() async {
    final v = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = v.version);
  }

  Future<void> _load() async {
    final active = await QBitApi.loadSavedConfig();
    if (!mounted) return;
    setState(() {
      _active = active;
      _version = null;
      _loading = false;
    });
    // 版本号异步获取，不阻塞 section 渲染
    if (active != null) {
      final v = await QBitApi().getAppVersion();
      if (!mounted) return;
      setState(() => _version = v);
    }
  }

  String _label(ServerConfig s) =>
      s.name.isNotEmpty ? s.name : s.url.replaceFirst(RegExp(r'^https?://'), '');

  Future<void> _openManagement() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ServerManagementPage(onSwitched: widget.onSwitched),
      ),
    );
    await _load();
  }

  // —— 检查更新 ——
  // silent=true：启动时静默检查，仅刷新提示，不打扰；
  // silent=false：用户主动点「检查更新」，结果用 toast / 弹窗即时反馈。
  Future<void> _checkUpdate({required bool silent}) async {
    if (_checking) return;
    setState(() => _checking = true);
    final result = await UpdateService.instance.check();
    if (!mounted) return;
    setState(() {
      _update = result;
      _checking = false;
    });
    if (silent) return;
    if (result.error != null) {
      Toast.show(context, result.error!, type: ToastType.error);
    } else if (result.hasUpdate && result.latest != null) {
      _showUpdateSheet(result.latest!);
    } else {
      Toast.show(context, '已是最新版本', type: ToastType.success);
    }
  }

  // App 内下载 ipa（带进度）→ 完成后唤起 iOS 原生分享面板，
  // 由用户选「拷贝到 TrollStore」完成安装。全程不依赖 apple-magnifier scheme。
  Future<void> _install(AppRelease rel) async {
    final progress = ValueNotifier<double>(0);
    final cancelToken = CancelToken();
    var dialogOpen = true;

    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('正在下载更新'),
        content: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(children: [
                      Container(color: AppColors.of(AppColors.separator)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: p.clamp(0.0, 1.0),
                        child: Container(
                            color: AppColors.accent.resolveFrom(ctx)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Text('${(p * 100).toStringAsFixed(0)}%',
                    style: AppTypography.subtitle()),
              ],
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => cancelToken.cancel('cancelled'),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    try {
      final path = await UpdateService.instance.downloadIpa(
        rel,
        cancelToken: cancelToken,
        onProgress: (r, t) {
          if (t > 0) progress.value = r / t;
        },
      );
      closeDialog();
      if (!mounted) return;
      // iPad 上分享面板是 popover，需锚点；iPhone 上忽略。
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await Share.shareXFiles(
        [XFile(path, name: 'Orbix-${rel.tag}.ipa')],
        subject: 'Orbix ${rel.tag}',
        sharePositionOrigin: origin,
      );
    } on DioException catch (e) {
      closeDialog();
      if (CancelToken.isCancel(e)) return; // 用户主动取消，静默
      if (mounted) {
        Toast.show(context, '下载失败，请检查网络', type: ToastType.error);
      }
    } catch (_) {
      closeDialog();
      if (mounted) Toast.show(context, '下载失败', type: ToastType.error);
    }
  }

  // 兜底：复制 .ipa 直链，便于手动用浏览器 / TrollStore 处理。
  Future<void> _copyIpaLink(AppRelease rel) async {
    await Clipboard.setData(ClipboardData(text: rel.ipaUrl));
    if (mounted) Toast.show(context, '下载链接已复制', type: ToastType.success);
  }

  String _fmtMB(int bytes) =>
      bytes <= 0 ? '' : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  // 新版本详情表：标题 + 更新日志（可滚动）+ 下载并安装。
  void _showUpdateSheet(AppRelease rel) {
    final size = _fmtMB(rel.ipaSize);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('新版本 ${rel.tag}'),
        message: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            rel.notes.isEmpty ? '本次没有提供更新说明。' : rel.notes,
            textAlign: TextAlign.left,
            style: AppTypography.subtitle(),
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _install(rel);
            },
            child: Text(size.isEmpty
                ? '下载并安装'
                : '下载并安装 · $size'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _copyIpaLink(rel);
            },
            child: const Text('复制下载链接'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  // 应用 section：发现新版高亮入口 + 当前版本 + 检查更新。
  // 安全 section：Face ID / 生物识别应用锁开关。
  Widget _buildSecuritySection() {
    final lockName = _hasFaceId ? 'Face ID' : '生物识别';
    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      header: Text('安全', style: AppTypography.sectionHeader()),
      footer: Text(
        '开启后，打开 App 或从后台切回时需通过 $lockName 验证。',
        style: AppTypography.subtitle(),
      ),
      children: [
        CupertinoListTile(
          leading: const Icon(
            CupertinoIcons.lock_shield_fill,
            color: AppColors.accent,
            size: 22,
          ),
          title: Text('$lockName 解锁', style: AppTypography.body()),
          trailing: _lockBusy
              ? const CupertinoActivityIndicator(radius: 9)
              : CupertinoSwitch(
                  value: _lockEnabled,
                  onChanged: _toggleLock,
                ),
        ),
      ],
    );
  }

  Widget _buildUpdateSection() {
    final up = _update;
    final rel = up?.latest;
    final hasUpdate = up?.hasUpdate == true && rel != null;
    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      header: Text('应用', style: AppTypography.sectionHeader()),
      children: [
        if (hasUpdate)
          CupertinoListTile.notched(
            leading: const Icon(
              CupertinoIcons.arrow_down_circle_fill,
              color: AppColors.accent,
              size: 22,
            ),
            title: Text(
              '发现新版本 ${rel.tag}',
              style: AppTypography.body().copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.accent.resolveFrom(context),
              ),
            ),
            subtitle: Text('点击查看更新内容并安装', style: AppTypography.subtitle()),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showUpdateSheet(rel),
          ),
        CupertinoListTile(
          title: Text('当前版本', style: AppTypography.body()),
          additionalInfo:
              Text(_appVersion ?? '—', style: AppTypography.subtitle()),
        ),
        CupertinoListTile.notched(
          title: Text('检查更新', style: AppTypography.body()),
          additionalInfo: _checking
              ? const CupertinoActivityIndicator(radius: 9)
              : Text(
                  up == null ? '' : (hasUpdate ? '有新版本' : '已是最新'),
                  style: AppTypography.subtitle(
                    color: hasUpdate
                        ? AppColors.accent.resolveFrom(context)
                        : AppColors.of(AppColors.tertiaryLabel),
                  ),
                ),
          trailing: const CupertinoListTileChevron(),
          onTap: _checking ? null : () => _checkUpdate(silent: false),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text('设置', style: AppTypography.largeTitle()),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                _loading
                    ? _buildServerSectionSkeleton()
                    : _buildServerSection(),
                if (_lockSupported) _buildSecuritySection(),
                _buildUpdateSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 服务器信息：inset grouped section，名称作为入口标题 + 详情三行。
  Widget _buildServerSection() {
    final s = _active;
    if (s == null) {
      return CupertinoListSection.insetGrouped(
        backgroundColor: AppColors.of(AppColors.groupedBg),
        decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
        header: Text('服务器', style: AppTypography.sectionHeader()),
        children: [
          CupertinoListTile.notched(
            leading: Icon(
              CupertinoIcons.circle,
              color: AppColors.of(AppColors.placeholder),
              size: 22,
            ),
            title: Text('未连接服务器', style: AppTypography.body()),
            subtitle: Text('点击管理服务器', style: AppTypography.subtitle()),
            trailing: const CupertinoListTileChevron(),
            onTap: _openManagement,
          ),
        ],
      );
    }

    final secure = s.url.contains('https') || s.port == '443';

    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      header: Text('服务器', style: AppTypography.sectionHeader()),
      children: [
        // 服务器名 = 入口标题，点击进入管理页
        CupertinoListTile.notched(
          title: Text(
            _label(s),
            style: AppTypography.cardTitle(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: _openManagement,
        ),
        // 地址：URL 紧跟一个绿色小锁图标，无任何色块底
        CupertinoListTile(
          title: Text('地址', style: AppTypography.body()),
          additionalInfo: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  s.url,
                  style: AppTypography.subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (secure) ...[
                const SizedBox(width: 6),
                const Icon(
                  CupertinoIcons.lock_fill,
                  size: 13,
                  color: AppColors.success,
                ),
              ],
            ],
          ),
        ),
        CupertinoListTile(
          title: Text('版本', style: AppTypography.body()),
          additionalInfo:
              Text(_version ?? '—', style: AppTypography.subtitle()),
        ),
        CupertinoListTile(
          title: Text('当前用户', style: AppTypography.body()),
          additionalInfo: Text(s.username, style: AppTypography.subtitle()),
        ),
      ],
    );
  }

  // 加载态：与正式 section 同构的骨架屏，避免「先小后大」的布局跳动。
  Widget _buildServerSectionSkeleton() {
    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      header: Text('服务器', style: AppTypography.sectionHeader()),
      children: const [
        CupertinoListTile(
          title: SkeletonBar(width: 160, height: 22),
          trailing: CupertinoListTileChevron(),
        ),
        CupertinoListTile(
          title: SkeletonBar(width: 40, height: 14),
          additionalInfo: SkeletonBar(width: 180, height: 14),
        ),
        CupertinoListTile(
          title: SkeletonBar(width: 40, height: 14),
          additionalInfo: SkeletonBar(width: 64, height: 14),
        ),
        CupertinoListTile(
          title: SkeletonBar(width: 64, height: 14),
          additionalInfo: SkeletonBar(width: 56, height: 14),
        ),
      ],
    );
  }
}
