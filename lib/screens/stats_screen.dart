import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/qbit_api.dart';
import '../theme/app_colors.dart';

/// 统计页：服务器仪表盘。
/// 实时速度、会话/累计传输量、全局分享率、磁盘剩余、连接状态、任务概览。
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Timer? _timer;
  Map<String, dynamic> _ss = {}; // server_state
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

  // —— 取值（server_state 优先，回退 transfer/info）——
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
        return const Color(0xFF34C759);
      case 'firewalled':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFFFF3B30);
    }
  }

  // 任务按状态分组计数
  Map<String, int> _counts() {
    int dl = 0, up = 0, paused = 0, checking = 0, error = 0;
    for (final t in _torrents) {
      final s = (t is Map ? t['state'] : '').toString();
      if (['downloading', 'metaDL', 'forcedDL', 'stalledDL', 'queuedDL'].contains(s)) {
        dl++;
      } else if (['uploading', 'forcedUP', 'stalledUP', 'queuedUP'].contains(s)) {
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
    final c = _counts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('统计',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.of(AppColors.label),
                    letterSpacing: -0.5)),
          ),
        ),
        Expanded(
          child: !_loaded
              ? const Center(child: CupertinoActivityIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // 实时速度
                      Row(
                        children: [
                          Expanded(
                            child: _speedCard('实时下载', _fmtSpeed(_g('dl_info_speed')),
                                CupertinoIcons.arrow_down_circle_fill, const Color(0xFF5AC8FA)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _speedCard('实时上传', _fmtSpeed(_g('up_info_speed')),
                                CupertinoIcons.arrow_up_circle_fill, const Color(0xFF007AFF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('传输量'),
                      _card([
                        _row('本次会话 · 下载', _fmtSize(_g('dl_info_data'))),
                        _row('本次会话 · 上传', _fmtSize(_g('up_info_data'))),
                        _row('累计下载', _fmtSize(_g('alltime_dl'))),
                        _row('累计上传', _fmtSize(_g('alltime_ul'))),
                        _row('全局分享率', _g('global_ratio').toStringAsFixed(2),
                            highlight: const Color(0xFFFF9500)),
                        _row('本次浪费', _fmtSize(_g('total_wasted_session'))),
                      ]),
                      const SizedBox(height: 22),
                      _sectionTitle('连接'),
                      _card([
                        _row('连接状态', _connText, highlight: _connColor),
                        _row('DHT 节点', _g('dht_nodes').toInt().toString()),
                        _row('对等连接数', _g('total_peer_connections').toInt().toString()),
                        _row('下载限速',
                            _g('dl_rate_limit') <= 0 ? '无限制' : _fmtSpeed(_g('dl_rate_limit'))),
                        _row('上传限速',
                            _g('up_rate_limit') <= 0 ? '无限制' : _fmtSpeed(_g('up_rate_limit'))),
                      ]),
                      const SizedBox(height: 22),
                      _sectionTitle('磁盘'),
                      _card([
                        _row('默认保存路径剩余', _fmtSize(_g('free_space_on_disk')),
                            highlight: const Color(0xFF34C759)),
                      ]),
                      const SizedBox(height: 22),
                      _sectionTitle('任务概览'),
                      _countGrid(c),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _speedCard(String title, String speed, IconData icon, Color color) {
    final parts = speed.split(' ');
    final number = parts.isNotEmpty ? parts[0] : speed;
    final unit = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(AppColors.card),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              ),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countGrid(Map<String, int> c) {
    final items = [
      ['总任务', c['total']!, const Color(0xFF007AFF), CupertinoIcons.square_stack_3d_up_fill],
      ['下载中', c['dl']!, const Color(0xFF5AC8FA), CupertinoIcons.arrow_down_circle_fill],
      ['做种中', c['up']!, const Color(0xFF34C759), CupertinoIcons.arrow_up_circle_fill],
      ['已暂停', c['paused']!, const Color(0xFF8E8E93), CupertinoIcons.pause_circle_fill],
      ['校验中', c['checking']!, const Color(0xFFFF9500), CupertinoIcons.arrow_2_circlepath_circle_fill],
      ['错误', c['error']!, const Color(0xFFFF3B30), CupertinoIcons.exclamationmark_circle_fill],
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.0,
      children: items.map((it) {
        final label = it[0] as String;
        final value = it[1] as int;
        final color = it[2] as Color;
        final icon = it[3] as IconData;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.of(AppColors.card),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text('$value',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.of(AppColors.label))),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 13, color: AppColors.of(AppColors.secondaryLabel))),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.of(AppColors.card),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _row(String label, String value, {Color? highlight}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14, color: AppColors.of(AppColors.secondaryLabel))),
            const SizedBox(width: 16),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: highlight ?? AppColors.of(AppColors.label))),
            ),
          ],
        ),
      );
}
