import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../services/torrent_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';
import 'torrent_detail_screen.dart';

enum OnlineSearchState { idle, searching, success, empty, error }

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    if (_timer?.isActive ?? false) _timer!.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 600);
  int _mode = 0;

  List<dynamic> _allTorrents = [];
  bool _localLoaded = false;

  OnlineSearchState _onlineState = OnlineSearchState.idle;
  List<Map<String, dynamic>> _results = [];
  int _lastPage = 1;
  bool _isLoadingMore = false;

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

  Future<void> _runOnlineSearch(String pattern) async {
    if (pattern.trim().isEmpty) {
      setState(() => _onlineState = OnlineSearchState.idle);
      return;
    }

    setState(() {
      _onlineState = OnlineSearchState.searching;
      _results = [];
      _lastPage = 1;
    });

    try {
      final items = await TorrentSearchService.instance.search(pattern.trim(), pages: 10, startPage: 1);
      if (!mounted) return;

      if (items.isEmpty) {
        setState(() => _onlineState = OnlineSearchState.empty);
        return;
      }

      setState(() {
        _results = items.map(_toResultMap).toList();
        _lastPage = 10;
        _onlineState = OnlineSearchState.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _onlineState = OnlineSearchState.error);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final start = _lastPage + 1;
    try {
      final items = await TorrentSearchService.instance.search(
        _queryCtrl.text.trim(),
        pages: 15,
        startPage: start,
      );
      if (!mounted) return;

      final seen = _results.map((r) => r['fileUrl'] as String).toSet();
      for (final item in items) {
        if (!seen.contains(item.magnet)) {
          _results.add(_toResultMap(item));
        }
      }
      setState(() {
        _isLoadingMore = false;
        _lastPage = start + 15 - 1;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Map<String, dynamic> _toResultMap(ScrapedTorrent item) {
    return {
      'fileName': item.title,
      'fileUrl': item.magnet,
      'code': item.code,
      'thumbnail': item.thumbnail ?? '',
      'sizeStr': item.size,
      'date': item.date,
    };
  }

  Future<void> _addResult(Map result) async {
    final url = (result['fileUrl'] ?? '').toString();
    if (url.isEmpty) {
      _toast('该结果没有可用的下载链接', ok: false);
      return;
    }
    HapticFeedback.mediumImpact();
    final err = await QBitApi().addMagnet(url);
    if (!mounted) return;
    _toast(err ?? '已添加到下载队列', ok: err == null);
  }

  void _toast(String msg, {required bool ok}) {
    Toast.show(context, msg, type: ok ? ToastType.success : ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text('发现', style: AppTypography.largeTitle()),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _mode,
            children: {
              0: _segLabel('本地任务'),
              1: _segLabel('141PPV 搜种'),
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
            placeholder: _mode == 0 ? '搜索我的任务' : '输入番号或名称，自动搜索',
            style: AppTypography.body(),
            placeholderStyle: AppTypography.body(color: AppColors.of(AppColors.tertiaryLabel)),
            backgroundColor: AppColors.of(AppColors.card),
            onChanged: (text) {
              if (_mode == 0) {
                setState(() {});
              } else {
                _debouncer.run(() => _runOnlineSearch(text));
              }
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

  Widget _buildOnline() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildOnlineContentSliver(),
        if (_onlineState == OnlineSearchState.success)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: _isLoadingMore
                    ? const CupertinoActivityIndicator()
                    : CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        color: AppColors.of(AppColors.card),
                        borderRadius: BorderRadius.circular(20),
                        onPressed: _loadMore,
                        child: const Text('挖掘更早资源', style: TextStyle(fontSize: 13, color: AppColors.accent)),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOnlineContentSliver() {
    switch (_onlineState) {
      case OnlineSearchState.idle:
        return SliverFillRemaining(child: _emptyHint('输入关键字自动匹配 141PPV', icon: CupertinoIcons.search));
      case OnlineSearchState.searching:
        return _buildGridSkeleton();
      case OnlineSearchState.empty:
        return SliverFillRemaining(child: _emptyHint('未找到相关番号或结果'));
      case OnlineSearchState.error:
        return SliverFillRemaining(child: _emptyHint('网络请求失败，请检查连通性', icon: CupertinoIcons.wifi_exclamationmark));
      case OnlineSearchState.success:
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGridCard(_results[index]),
              childCount: _results.length,
            ),
          ),
        );
    }
  }

  Widget _buildGridCard(Map r) {
    final code = (r['code'] ?? '').toString();
    final sizeStr = (r['sizeStr'] ?? '').toString();
    final thumb = (r['thumbnail'] ?? '').toString();

    return CupertinoContextMenu(
      actions: [
        CupertinoContextMenuAction(
          onPressed: () {
            Navigator.pop(context);
            _addResult(r);
          },
          trailingIcon: CupertinoIcons.arrow_down_circle,
          child: const Text('添加到队列'),
        ),
        CupertinoContextMenuAction(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: r['fileUrl']));
            Navigator.pop(context);
            _toast('磁力链接已复制', ok: true);
          },
          trailingIcon: CupertinoIcons.doc_on_doc,
          child: const Text('复制磁力'),
        ),
      ],
      child: GestureDetector(
        onTap: () => _showFullImage(thumb),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.of(AppColors.card),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.isNotEmpty)
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackCover(),
                )
              else
                _fallbackCover(),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.srcOver),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            code.isNotEmpty ? code : '未知',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sizeStr,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    if (url.isEmpty) return;
    Navigator.push(context, CupertinoPageRoute(
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          child: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.white54, size: 64),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const CupertinoActivityIndicator();
                },
              ),
            ),
          ),
        ),
      ),
      fullscreenDialog: true,
    ));
  }

  Widget _fallbackCover() => Container(
        color: AppColors.of(AppColors.separator),
        child: const Center(child: Icon(CupertinoIcons.film, color: AppColors.placeholder)),
      );

  Widget _buildGridSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(
            decoration: BoxDecoration(
              color: AppColors.of(AppColors.card),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SkeletonBar(width: double.infinity, height: double.infinity),
          ),
          childCount: 6,
        ),
      ),
    );
  }

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

  Widget _emptyHint(String text, {IconData icon = CupertinoIcons.tray}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.of(AppColors.placeholder)),
          const SizedBox(height: 16),
          Text(text, style: AppTypography.subtitle(color: AppColors.of(AppColors.tertiaryLabel))),
        ],
      ),
    );
  }
}
