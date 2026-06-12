import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/toast.dart';

/// 种子详情页：点击列表卡片进入。
///
/// 头部 Hero（百分比 + 状态 + 2pt 进度线 + 上下行速度），下方 inset grouped
/// 分组：传输 / 信息 / 文件。每 2 秒自动刷新。
class TorrentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> torrent;
  const TorrentDetailScreen({super.key, required this.torrent});

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen> {
  late Map<String, dynamic> _t;
  Map<String, dynamic> _props = {};
  List<dynamic> _files = [];
  Timer? _timer;

  String get _hash => (_t['hash'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _t = Map<String, dynamic>.from(widget.torrent);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = QBitApi();
    try {
      final results = await Future.wait([
        api.getTorrentByHash(_hash),
        api.getProperties(_hash),
        api.getTorrentFiles(_hash),
      ]);
      if (!mounted) return;
      setState(() {
        final info = results[0] as Map<String, dynamic>?;
        if (info != null) _t = info;
        final props = results[1] as Map<String, dynamic>?;
        if (props != null) _props = props;
        _files = results[2] as List<dynamic>;
      });
    } catch (e) {
      debugPrint('详情刷新失败: $e');
    }
  }

  // —— 格式化 ——
  String _fmtSize(num? bytes) {
    final b = (bytes ?? 0).toDouble();
    if (b <= 0) return '0 B';
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(2)} MB';
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  String _fmtSpeed(num? bytes) {
    final b = (bytes ?? 0);
    return b <= 0 ? '0 B/s' : '${_fmtSize(b)}/s';
  }

  String _fmtEta(int seconds) {
    if (seconds == 8640000 || seconds < 0) return '∞';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '—';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '$d天 $h小时';
    if (h > 0) return '$h小时 $m分';
    return '$m分';
  }

  String _fmtDate(num? epochSeconds) {
    final v = (epochSeconds ?? 0).toInt();
    if (v <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(v * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  // 状态 → text/color/icon；颜色全走 Cupertino 系统色 + AppColors 动态色。
  ({String text, Color color, IconData icon}) _parseState(String state) {
    switch (state) {
      case 'downloading':
      case 'metaDL':
      case 'forcedDL':
        return (
          text: '下载中',
          color: AppColors.accent,
          icon: CupertinoIcons.arrow_down_circle_fill,
        );
      case 'stalledDL':
        return (
          text: '等待下载',
          color: AppColors.accent,
          icon: CupertinoIcons.arrow_down_circle,
        );
      case 'uploading':
      case 'forcedUP':
        return (
          text: '上传中',
          color: AppColors.success,
          icon: CupertinoIcons.arrow_up_circle_fill,
        );
      case 'stalledUP':
        return (
          text: '做种中',
          color: AppColors.success,
          icon: CupertinoIcons.arrow_up_circle_fill,
        );
      case 'pausedDL':
      case 'stoppedDL':
        return (
          text: '已暂停',
          color: AppColors.of(AppColors.secondaryLabel),
          icon: CupertinoIcons.pause_circle_fill,
        );
      case 'pausedUP':
      case 'stoppedUP':
        return (
          text: '已完成',
          color: AppColors.of(AppColors.secondaryLabel),
          icon: CupertinoIcons.checkmark_circle_fill,
        );
      case 'checkingUP':
      case 'checkingDL':
      case 'checkingResumeData':
        return (
          text: '校验中',
          color: AppColors.warning,
          icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
        );
      case 'queuedDL':
      case 'queuedUP':
        return (
          text: '排队中',
          color: AppColors.of(AppColors.secondaryLabel),
          icon: CupertinoIcons.time,
        );
      case 'missingFiles':
        // 文件丢失：磁盘上找不到任务文件，与一般错误区分，给出更准确的标签。
        return (
          text: '文件丢失',
          color: AppColors.danger,
          icon: CupertinoIcons.exclamationmark_triangle_fill,
        );
      case 'error':
        return (
          text: '错误',
          color: AppColors.danger,
          icon: CupertinoIcons.exclamationmark_circle_fill,
        );
      default:
        return (
          text: state,
          color: AppColors.of(AppColors.tertiaryLabel),
          icon: CupertinoIcons.circle,
        );
    }
  }

  bool get _isPaused {
    final s = (_t['state'] ?? '').toString();
    return s.startsWith('stopped') || s.startsWith('paused');
  }

  // —— 操作 ——
  Future<void> _runAction(
      Future<bool> Function() action, String okMsg) async {
    final ok = await action();
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    _toast(ok ? okMsg : '操作失败，请重试', ok: ok);
  }

  void _confirmDelete() {
    final name = (_t['name'] ?? '').toString();
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
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await QBitApi().deleteTorrent(_hash, deleteFiles: false);
              if (ok) Get.back(result: true);
            },
            child: const Text('仅删任务'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await QBitApi().deleteTorrent(_hash, deleteFiles: true);
              if (ok) Get.back(result: true);
            },
            child: const Text('删任务和文件'),
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
    final info = _parseState((_t['state'] ?? '').toString());
    final progress = ((_t['progress'] ?? 0.0) as num).toDouble();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      navigationBar: CupertinoNavigationBar(
        backgroundColor:
            AppColors.of(AppColors.groupedBg).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: AppColors.of(AppColors.separator),
            width: 0.0, // 让系统按设备像素绘 hairline
          ),
        ),
        previousPageTitle: '种子',
        middle: Text('任务详情', style: AppTypography.navTitle()),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _confirmDelete,
          child: const Icon(
            CupertinoIcons.delete,
            color: AppColors.danger,
            size: 22,
          ),
        ),
      ),
      // 半透 CupertinoNavigationBar 会通过 MediaQuery 给 child 设 padding.top
      // = navBar+statusBar，但 CustomScrollView 不自动消费 —— 必须包一层
      // SafeArea 否则首个 sliver 会被挤到 nav bar 之下。
      child: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(info, progress)),
            SliverToBoxAdapter(child: _buildActions()),
            SliverToBoxAdapter(
                child: _buildErrorHint((_t['state'] ?? '').toString())),
            SliverToBoxAdapter(child: _buildTransferSection()),
            SliverToBoxAdapter(child: _buildInfoSection()),
            SliverToBoxAdapter(child: _buildFilesSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // —— Hero：名称 + 大百分比 + 状态 + 2pt 进度 + 速度脚注 ——
  Widget _buildHero(
      ({String text, Color color, IconData icon}) info, double progress) {
    final pct = (progress * 100).toStringAsFixed(1);
    final dl = (_t['dlspeed'] ?? 0) as int;
    final up = (_t['upspeed'] ?? 0) as int;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          // 名称
          Text(
            (_t['name'] ?? '未知任务').toString(),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body().copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.of(AppColors.secondaryLabel),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          // 大百分比：使用 themeColor 着色，配 hero 字重
          Text(
            '$pct%',
            style: AppTypography.hero(color: info.color),
          ),
          const SizedBox(height: 8),
          // 状态行：图标 + 文本
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(info.icon, size: 14, color: info.color),
              const SizedBox(width: 6),
              Text(
                info.text,
                style: AppTypography.subtitle(color: info.color).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 2pt 极细进度线（与种子行 / 文件行同构，方端无圆头，Tesla 风冷峻）
          SizedBox(
            height: 2,
            child: Stack(
              children: [
                Container(color: AppColors.of(AppColors.separator)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(color: info.color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 速度脚注
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.arrow_down,
                  size: 11, color: AppColors.of(AppColors.tertiaryLabel)),
              const SizedBox(width: 4),
              Text(_fmtSpeed(dl), style: AppTypography.caption()),
              const SizedBox(width: 28),
              Icon(CupertinoIcons.arrow_up,
                  size: 11, color: AppColors.of(AppColors.tertiaryLabel)),
              const SizedBox(width: 4),
              Text(_fmtSpeed(up), style: AppTypography.caption()),
            ],
          ),
        ],
      ),
    );
  }

  // 错误/文件丢失时的解释卡：说明可能原因 + 建议操作；其它状态不显示。
  Widget _buildErrorHint(String state) {
    final isMissing = state == 'missingFiles';
    if (state != 'error' && !isMissing) return const SizedBox.shrink();
    final title = isMissing ? '文件丢失' : '任务出错';
    final body = isMissing
        ? 'qBittorrent 在磁盘上找不到该任务的文件。常见原因：文件被移动 / 重命名 / 删除，或保存所在的磁盘、网络存储未挂载。\n\n若文件其实还在原处，点上方「校验」即可恢复；若确已删除，则需重新下载。'
        : '任务进入错误状态。常见原因：磁盘空间不足、保存路径不可写或磁盘掉线、文件被占用，或 Tracker / IO 异常。\n\n建议先检查服务器磁盘与保存路径，再点上方「校验」，或重新「启动」任务。';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.of(AppColors.card),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isMissing
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.exclamationmark_circle_fill,
              color: AppColors.danger,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body().copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: AppTypography.subtitle(
                      color: AppColors.of(AppColors.secondaryLabel),
                    ).copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —— 操作栏：4 个裸按钮，无底色 ——
  Widget _buildActions() {
    final actions = <_ActionSpec>[
      _isPaused
          ? _ActionSpec(
              icon: CupertinoIcons.play_fill,
              label: '启动',
              color: AppColors.success,
              onTap: () =>
                  _runAction(() => QBitApi().startTorrent(_hash), '已启动'),
            )
          : _ActionSpec(
              icon: CupertinoIcons.pause_fill,
              label: '暂停',
              color: AppColors.warning,
              onTap: () =>
                  _runAction(() => QBitApi().stopTorrent(_hash), '已暂停'),
            ),
      _ActionSpec(
        icon: CupertinoIcons.bolt_fill,
        label: '强制',
        color: AppColors.accent,
        onTap: () =>
            _runAction(() => QBitApi().forceStartTorrent(_hash), '已强制启动'),
      ),
      _ActionSpec(
        icon: CupertinoIcons.checkmark_shield,
        label: '校验',
        color: AppColors.accent,
        onTap: () =>
            _runAction(() => QBitApi().recheckTorrent(_hash), '已开始校验'),
      ),
      _ActionSpec(
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        label: '汇报',
        color: AppColors.accent,
        onTap: () =>
            _runAction(() => QBitApi().reannounceTorrent(_hash), '已重新汇报'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: actions
            .map((a) => Expanded(child: _buildActionButton(a)))
            .toList(),
      ),
    );
  }

  Widget _buildActionButton(_ActionSpec a) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: Size.zero,
      onPressed: a.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(a.icon, size: 22, color: a.color),
          const SizedBox(height: 6),
          Text(
            a.label,
            style: AppTypography.caption(
              color: AppColors.of(AppColors.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  // —— 传输 ——
  Widget _buildTransferSection() {
    final dl = (_t['dlspeed'] ?? 0) as int;
    final up = (_t['upspeed'] ?? 0) as int;
    final downloaded = _t['downloaded'] ?? _props['total_downloaded'];
    final uploaded = _t['uploaded'] ?? _props['total_uploaded'];
    final ratio =
        ((_t['ratio'] ?? _props['share_ratio'] ?? 0.0) as num).toDouble();
    final eta = (_t['eta'] ?? 8640000) as int;
    final seeds = _t['num_seeds'] ?? _props['seeds'] ?? 0;
    final peers = _t['num_leechs'] ?? _props['peers'] ?? 0;

    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      header: Text('传输', style: AppTypography.sectionHeader()),
      children: [
        _tile('下载速度', _fmtSpeed(dl)),
        _tile('上传速度', _fmtSpeed(up)),
        _tile('已下载', _fmtSize(downloaded as num?), muted: true),
        _tile('已上传', _fmtSize(uploaded as num?), muted: true),
        _tile('分享率', ratio.toStringAsFixed(2),
            valueColor: ratio >= 1.0 ? AppColors.warning : null),
        _tile('剩余时间', _fmtEta(eta), muted: true),
        _tile('连接 (做种 / 下载)', '$seeds / $peers', muted: true),
      ],
    );
  }

  // —— 信息（长字段如路径 / Hash 走 mono subtitle）——
  Widget _buildInfoSection() {
    final size = _t['total_size'] ?? _t['size'];
    final savePath =
        (_t['save_path'] ?? _props['save_path'] ?? '—').toString();
    final category = (_t['category'] ?? '').toString();
    final tags = (_t['tags'] ?? '').toString();
    final addedOn = _t['added_on'] ?? _props['addition_date'];
    final completionOn = _t['completion_on'] ?? _props['completion_date'];
    final elapsed = (_props['time_elapsed'] ?? 0) as int;
    final seedingTime = (_props['seeding_time'] ?? 0) as int;

    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      header: Text('信息', style: AppTypography.sectionHeader()),
      children: [
        _tile('总大小', _fmtSize(size as num?)),
        _monoTile('保存路径', savePath),
        if (category.isNotEmpty) _tile('分类', category),
        if (tags.isNotEmpty) _tile('标签', tags),
        _tile('添加时间', _fmtDate(addedOn as num?), muted: true),
        _tile('完成时间', _fmtDate(completionOn as num?), muted: true),
        _tile('活动时长', _fmtDuration(elapsed), muted: true),
        _tile('做种时长', _fmtDuration(seedingTime), muted: true),
        _monoTile('Hash', _hash),
      ],
    );
  }

  // —— 文件：单 inset 容器 + 每行底部 2pt 极细进度（同主屏种子行的形态）——
  Widget _buildFilesSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 20, 8),
            child: Text('文件 (${_files.length})',
                style: AppTypography.sectionHeader()),
          ),
          if (_files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.of(AppColors.card),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('暂无文件信息',
                      style: AppTypography.subtitle(
                          color: AppColors.of(AppColors.tertiaryLabel))),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.of(AppColors.card),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: List.generate(
                  _files.length,
                  (i) => _buildFileRow(_files[i] as Map),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileRow(Map f) {
    final name = (f['name'] ?? '').toString().split('/').last;
    final fsize = f['size'] as num?;
    final fprog = ((f['progress'] ?? 0.0) as num).toDouble();
    final done = fprog >= 1.0;
    final barColor =
        done ? AppColors.success : AppColors.accent;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _fmtSize(fsize),
                      style: AppTypography.caption(
                          color: AppColors.of(AppColors.tertiaryLabel)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${(fprog * 100).toStringAsFixed(1)}%',
                style: AppTypography.caption(
                  color: done
                      ? AppColors.success
                      : AppColors.of(AppColors.tertiaryLabel),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 2,
          child: Stack(
            children: [
              Container(color: AppColors.of(AppColors.separator)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fprog.clamp(0.0, 1.0),
                child: Container(color: barColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // —— 通用键值 tile：value 短，走 additionalInfo ——
  Widget _tile(
    String label,
    String value, {
    Color? valueColor,
    bool muted = false,
  }) {
    return CupertinoListTile(
      title: Text(label, style: AppTypography.body()),
      additionalInfo: Text(
        value,
        style: AppTypography.subtitle(
          color: valueColor ??
              (muted
                  ? AppColors.of(AppColors.tertiaryLabel)
                  : AppColors.of(AppColors.label)),
        ).copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  // —— 长字段（路径 / Hash）：value 走 subtitle 占满一行 + 等宽字体 ——
  Widget _monoTile(String label, String value) {
    return CupertinoListTile(
      title: Text(label, style: AppTypography.body()),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value,
          style: AppTypography.caption(
            color: AppColors.of(AppColors.tertiaryLabel),
          ).copyWith(fontFamily: 'Menlo'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ActionSpec {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionSpec({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
