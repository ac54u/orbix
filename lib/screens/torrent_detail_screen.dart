import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/qbit_api.dart';
import '../theme/app_colors.dart';

/// 种子详情页：点击列表卡片进入。
/// 展示状态、进度、传输统计、属性与文件列表，并提供常用操作。
class TorrentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> torrent; // 进入时的快照，先渲染再轮询更新
  const TorrentDetailScreen({super.key, required this.torrent});

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen> {
  late Map<String, dynamic> _t;
  Map<String, dynamic> _props = {};
  List<dynamic> _files = [];
  Timer? _timer;

  static const Color _accent = Color(0xFF007AFF);

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
    if (d > 0) return '${d}天 ${h}小时';
    if (h > 0) return '${h}小时 ${m}分';
    return '${m}分';
  }

  String _fmtDate(num? epochSeconds) {
    final v = (epochSeconds ?? 0).toInt();
    if (v <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(v * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

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
        return {'text': '下载中', 'color': blue, 'icon': CupertinoIcons.arrow_down_circle_fill};
      case 'stalledDL':
        return {'text': '等待下载', 'color': blue, 'icon': CupertinoIcons.arrow_down_circle};
      case 'uploading':
      case 'forcedUP':
        return {'text': '上传中', 'color': green, 'icon': CupertinoIcons.arrow_up_circle_fill};
      case 'stalledUP':
        return {'text': '做种中', 'color': green, 'icon': CupertinoIcons.arrow_up_circle_fill};
      case 'pausedDL':
      case 'stoppedDL':
        return {'text': '已暂停', 'color': grey, 'icon': CupertinoIcons.pause_circle_fill};
      case 'pausedUP':
      case 'stoppedUP':
        return {'text': '已完成', 'color': grey, 'icon': CupertinoIcons.checkmark_circle_fill};
      case 'checkingUP':
      case 'checkingDL':
      case 'checkingResumeData':
        return {'text': '校验中', 'color': orange, 'icon': CupertinoIcons.arrow_2_circlepath_circle_fill};
      case 'queuedDL':
      case 'queuedUP':
        return {'text': '排队中', 'color': grey, 'icon': CupertinoIcons.time};
      case 'error':
      case 'missingFiles':
        return {'text': '错误', 'color': red, 'icon': CupertinoIcons.exclamationmark_circle_fill};
      default:
        return {'text': state, 'color': grey, 'icon': CupertinoIcons.circle};
    }
  }

  bool get _isPaused {
    final s = (_t['state'] ?? '').toString();
    return s.startsWith('stopped') || s.startsWith('paused');
  }

  // —— 操作 ——
  Future<void> _runAction(Future<bool> Function() action, String okMsg) async {
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
    AppColors.watch(context);
    final state = (_t['state'] ?? '').toString();
    final info = _parseState(state);
    final Color themeColor = info['color'];
    final progress = (_t['progress'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      appBar: AppBar(
        backgroundColor: AppColors.of(AppColors.groupedBg),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Get.back(),
          child: const Icon(CupertinoIcons.back, color: _accent),
        ),
        title: Text('任务详情',
            style: TextStyle(
                color: AppColors.of(AppColors.label),
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _confirmDelete,
            child: const Icon(CupertinoIcons.delete, color: Color(0xFFFF3B30), size: 22),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _header(info, themeColor, progress),
            const SizedBox(height: 20),
            _actionsBar(),
            const SizedBox(height: 20),
            _sectionTitle('传输'),
            _transferCard(),
            const SizedBox(height: 20),
            _sectionTitle('信息'),
            _infoCard(),
            const SizedBox(height: 20),
            _sectionTitle('文件 (${_files.length})'),
            _filesCard(),
          ],
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> info, Color themeColor, double progress) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.of(AppColors.card),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(info['icon'], color: themeColor, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (_t['name'] ?? '未知任务').toString(),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(AppColors.label)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(info['text'],
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) => Container(
              height: 6,
              width: c.maxWidth,
              decoration: BoxDecoration(
                  color: AppColors.of(AppColors.separator),
                  borderRadius: BorderRadius.circular(3)),
              child: Row(
                children: [
                  Container(
                    width: c.maxWidth * progress.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                        color: themeColor, borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsBar() {
    return Row(
      children: [
        if (_isPaused)
          _actionButton(CupertinoIcons.play_fill, '启动', _accent,
              () => _runAction(() => QBitApi().startTorrent(_hash), '已启动'))
        else
          _actionButton(CupertinoIcons.pause_fill, '暂停', const Color(0xFFFF9500),
              () => _runAction(() => QBitApi().stopTorrent(_hash), '已暂停')),
        const SizedBox(width: 12),
        _actionButton(CupertinoIcons.bolt_fill, '强制', const Color(0xFF34C759),
            () => _runAction(() => QBitApi().forceStartTorrent(_hash), '已强制启动')),
        const SizedBox(width: 12),
        _actionButton(CupertinoIcons.checkmark_shield, '校验', const Color(0xFF8E8E93),
            () => _runAction(() => QBitApi().recheckTorrent(_hash), '已开始校验')),
        const SizedBox(width: 12),
        _actionButton(CupertinoIcons.antenna_radiowaves_left_right, '汇报', const Color(0xFF5AC8FA),
            () => _runAction(() => QBitApi().reannounceTorrent(_hash), '已重新汇报')),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.of(AppColors.card),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.of(AppColors.secondaryLabel))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 13, color: AppColors.of(AppColors.secondaryLabel))),
      );

  Widget _transferCard() {
    final dl = (_t['dlspeed'] ?? 0) as int;
    final up = (_t['upspeed'] ?? 0) as int;
    final downloaded = _t['downloaded'] ?? _props['total_downloaded'];
    final uploaded = _t['uploaded'] ?? _props['total_uploaded'];
    final ratio = (_t['ratio'] ?? _props['share_ratio'] ?? 0.0).toDouble();
    final eta = (_t['eta'] ?? 8640000) as int;
    final seeds = _t['num_seeds'] ?? _props['seeds'] ?? 0;
    final peers = _t['num_leechs'] ?? _props['peers'] ?? 0;

    return _cardOf([
      _row('下载速度', _fmtSpeed(dl)),
      _row('上传速度', _fmtSpeed(up)),
      _row('已下载', _fmtSize(downloaded as num?)),
      _row('已上传', _fmtSize(uploaded as num?)),
      _row('分享率', ratio.toStringAsFixed(2)),
      _row('剩余时间', _fmtEta(eta)),
      _row('连接 (做种/下载)', '$seeds / $peers'),
    ]);
  }

  Widget _infoCard() {
    final size = _t['total_size'] ?? _t['size'];
    final savePath = (_t['save_path'] ?? _props['save_path'] ?? '—').toString();
    final category = (_t['category'] ?? '').toString();
    final tags = (_t['tags'] ?? '').toString();
    final addedOn = _t['added_on'] ?? _props['addition_date'];
    final completionOn = _t['completion_on'] ?? _props['completion_date'];
    final elapsed = (_props['time_elapsed'] ?? 0) as int;
    final seedingTime = (_props['seeding_time'] ?? 0) as int;

    return _cardOf([
      _row('总大小', _fmtSize(size as num?)),
      _row('保存路径', savePath, mono: true),
      if (category.isNotEmpty) _row('分类', category),
      if (tags.isNotEmpty) _row('标签', tags),
      _row('添加时间', _fmtDate(addedOn as num?)),
      _row('完成时间', _fmtDate(completionOn as num?)),
      _row('活动时长', _fmtDuration(elapsed)),
      _row('做种时长', _fmtDuration(seedingTime)),
      _row('Hash', _hash, mono: true),
    ]);
  }

  Widget _filesCard() {
    if (_files.isEmpty) {
      return _cardOf([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('暂无文件信息',
                style: TextStyle(
                    fontSize: 13, color: AppColors.of(AppColors.secondaryLabel))),
          ),
        ),
      ]);
    }
    final rows = <Widget>[];
    for (var i = 0; i < _files.length; i++) {
      final f = _files[i] as Map;
      final name = (f['name'] ?? '').toString().split('/').last;
      final fsize = f['size'] as num?;
      final fprog = (f['progress'] ?? 0.0).toDouble();
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.of(AppColors.label))),
                ),
                const SizedBox(width: 8),
                Text(_fmtSize(fsize),
                    style: TextStyle(
                        fontSize: 12, color: AppColors.of(AppColors.secondaryLabel))),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fprog.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.of(AppColors.separator),
                valueColor: AlwaysStoppedAnimation(
                    fprog >= 1.0 ? const Color(0xFF34C759) : _accent),
              ),
            ),
          ],
        ),
      ));
      if (i != _files.length - 1) {
        rows.add(Container(
            height: 0.5,
            color: AppColors.of(AppColors.separator),
            margin: const EdgeInsets.only(left: 16)));
      }
    }
    return _cardOf(rows, padded: false);
  }

  Widget _cardOf(List<Widget> children, {bool padded = true}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(AppColors.card),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padded ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _row(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: AppColors.of(AppColors.secondaryLabel))),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.of(AppColors.label),
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
