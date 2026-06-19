import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../services/torrent_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';
import 'torrent_detail_screen.dart';

/// 搜索页：本地任务搜索 + 141ppv.com 联网爬虫（顶部分段切换）。
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
  List<Map<String, dynamic>> _results = [];
  String? _onlineNotice;
  bool _onlineSearched = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void dispose() {
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

  // —— 联网搜索（141ppv.com 爬虫）——
  Future<void> _runOnlineSearch() async {
    final pattern = _queryCtrl.text.trim();
    if (pattern.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _onlineNotice = null;
      _onlineSearched = true;
      _searching = true;
      _results = [];
    });

    final items = await TorrentSearchService.instance.search(pattern, pages: 3);
    if (!mounted) return;

    if (items.isEmpty) {
      setState(() {
        _searching = false;
        _onlineNotice = '没有找到结果，换个关键字试试';
      });
      return;
    }

    setState(() {
      _searching = false;
      _results = items.map(_toResultMap).toList();
    });
  }

  Future<void> _loadMore() async {
    if (_searching) return;
    setState(() => _searching = true);

    final currentCount = _results.length;
    final items = await TorrentSearchService.instance.search(
      _queryCtrl.text.trim(),
      pages: (currentCount ~/ 20).clamp(2, 10), // 每次多翻几页
    );
    if (!mounted) return;

    final seen = _results.map((r) => r['fileUrl'] as String).toSet();
    for (final item in items) {
      if (!seen.contains(item.magnet)) {
        _results.add(_toResultMap(item));
      }
    }

    setState(() => _searching = false);
  }

  Map<String, dynamic> _toResultMap(ScrapedTorrent item) {
    return {
      'fileName': item.title.isNotEmpty && item.title != item.code
          ? '[${item.code}] ${item.title}'
          : item.code,
      'fileUrl': item.magnet,
      'fileSize': _parseSizeBytes(item.size),
      'nbSeeders': -1,
      'nbLeechers': -1,
      'siteUrl': item.pageUrl,
      'siteName': '141PPV',
      'descrLink': item.pageUrl,
    };
  }

  /// "5.3 GB" → bytes
  int? _parseSizeBytes(String size) {
    if (size.isEmpty) return null;
    final m = RegExp(r'([\d.]+)\s*(TB|GB|MB|KB|B)',
            caseSensitive: false)
        .firstMatch(size);
    if (m == null) return null;
    final num = double.tryParse(m.group(1)!) ?? 0;
    final unit = m.group(2)!.toUpperCase();
    switch (unit) {
      case 'TB':
        return (num * 1099511627776).round();
      case 'GB':
        return (num * 1073741824).round();
      case 'MB':
        return (num * 1048576).round();
      case 'KB':
        return (num * 1024).round();
      default:
        return num.round();
    }
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
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1048576).toStringAsFixed(2)} MB';
    }
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  // 状态 → (color, icon)
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
    if (state == 'missingFiles') {
      return (
        color: AppColors.danger,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
      );
    }
    if (state == 'error') {
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
            placeholder:
                _mode == 0 ? '搜索我的任务' : '输入关键字后回车搜索',
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

  // —— 本地结果 ——
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
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      children: list.map((t) {
        final tt = t as Map;
        final info = _stateInfo((tt['state'] ?? '').toString());
        final progress = ((tt['progress'] ?? 0.0) as num).toDouble();
        final dotStyle =
            AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel));
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
            await Get.to(
                () => TorrentDetailScreen(torrent: Map<String, dynamic>.from(tt)));
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
        '输入关键字后回车，搜索 141PPV 种子',
        icon: CupertinoIcons.search,
      );
    }
    if (_searching && _results.isEmpty) {
      return _buildOnlineSkeleton();
    }
    if (!_searching && _results.isEmpty) {
      return _emptyHint('没有找到结果，换个关键字试试');
    }
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        if (_searching) _buildSearchingBanner(),
        _buildOnlineList(),
        if (!_searching)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            child: Center(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                onPressed: _loadMore,
                child: const Text('加载更多',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accent)),
              ),
            ),
          ),
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
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
      children: _results.map((r) => _buildOnlineTile(r)).toList(),
    );
  }

  Widget _buildOnlineTile(Map r) {
    final name = (r['fileName'] ?? '').toString();
    final size = r['fileSize'] as num?;
    final seeders = ((r['nbSeeders'] ?? -1) as num).toInt();
    final leechers = ((r['nbLeechers'] ?? -1) as num).toInt();

    final dotStyle =
        AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel));
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
    if (seeders >= 0) {
      addSep();
      spans.add(const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(CupertinoIcons.arrow_up, size: 10, color: AppColors.success),
      ));
      spans.add(TextSpan(
        text: ' $seeders',
        style: AppTypography.caption(color: AppColors.success),
      ));
    }
    if (leechers >= 0) {
      addSep();
      spans.add(const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child:
            Icon(CupertinoIcons.arrow_down, size: 10, color: AppColors.warning),
      ));
      spans.add(TextSpan(
        text: ' $leechers',
        style: AppTypography.caption(color: AppColors.warning),
      ));
    }

    final subtitleWidgets = <Widget>[
      Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2),
      Text(
        '141PPV  ·  ${Uri.tryParse((r['siteUrl'] ?? '').toString())?.pathSegments.lastOrNull ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption(
            color: AppColors.of(AppColors.tertiaryLabel)),
      ),
    ];

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
      backgroundColor: AppColors.of(AppColors.groupedBg),
      decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
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
          backgroundColor: AppColors.of(AppColors.groupedBg),
          decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
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
