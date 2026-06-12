import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';
import 'torrent_detail_screen.dart';

/// 搜索页：本地任务搜索 + qB 联网搜索引擎（顶部分段切换）。
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
  bool _onlineSearched = false;

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
    final hasEnabled = plugins.any((p) => p is Map && p['enabled'] == true);

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
    Toast.show(context, msg, type: ok ? ToastType.success : ToastType.error);
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

  // 状态 → (color, icon)；颜色全走 Cupertino 系统语义色 / AppColors 动态色。
  ({Color color, IconData icon}) _stateInfo(String state) {
    if (['downloading', 'metaDL', 'forcedDL', 'stalledDL'].contains(state)) {
      return (
        color: AppColors.accent,
        icon: CupertinoIcons.arrow_down_circle_fill,
      );
    }
    if (['uploading', 'forcedUP', 'stalledUP'].contains(state)) {
      return (
        color: AppColors.success,
        icon: CupertinoIcons.arrow_up_circle_fill,
      );
    }
    if (state.startsWith('paused') || state.startsWith('stopped')) {
      return (
        color: AppColors.of(AppColors.secondaryLabel),
        icon: CupertinoIcons.pause_circle_fill,
      );
    }
    if (state.startsWith('checking')) {
      return (
        color: AppColors.warning,
        icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
      );
    }
    if (state == 'error' || state == 'missingFiles') {
      return (
        color: AppColors.danger,
        icon: CupertinoIcons.exclamationmark_circle_fill,
      );
    }
    return (
      color: AppColors.of(AppColors.tertiaryLabel),
      icon: CupertinoIcons.circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text('搜索', style: AppTypography.largeTitle()),
        ),
        const SizedBox(height: 14),
        // 模式切换：iOS 原生滑动分段控件
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoSearchTextField(
            controller: _queryCtrl,
            placeholder: _mode == 0 ? '搜索我的任务' : '输入关键字后回车搜索',
            style: AppTypography.body(),
            placeholderStyle: AppTypography.body(
                color: AppColors.of(AppColors.tertiaryLabel)),
            backgroundColor: AppColors.of(AppColors.card),
            onChanged: (_) {
              if (_mode == 0) setState(() {});
            },
            onSubmitted: (_) {
              if (_mode == 1) _runOnlineSearch();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _mode == 0 ? _buildLocal() : _buildOnline()),
      ],
    );
  }

  Widget _segLabel(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: AppTypography.body().copyWith(fontSize: 14)),
      );

  // —— 本地结果（Cupertino sliver refresh + inset grouped）——
  Widget _buildLocal() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadLocal),
        if (!_localLoaded)
          SliverToBoxAdapter(child: _buildLocalSkeleton())
        else if (_localResults.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyHint(
              _queryCtrl.text.trim().isEmpty
                  ? '暂无任务'
                  : '没有匹配「${_queryCtrl.text.trim()}」的任务',
            ),
          )
        else
          SliverToBoxAdapter(child: _buildLocalList()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildLocalList() {
    final list = _localResults;
    return CupertinoListSection.insetGrouped(
      children: list.map((t) {
        final tt = t as Map;
        final info = _stateInfo((tt['state'] ?? '').toString());
        final progress = ((tt['progress'] ?? 0.0) as num).toDouble();
        final dotStyle = AppTypography.caption(
            color: AppColors.of(AppColors.tertiaryLabel));
        return CupertinoListTile.notched(
          leading: Icon(info.icon, color: info.color, size: 22),
          title: Text(
            (tt['name'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body().copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          subtitle: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: _fmtSize((tt['total_size'] ?? 0) as num),
                  style: AppTypography.caption()),
              TextSpan(text: '  ·  ', style: dotStyle),
              TextSpan(
                  text: '${(progress * 100).toStringAsFixed(1)}%',
                  style: AppTypography.caption()),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            await Get.to(() => TorrentDetailScreen(
                torrent: Map<String, dynamic>.from(tt)));
            _loadLocal();
          },
        );
      }).toList(),
    );
  }

  // —— 联网结果 ——
  Widget _buildOnline() {
    if (_onlineNotice != null) {
      return _emptyHint(
        _onlineNotice!,
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
    if (!_onlineSearched) {
      return _emptyHint(
        '输入关键字后回车，跨站点搜索种子',
        icon: CupertinoIcons.search,
      );
    }
    if (_searching && _results.isEmpty) {
      return _buildOnlineSkeleton();
    }
    if (!_searching && _results.isEmpty) {
      return _emptyHint('没有找到结果，换个关键字试试');
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (_searching)
          SliverToBoxAdapter(child: _buildSearchingBanner()),
        SliverToBoxAdapter(child: _buildOnlineList()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSearchingBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 8),
          const SizedBox(width: 8),
          Text(
            '搜索中…已找到 ${_results.length} 条',
            style: AppTypography.caption(),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineList() {
    return CupertinoListSection.insetGrouped(
      children:
          _results.map((r) => _buildOnlineTile(r as Map)).toList(),
    );
  }

  Widget _buildOnlineTile(Map r) {
    final name = (r['fileName'] ?? '').toString();
    final size = r['fileSize'] as num?;
    final seeders = ((r['nbSeeders'] ?? -1) as num).toInt();
    final leechers = ((r['nbLeechers'] ?? -1) as num).toInt();
    final site = Uri.tryParse((r['siteUrl'] ?? '').toString())?.host ?? '';

    final dotStyle = AppTypography.caption(
        color: AppColors.of(AppColors.tertiaryLabel));
    final spans = <InlineSpan>[];
    void addSep() {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '  ·  ', style: dotStyle));
      }
    }

    if (size != null) {
      addSep();
      spans.add(TextSpan(
        text: _fmtSize(size),
        style: AppTypography.caption(),
      ));
    }
    addSep();
    spans.add(const WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(CupertinoIcons.arrow_up,
          size: 10, color: AppColors.success),
    ));
    spans.add(TextSpan(
      text: ' ${seeders < 0 ? '?' : seeders}',
      style: AppTypography.caption(color: AppColors.success),
    ));
    addSep();
    spans.add(const WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(CupertinoIcons.arrow_down,
          size: 10, color: AppColors.warning),
    ));
    spans.add(TextSpan(
      text: ' ${leechers < 0 ? '?' : leechers}',
      style: AppTypography.caption(color: AppColors.warning),
    ));

    final subtitleWidgets = <Widget>[
      Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ];
    if (site.isNotEmpty) {
      subtitleWidgets.addAll([
        const SizedBox(height: 2),
        Text(
          site,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption(
              color: AppColors.of(AppColors.tertiaryLabel)),
        ),
      ]);
    }

    return CupertinoListTile(
      title: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body().copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: subtitleWidgets,
      ),
      trailing: const Icon(
        CupertinoIcons.add_circled,
        size: 22,
        color: AppColors.accent,
      ),
      onTap: () => _addResult(r),
    );
  }

  // —— 加载态：骨架屏 ——
  Widget _buildLocalSkeleton() {
    return CupertinoListSection.insetGrouped(
      children: List.generate(
        6,
        (_) => const CupertinoListTile(
          leading: SkeletonBar(
            width: 22,
            height: 22,
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
          title: SkeletonBar(width: 200, height: 14),
          subtitle: SkeletonBar(width: 100, height: 12),
          trailing: CupertinoListTileChevron(),
        ),
      ),
    );
  }

  Widget _buildOnlineSkeleton() {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 8),
              const SizedBox(width: 8),
              Text('搜索中…', style: AppTypography.caption()),
            ],
          ),
        ),
        CupertinoListSection.insetGrouped(
          children: List.generate(
            5,
            (_) => const CupertinoListTile(
              title: SkeletonBar(width: 220, height: 14),
              subtitle: SkeletonBar(width: 140, height: 12),
              trailing: SkeletonBar(
                width: 22,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(String text, {IconData icon = CupertinoIcons.tray}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.of(AppColors.placeholder)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.subtitle(
                  color: AppColors.of(AppColors.tertiaryLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
