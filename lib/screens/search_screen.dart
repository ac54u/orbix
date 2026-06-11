import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import 'torrent_detail_screen.dart';

/// 搜索页：本地任务搜索 + qB 联网搜索引擎（顶部切换）。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  int _mode = 0; // 0=本地 1=联网

  // —— 本地 ——
  List<dynamic> _allTorrents = [];
  bool _localLoaded = false;

  // —— 联网 ——
  bool _searching = false;
  int? _searchId;
  List<dynamic> _results = [];
  String? _onlineNotice; // 无插件 / 出错时的友好提示
  bool _onlineSearched = false; // 是否已发起过一次搜索

  static const Color _accent = Color(0xFF007AFF);

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void dispose() {
    _cleanupSearch();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    try {
      final list = await QBitApi().getTorrents();
      if (!mounted) return;
      setState(() {
        _allTorrents = list;
        _localLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _localLoaded = true);
    }
  }

  void _cleanupSearch() {
    final id = _searchId;
    if (id != null) {
      final api = QBitApi();
      api.stopSearch(id);
      api.deleteSearch(id);
      _searchId = null;
    }
  }

  // —— 本地筛选 ——
  List<dynamic> get _localResults {
    final q = _queryCtrl.text.trim().toLowerCase();
    final list = _allTorrents.where((t) {
      if (t is! Map) return false;
      if (q.isEmpty) return true;
      return (t['name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) =>
        ((b['added_on'] ?? 0) as int).compareTo((a['added_on'] ?? 0) as int));
    return list;
  }

  // —— 联网搜索 ——
  Future<void> _runOnlineSearch() async {
    final pattern = _queryCtrl.text.trim();
    if (pattern.isEmpty) return;
    FocusScope.of(context).unfocus();
    final api = QBitApi();

    setState(() {
      _onlineNotice = null;
      _onlineSearched = true;
      _searching = true;
      _results = [];
    });

    // 检查插件
    final plugins = await api.getSearchPlugins();
    if (!mounted) return;
    if (plugins.isEmpty) {
      setState(() {
        _searching = false;
        _onlineNotice =
            '服务端未安装搜索插件。\n请在 qBittorrent 桌面端「搜索 → 搜索插件」中安装并启用插件后再试。';
      });
      return;
    }
    final hasEnabled =
        plugins.any((p) => p is Map && p['enabled'] == true);

    // 清掉上一次的 job
    _cleanupSearch();

    final id = await api.startSearch(pattern,
        plugins: hasEnabled ? 'enabled' : 'all');
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _searching = false;
        _onlineNotice = '无法启动搜索，请稍后重试。';
      });
      return;
    }
    _searchId = id;
    _pollSearch(id);
  }

  Future<void> _pollSearch(int id) async {
    // 最多轮询 ~40 秒，期间持续把已得到的结果刷到界面
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _searchId != id) return;
      final res = await QBitApi().getSearchResults(id);
      if (!mounted || _searchId != id) return;
      if (res != null) {
        final results = (res['results'] as List?) ?? [];
        results.sort((a, b) => ((b is Map ? b['nbSeeders'] : 0) as num? ?? 0)
            .compareTo((a is Map ? a['nbSeeders'] : 0) as num? ?? 0));
        setState(() => _results = results);
        if ((res['status'] ?? '').toString() == 'Stopped') {
          setState(() => _searching = false);
          return;
        }
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _addResult(Map result) async {
    final url = (result['fileUrl'] ?? '').toString();
    final name = (result['fileName'] ?? '').toString();
    if (url.isEmpty) {
      _toast('该结果没有可用的下载链接', ok: false);
      return;
    }
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('添加任务'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(name, maxLines: 4, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final err = await QBitApi().addMagnet(url);
    if (!mounted) return;
    _toast(err ?? '已添加到下载队列', ok: err == null);
  }

  void _toast(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  // —— 格式化 ——
  String _fmtSize(num? bytes) {
    final b = (bytes ?? 0).toDouble();
    if (b < 0) return '未知';
    if (b == 0) return '0 B';
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(2)} MB';
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> _stateInfo(String state) {
    const blue = Color(0xFF007AFF);
    const green = Color(0xFF34C759);
    const grey = Color(0xFF8E8E93);
    const orange = Color(0xFFFF9500);
    const red = Color(0xFFFF3B30);
    if (['downloading', 'metaDL', 'forcedDL', 'stalledDL'].contains(state)) {
      return {'color': blue, 'icon': CupertinoIcons.arrow_down_circle_fill};
    }
    if (['uploading', 'forcedUP', 'stalledUP'].contains(state)) {
      return {'color': green, 'icon': CupertinoIcons.arrow_up_circle_fill};
    }
    if (state.startsWith('paused') || state.startsWith('stopped')) {
      return {'color': grey, 'icon': CupertinoIcons.pause_circle_fill};
    }
    if (state.startsWith('checking')) {
      return {'color': orange, 'icon': CupertinoIcons.arrow_2_circlepath_circle_fill};
    }
    if (state == 'error' || state == 'missingFiles') {
      return {'color': red, 'icon': CupertinoIcons.exclamationmark_circle_fill};
    }
    return {'color': grey, 'icon': CupertinoIcons.circle};
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('搜索',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.of(AppColors.label),
                    letterSpacing: -0.5)),
          ),
        ),
        const SizedBox(height: 12),
        // 模式切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _mode,
            children: {
              0: _segLabel('本地任务'),
              1: _segLabel('联网搜种'),
            },
            onValueChanged: (v) {
              if (v == null) return;
              setState(() => _mode = v);
              if (v == 0) _loadLocal();
            },
          ),
        ),
        const SizedBox(height: 14),
        // 搜索框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CupertinoSearchTextField(
            controller: _queryCtrl,
            placeholder: _mode == 0 ? '搜索我的任务' : '输入关键字后回车搜索',
            style: TextStyle(color: AppColors.of(AppColors.label)),
            backgroundColor: AppColors.of(AppColors.card),
            onChanged: (_) {
              if (_mode == 0) setState(() {});
            },
            onSubmitted: (_) {
              if (_mode == 1) _runOnlineSearch();
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _mode == 0 ? _buildLocal() : _buildOnline()),
      ],
    );
  }

  Widget _segLabel(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t,
            style: TextStyle(fontSize: 14, color: AppColors.of(AppColors.label))),
      );

  // —— 本地结果 ——
  Widget _buildLocal() {
    if (!_localLoaded) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final list = _localResults;
    if (list.isEmpty) {
      return _emptyHint(
          _queryCtrl.text.trim().isEmpty ? '暂无任务' : '没有匹配「${_queryCtrl.text.trim()}」的任务');
    }
    return RefreshIndicator(
      onRefresh: _loadLocal,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final t = list[i] as Map;
          final info = _stateInfo((t['state'] ?? '').toString());
          final progress = (t['progress'] ?? 0.0).toDouble();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await Get.to(() =>
                  TorrentDetailScreen(torrent: Map<String, dynamic>.from(t)));
              _loadLocal();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.of(AppColors.card),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(info['icon'], color: info['color'], size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((t['name'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.of(AppColors.label))),
                        const SizedBox(height: 4),
                        Text(
                            '${_fmtSize((t['total_size'] ?? 0) as num)}  ·  ${(progress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right,
                      size: 16, color: Color(0xFFC7C7CC)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // —— 联网结果 ——
  Widget _buildOnline() {
    if (_onlineNotice != null) {
      return _emptyHint(_onlineNotice!, icon: CupertinoIcons.exclamationmark_circle);
    }
    if (!_onlineSearched) {
      return _emptyHint('输入关键字后回车，跨站点搜索种子',
          icon: CupertinoIcons.search);
    }
    return Column(
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(width: 8),
                Text('搜索中…已找到 ${_results.length} 条',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? (_searching
                  ? const SizedBox.shrink()
                  : _emptyHint('没有找到结果，换个关键字试试'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _onlineRow(_results[i] as Map),
                ),
        ),
      ],
    );
  }

  Widget _onlineRow(Map r) {
    final name = (r['fileName'] ?? '').toString();
    final size = r['fileSize'] as num?;
    final seeders = (r['nbSeeders'] ?? -1) as num;
    final leechers = (r['nbLeechers'] ?? -1) as num;
    final site = Uri.tryParse((r['siteUrl'] ?? '').toString())?.host ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _addResult(r),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.of(AppColors.card),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(AppColors.label))),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(CupertinoIcons.doc, _fmtSize(size), const Color(0xFF8E8E93)),
                const SizedBox(width: 12),
                _chip(CupertinoIcons.arrow_up_circle_fill,
                    seeders < 0 ? '?' : seeders.toInt().toString(), const Color(0xFF34C759)),
                const SizedBox(width: 12),
                _chip(CupertinoIcons.arrow_down_circle_fill,
                    leechers < 0 ? '?' : leechers.toInt().toString(), const Color(0xFFFF9500)),
                const Spacer(),
                const Icon(CupertinoIcons.add_circled,
                    size: 20, color: _accent),
              ],
            ),
            if (site.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(site,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAEAEB2))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.of(AppColors.secondaryLabel),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _emptyHint(String text, {IconData icon = CupertinoIcons.tray}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 46, color: AppColors.of(AppColors.placeholder)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF8E8E93), height: 1.5)),
        ),
      ],
    );
  }
}
