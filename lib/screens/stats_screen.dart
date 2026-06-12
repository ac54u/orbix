import 'dart:async';
import 'package:flutter/cupertino.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';

/// 统计页：服务器仪表盘。
///
/// 顶部 Hero：总速度居中超大 + 超细字重。
/// 下方分组：传输量 / 连接 / 磁盘 / 任务概览，全部 inset grouped。
/// 非高频关注的次要数据弱化为 tertiaryLabel 灰。
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Timer? _timer;
  Map<String, dynamic> _ss = {};
  Map<String, dynamic> _transfer = {};
  List<dynamic> _torrents = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
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
        api.syncMainData(0),
        api.getTransferInfo(),
        api.getTorrents(),
      ]);
      if (!mounted) return;
      setState(() {
        final main = results[0] as Map<String, dynamic>?;
        final ss = main?['server_state'];
        if (ss is Map) _ss = Map<String, dynamic>.from(ss);
        _transfer = results[1] as Map<String, dynamic>;
        _torrents = results[2] as List<dynamic>;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('统计刷新失败: $e');
    }
  }

  // —— server_state 优先，回退 transfer/info ——
  num _g(String key, [num fallback = 0]) {
    final v = _ss[key] ?? _transfer[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  // —— 格式化 ——
  String _fmtSize(num? bytes) {
    final b = (bytes ?? 0).toDouble();
    if (b <= 0) return '0 B';
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(2)} MB';
    if (b < 1099511627776) return '${(b / 1073741824).toStringAsFixed(2)} GB';
    return '${(b / 1099511627776).toStringAsFixed(2)} TB';
  }

  String _fmtSpeed(num? bytes) =>
      (bytes ?? 0) <= 0 ? '0 B/s' : '${_fmtSize(bytes)}/s';

  /// 把总字节数拆成 (数字, 单位)，方便 Hero 区分两段排印。
  (String, String) _heroSpeed(num totalBytes) {
    final b = totalBytes.toDouble();
    if (b <= 0) return ('0', 'B/s');
    if (b < 1024) return (b.toStringAsFixed(0), 'B/s');
    if (b < 1024 * 1024) return ((b / 1024).toStringAsFixed(1), 'KB/s');
    if (b < 1024 * 1024 * 1024) {
      return ((b / 1048576).toStringAsFixed(2), 'MB/s');
    }
    return ((b / 1073741824).toStringAsFixed(2), 'GB/s');
  }

  String get _connText {
    final s = (_ss['connection_status'] ?? '').toString();
    switch (s) {
      case 'connected':
        return '已连接';
      case 'firewalled':
        return '受防火墙限制';
      case 'disconnected':
        return '未连接';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  Color get _connColor {
    switch ((_ss['connection_status'] ?? '').toString()) {
      case 'connected':
        return AppColors.success;
      case 'firewalled':
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  Map<String, int> _counts() {
    int dl = 0, up = 0, paused = 0, checking = 0, error = 0;
    for (final t in _torrents) {
      final s = (t is Map ? t['state'] : '').toString();
      if (['downloading', 'metaDL', 'forcedDL', 'stalledDL', 'queuedDL']
          .contains(s)) {
        dl++;
      } else if (['uploading', 'forcedUP', 'stalledUP', 'queuedUP']
          .contains(s)) {
        up++;
      } else if (s.startsWith('paused') || s.startsWith('stopped')) {
        paused++;
      } else if (s.startsWith('checking')) {
        checking++;
      } else if (s == 'error' || s == 'missingFiles') {
        error++;
      }
    }
    return {
      'total': _torrents.length,
      'dl': dl,
      'up': up,
      'paused': paused,
      'checking': checking,
      'error': error,
    };
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text('统计', style: AppTypography.largeTitle()),
        ),
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              SliverToBoxAdapter(
                child: _loaded ? _buildContent() : _buildSkeleton(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final dl = _g('dl_info_speed');
    final up = _g('up_info_speed');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(dl, up),
        _buildTransferSection(),
        _buildConnectionSection(),
        _buildDiskSection(),
        _buildOverviewSection(_counts()),
      ],
    );
  }

  // —— Hero：居中超大总速 + 单位 + 上下行分拆细节 ——
  Widget _buildHero(num dl, num up) {
    final (number, unit) = _heroSpeed(dl + up);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Column(
        children: [
          Text(
            '当前总速',
            style: AppTypography.caption(
                color: AppColors.of(AppColors.tertiaryLabel)),
          ),
          const SizedBox(height: 10),
          // 总速数字：56pt w200，启用 tabular figures 防抖。
          Text(number, style: AppTypography.hero()),
          const SizedBox(height: 6),
          Text(
            unit,
            style: AppTypography.subtitle().copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 22),
          // 下/上行细分：极小字号 + 中灰色，作为 Hero 的脚注。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.arrow_down,
                  size: 11,
                  color: AppColors.of(AppColors.tertiaryLabel)),
              const SizedBox(width: 4),
              Text(_fmtSpeed(dl), style: AppTypography.caption()),
              const SizedBox(width: 28),
              Icon(CupertinoIcons.arrow_up,
                  size: 11,
                  color: AppColors.of(AppColors.tertiaryLabel)),
              const SizedBox(width: 4),
              Text(_fmtSpeed(up), style: AppTypography.caption()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferSection() {
    return CupertinoListSection.insetGrouped(
      header: Text('传输量', style: AppTypography.sectionHeader()),
      children: [
        _tile('本次会话 · 下载', _fmtSize(_g('dl_info_data'))),
        _tile('本次会话 · 上传', _fmtSize(_g('up_info_data'))),
        _tile('累计下载', _fmtSize(_g('alltime_dl'))),
        _tile('累计上传', _fmtSize(_g('alltime_ul'))),
        _tile('全局分享率', _g('global_ratio').toStringAsFixed(2),
            valueColor: AppColors.warning),
        _tile('本次浪费', _fmtSize(_g('total_wasted_session')), muted: true),
      ],
    );
  }

  Widget _buildConnectionSection() {
    return CupertinoListSection.insetGrouped(
      header: Text('连接', style: AppTypography.sectionHeader()),
      children: [
        _tile('连接状态', _connText, valueColor: _connColor),
        _tile('DHT 节点', _g('dht_nodes').toInt().toString(), muted: true),
        _tile('对等连接数', _g('total_peer_connections').toInt().toString(),
            muted: true),
        _tile(
          '下载限速',
          _g('dl_rate_limit') <= 0 ? '无限制' : _fmtSpeed(_g('dl_rate_limit')),
          muted: true,
        ),
        _tile(
          '上传限速',
          _g('up_rate_limit') <= 0 ? '无限制' : _fmtSpeed(_g('up_rate_limit')),
          muted: true,
        ),
      ],
    );
  }

  Widget _buildDiskSection() {
    return CupertinoListSection.insetGrouped(
      header: Text('磁盘', style: AppTypography.sectionHeader()),
      children: [
        _tile('默认保存路径剩余', _fmtSize(_g('free_space_on_disk')),
            muted: true),
      ],
    );
  }

  Widget _buildOverviewSection(Map<String, int> c) {
    final items = <List<dynamic>>[
      ['总任务', c['total']!, AppColors.accent,
          CupertinoIcons.square_stack_3d_up_fill],
      ['下载中', c['dl']!, const Color(0xFF4070F2),
          CupertinoIcons.arrow_down_circle_fill],
      ['做种中', c['up']!, AppColors.success,
          CupertinoIcons.arrow_up_circle_fill],
      ['已暂停', c['paused']!, AppColors.of(AppColors.secondaryLabel),
          CupertinoIcons.pause_circle_fill],
      ['校验中', c['checking']!, AppColors.warning,
          CupertinoIcons.arrow_2_circlepath_circle_fill],
      ['错误', c['error']!, AppColors.danger,
          CupertinoIcons.exclamationmark_circle_fill],
    ];
    return CupertinoListSection.insetGrouped(
      header: Text('任务概览', style: AppTypography.sectionHeader()),
      children: items.map((it) {
        final label = it[0] as String;
        final value = it[1] as int;
        final color = it[2] as Color;
        final icon = it[3] as IconData;
        final isZero = value == 0;
        return CupertinoListTile.notched(
          leading: Icon(icon, color: color, size: 22),
          title: Text(label, style: AppTypography.body()),
          additionalInfo: Text(
            '$value',
            style: AppTypography.subtitle().copyWith(
              fontWeight: FontWeight.w600,
              color: isZero
                  ? AppColors.of(AppColors.tertiaryLabel)
                  : AppColors.of(AppColors.label),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 通用键值行：muted=true 时把值色压到 tertiaryLabel（背景信息）。
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

  // —— 加载态：骨架屏，结构与正式页同构，避免布局跳动 ——
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 36, 20, 36),
          child: Column(
            children: [
              SkeletonBar(width: 60, height: 12),
              SizedBox(height: 14),
              SkeletonBar(
                width: 200,
                height: 56,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 10),
              SkeletonBar(width: 60, height: 14),
              SizedBox(height: 22),
              SkeletonBar(width: 220, height: 12),
            ],
          ),
        ),
        _sectionSkeleton(6),
        _sectionSkeleton(5),
        _sectionSkeleton(1),
        _sectionSkeleton(6, withLeading: true),
      ],
    );
  }

  Widget _sectionSkeleton(int rowCount, {bool withLeading = false}) {
    return CupertinoListSection.insetGrouped(
      header: const SkeletonBar(width: 60, height: 12),
      children: List.generate(
        rowCount,
        (_) => CupertinoListTile(
          leading: withLeading
              ? const SkeletonBar(
                  width: 22,
                  height: 22,
                  borderRadius: BorderRadius.all(Radius.circular(11)),
                )
              : null,
          title: const SkeletonBar(width: 100, height: 14),
          additionalInfo: const SkeletonBar(width: 56, height: 14),
        ),
      ),
    );
  }
}
