import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/qbit_api.dart';
import '../services/torrent_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/media_viewer.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';

enum _OnlineState { idle, loading, results, empty, error }

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

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _debouncer = Debouncer(milliseconds: 400);
  final _scrollCtrl = ScrollController();

  _OnlineState _state = _OnlineState.idle;
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _filteredResults = [];
  int _lastPage = 1;
  bool _isLoadingMore = false;

  String _activeTab = '';
  final Set<String> _bookmarks = {};

  static const _tabs = [''];
  static final _cardTween = Tween(begin: 0.0, end: 1.0);
  static const _cardDuration = Duration(milliseconds: 300);
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _scrollCtrl.addListener(_onScroll);
    _loadBookmarks();
    _loadLatest();
  }

  @override
  void dispose() {
    _queryCtrl.dispose(); _focusNode.dispose(); _shimmerCtrl.dispose();
    _scrollCtrl.dispose(); super.dispose();
  }

  // ── Bookmark ──
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('ppv_bookmarks') ?? [];
    if (mounted) setState(() => _bookmarks.addAll(stored));
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ppv_bookmarks', _bookmarks.toList());
  }

  void _toggleBookmark(String magnet) {
    setState(() {
      if (_bookmarks.contains(magnet)) { _bookmarks.remove(magnet); _toast('已取消收藏', ok: true); }
      else { _bookmarks.add(magnet); _toast('已收藏', ok: true); }
    });
    _saveBookmarks();
  }

  // ── Data ──
  void _onScroll() {
    if (_state != _OnlineState.results || _isLoadingMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadLatest() async {
    setState(() => _state = _OnlineState.loading);
    try {
      final items = await TorrentSearchService.instance.search('', pages: 5, startPage: 1);
      if (!mounted) return;
      if (items.isEmpty) { setState(() => _state = _OnlineState.empty); return; }
      setState(() {
        _state = _OnlineState.results;
        _allResults = items.map(_toResultMap).toList();
        _lastPage = 5;
        _applyFilters();
      });
    } catch (_) { if (mounted) setState(() => _state = _OnlineState.error); }
  }

  Future<void> _runSearch(String pattern) async {
    if (pattern.trim().isEmpty) { _loadLatest(); return; }
    setState(() { _state = _OnlineState.loading; _allResults = []; _lastPage = 1; });
    try {
      final items = await TorrentSearchService.instance.search(pattern.trim(), pages: 10, startPage: 1);
      if (!mounted) return;
      if (items.isEmpty) { setState(() => _state = _OnlineState.empty); return; }
      setState(() {
        _state = _OnlineState.results;
        _allResults = items.map(_toResultMap).toList();
        _lastPage = 10;
        _applyFilters();
      });
    } catch (_) { if (mounted) setState(() => _state = _OnlineState.error); }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final query = _queryCtrl.text.trim();
    final start = _lastPage + 1;
    try {
      final items = await TorrentSearchService.instance.search(query.isEmpty ? '' : query, pages: 15, startPage: start);
      if (!mounted) return;
      final seen = _allResults.map((r) => r['fileUrl'] as String).toSet();
      for (final item in items) {
        if (!seen.contains(item.magnet)) _allResults.add(_toResultMap(item));
      }
      setState(() { _isLoadingMore = false; _lastPage = start + 15 - 1; _applyFilters(); });
    } catch (_) { if (mounted) setState(() => _isLoadingMore = false); }
  }

  void _applyFilters() {
    var list = _allResults.toList();
    if (_activeTab.isNotEmpty) {
      list = list.where((r) => (r['code'] ?? '').toString().startsWith(_activeTab)).toList();
    }
    _filteredResults = list.toList();
  }

  Map<String, dynamic> _toResultMap(ScrapedTorrent item) => {
    'fileName': item.title, 'fileUrl': item.magnet, 'code': item.code,
    'thumbnail': item.thumbnail ?? '', 'sizeStr': item.size, 'date': item.date,
    'pageUrl': item.pageUrl, 'torrentUrl': item.torrentUrl,
    'description': item.description,
  };

  void _addMagnet(String url) async {
    if (url.isEmpty) { _toast('没有可用的下载链接', ok: false); return; }
    HapticFeedback.mediumImpact();
    final err = await QBitApi().addMagnet(url);
    if (!mounted) return;
    _toast(err ?? '已添加到下载队列', ok: err == null);
  }

  void _downloadTorrent(String url) async {
    try {
      final dio = Dio();
      final resp = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final path = '${(await getTemporaryDirectory()).path}/${url.split('/').last}';
      await File(path).writeAsBytes(resp.data!);
      await Share.shareXFiles([XFile(path)], text: '.torrent 文件');
    } catch (_) { _toast('下载失败', ok: false); }
  }

  void _toast(String msg, {required bool ok}) =>
      Toast.show(context, msg, type: ok ? ToastType.success : ToastType.error);

  // ── 打开全屏媒体浏览器 ──
  void _openFullScreen(int index) {
    final images = _filteredResults.map((r) => (r['thumbnail'] ?? '').toString()).toList();
    Navigator.push(context, CupertinoPageRoute(
      builder: (_) => MediaViewer(
        imageUrls: images,
        initialIndex: index,
        heroTagBuilder: (i) => 'ppv-${_filteredResults[i]['code']}',
        overlayBuilder: (i) => _FullScreenOverlay(
          item: _filteredResults[i],
          onAdd: _addMagnet,
          onBookmark: _toggleBookmark,
          isBookmarked: _bookmarks.contains(_filteredResults[i]['fileUrl']),
        ),
      ),
    ));
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(
              _bookmarks.isEmpty ? CupertinoIcons.heart : CupertinoIcons.heart_fill,
              size: 22, color: _bookmarks.isEmpty ? AppColors.of(AppColors.tertiaryLabel) : AppColors.danger,
            ),
            onPressed: () => _showBookmarks(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _OnlineState.idle: return _buildIdle();
      case _OnlineState.loading: return _buildLoading();
      case _OnlineState.results: return _buildResults();
      case _OnlineState.empty: return _emptyHint('没有找到相关结果', icon: CupertinoIcons.search);
      case _OnlineState.error:
        return _emptyHint('网络请求失败', icon: CupertinoIcons.wifi_exclamationmark,
          action: CupertinoButton(
            onPressed: _queryCtrl.text.trim().isEmpty ? _loadLatest : () => _runSearch(_queryCtrl.text.trim()),
            child: const Text('重试'),
          ),
        );
    }
  }

  Widget _buildIdle() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.flame_fill, size: 24, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('浏览热门', style: AppTypography.cardTitle()),
            ],
          ),
          const SizedBox(height: 6),
          Text('选择标签快速浏览，或直接搜索', style: AppTypography.subtitle(color: AppColors.of(AppColors.tertiaryLabel))),
          const SizedBox(height: 24),
          CupertinoSearchTextField(
            controller: _queryCtrl,
            focusNode: _focusNode,
            placeholder: '搜索番号或名称 …',
            style: AppTypography.body(),
            placeholderStyle: AppTypography.body(color: AppColors.of(AppColors.tertiaryLabel)),
            backgroundColor: AppColors.of(AppColors.card),
            onChanged: (text) => _debouncer.run(() => _runSearch(text)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _tabs.where((c) => c.isNotEmpty).map((s) => GestureDetector(
              onTap: () { _queryCtrl.text = s; _runSearch(s); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.of(AppColors.card),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.of(AppColors.separator)),
                ),
                child: Text(s, style: AppTypography.body().copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const CupertinoActivityIndicator(radius: 7),
                const SizedBox(width: 8),
                Text('正在获取最新资源…', style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel))),
              ],
            ),
          ),
        ),
        _buildGridSkeleton(),
      ],
    );
  }

  Widget _buildResults() {
    final list = _filteredResults;
    if (list.isEmpty) {
      return _emptyHint('筛选中没有匹配结果', icon: CupertinoIcons.slash_circle);
    }
    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── 粘性 Tab 栏（搜索框 + 分类标签） ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabHeaderDelegate(
            minHeight: 90,
            maxHeight: 90,
            child: _buildTabBar(),
          ),
        ),
        // ── 结果网格 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCard(list[index], index),
              childCount: list.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: _isLoadingMore
                  ? const CupertinoActivityIndicator()
                  : Text(list.length >= 30 ? '上滑加载更多' : '',
                      style: const TextStyle(color: AppColors.tertiaryLabel, fontSize: 13)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      color: AppColors.of(AppColors.groupedBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoSearchTextField(
            controller: _queryCtrl,
            focusNode: _focusNode,
            placeholder: '搜索番号或名称 …',
            style: AppTypography.body().copyWith(fontSize: 15),
            placeholderStyle: AppTypography.body(color: AppColors.of(AppColors.tertiaryLabel)).copyWith(fontSize: 15),
            backgroundColor: AppColors.of(AppColors.card),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onChanged: (text) => _debouncer.run(() => _runSearch(text)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tab in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() { _activeTab = _activeTab == tab ? '' : tab; _applyFilters(); });
                        // 滚动到网格顶部
                        _scrollCtrl.animateTo(90, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _activeTab == tab ? AppColors.accent : AppColors.of(AppColors.card),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _activeTab == tab ? AppColors.accent : AppColors.of(AppColors.separator),
                          ),
                        ),
                        child: Text(
                          tab.isEmpty ? '全部' : tab,
                          style: AppTypography.caption().copyWith(
                            fontSize: 12,
                            color: _activeTab == tab ? Colors.white : AppColors.of(AppColors.secondaryLabel),
                            fontWeight: _activeTab == tab ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 0, 0),
            child: Row(
              children: [
                Icon(CupertinoIcons.doc_text, size: 12, color: AppColors.of(AppColors.tertiaryLabel)),
                const SizedBox(width: 4),
                Text(
                  _queryCtrl.text.trim().isEmpty
                      ? '${_filteredResults.length} 条结果'
                      : '「${_queryCtrl.text.trim()}」  ·  ${_filteredResults.length} 条',
                  style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 卡片 ──
  Widget _buildCard(Map r, int index) {
    final code = (r['code'] ?? '').toString();
    final sizeStr = (r['sizeStr'] ?? '').toString();
    final thumb = (r['thumbnail'] ?? '').toString();
    final date = (r['date'] ?? '').toString();
    final magnet = (r['fileUrl'] ?? '').toString();
    final isBookmarked = _bookmarks.contains(magnet);
    final heroTag = 'ppv-${r['code']}';

    return CupertinoContextMenu(
      actions: [
        CupertinoContextMenuAction(
          onPressed: () { Navigator.pop(context); _addMagnet(magnet); },
          trailingIcon: CupertinoIcons.arrow_down_circle, isDefaultAction: true,
          child: const Text('添加到队列'),
        ),
        CupertinoContextMenuAction(
          onPressed: () { Navigator.pop(context); _toggleBookmark(magnet); },
          trailingIcon: isBookmarked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          child: Text(isBookmarked ? '取消收藏' : '收藏'),
        ),
        CupertinoContextMenuAction(
          onPressed: () { Navigator.pop(context); _showDetailSheet(r); },
          trailingIcon: CupertinoIcons.info_circle, child: const Text('查看详情'),
        ),
        CupertinoContextMenuAction(
          onPressed: () { Clipboard.setData(ClipboardData(text: magnet)); Navigator.pop(context); _toast('磁力已复制', ok: true); },
          trailingIcon: CupertinoIcons.doc_on_doc, child: const Text('复制磁力'),
        ),
      ],
      child: GestureDetector(
        onTap: () => _openFullScreen(index),
        child: TweenAnimationBuilder<double>(
          tween: _cardTween,
          duration: _cardDuration,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(offset: Offset(0, 15 * (1 - value)), child: child),
          ),
          child: Container(
            decoration: BoxDecoration(color: AppColors.of(AppColors.card), borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb.isNotEmpty)
                  Hero(
                    tag: heroTag,
                    child: Image.network(thumb, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackCover(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _shimmerPlaceholder();
                      },
                    ),
                  )
                else
                  _fallbackCover(),
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 100,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(code, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(sizeStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                if (isBookmarked)
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.heart_fill, size: 12, color: Colors.white),
                    ),
                  ),
                if (date.isNotEmpty)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(date.length >= 10 ? date.substring(0, 10) : date,
                        style: const TextStyle(color: Colors.white70, fontSize: 9)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 详情 Sheet ──
  void _showDetailSheet(Map r) {
    final code = (r['code'] ?? '').toString();
    final sizeStr = (r['sizeStr'] ?? '').toString();
    final thumb = (r['thumbnail'] ?? '').toString();
    final date = (r['date'] ?? '').toString();
    final magnet = (r['fileUrl'] ?? '').toString();
    final pageUrl = (r['pageUrl'] ?? '').toString();
    final torrentUrl = (r['torrentUrl'] ?? '').toString();
    final isBookmarked = _bookmarks.contains(magnet);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final fileName = (r['fileName'] ?? '').toString();
        final rawDesc = (r['description'] ?? '') as String?;
        final hasDesc = rawDesc != null && rawDesc.isNotEmpty;
        bool translationTriggered = false;
        String? localDesc;
        final debugCode = r['code'] as String?;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (hasDesc && !translationTriggered) {
              translationTriggered = true;
              TorrentSearchService.instance.translateDescription(rawDesc).then((desc) {
                setSheetState(() {
                  localDesc = desc;
                });
              });
            }

            return CupertinoPageScaffold(
              backgroundColor: AppColors.of(AppColors.groupedBg),
              navigationBar: CupertinoNavigationBar(
                middle: Text(code, style: const TextStyle(fontSize: 16)),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(isBookmarked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    size: 22, color: isBookmarked ? AppColors.danger : AppColors.of(AppColors.tertiaryLabel)),
                  onPressed: () { _toggleBookmark(magnet); Navigator.pop(context); },
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (thumb.isNotEmpty)
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                          color: Colors.black,
                          child: Image.network(thumb, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.white54, size: 48),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CupertinoActivityIndicator());
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(code, style: AppTypography.cardTitle()),
                            if (fileName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(fileName, style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel))),
                            ],
                            const SizedBox(height: 6),
                            Row(children: [
                              _metaChip(CupertinoIcons.doc, sizeStr),
                              if (date.isNotEmpty) ...[const SizedBox(width: 8), _metaChip(CupertinoIcons.calendar, date)],
                            ]),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.of(AppColors.card),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localDesc ?? rawDesc ?? 'rawDesc=null hasDesc=$hasDesc code=$debugCode',
                                    style: AppTypography.body().copyWith(fontSize: 13, height: 1.5),
                                  ),
                                  if (hasDesc && localDesc == null) ...[
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      const CupertinoActivityIndicator(radius: 6),
                                      const SizedBox(width: 6),
                                      Text('翻译中…', style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel))),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _actionBtn('添加到下载队列', CupertinoIcons.arrow_down_circle, AppColors.accent,
                              () { Navigator.pop(context); _addMagnet(magnet); }),
                            const SizedBox(height: 10),
                            _actionBtn('复制磁力链接', CupertinoIcons.doc_on_doc, null,
                              () { Clipboard.setData(ClipboardData(text: magnet)); _toast('磁力已复制', ok: true); }),
                            const SizedBox(height: 10),
                            _actionBtn('下载 .torrent 文件', CupertinoIcons.down_arrow, null,
                              () { Navigator.pop(context); _downloadTorrent(torrentUrl); }),
                            if (pageUrl.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _actionBtn('在浏览器中打开', CupertinoIcons.globe, null, () async {
                                final uri = Uri.tryParse(pageUrl);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _metaChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.of(AppColors.card), borderRadius: BorderRadius.circular(6)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.of(AppColors.tertiaryLabel)),
        const SizedBox(width: 4),
        Text(text, style: AppTypography.caption(color: AppColors.of(AppColors.secondaryLabel))),
      ],
    ),
  );

  Widget _actionBtn(String label, IconData icon, Color? color, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: CupertinoButton(
      onPressed: onTap,
      color: color ?? AppColors.of(AppColors.card),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.accent),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color ?? AppColors.accent, fontSize: 15)),
        ],
      ),
    ),
  );

  void _showBookmarks() {
    if (_bookmarks.isEmpty) { _toast('还没有收藏的内容', ok: false); return; }
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPageScaffold(
        backgroundColor: AppColors.of(AppColors.groupedBg),
        navigationBar: CupertinoNavigationBar(
          middle: const Text('收藏夹'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Text('清空', style: TextStyle(color: AppColors.danger)),
            onPressed: () { Navigator.pop(ctx); setState(() => _bookmarks.clear()); _saveBookmarks(); _toast('已清空收藏', ok: true); },
          ),
        ),
        child: SafeArea(
          child: _bookmarks.isEmpty
              ? _emptyHint('暂无收藏')
              : ListView(
                  children: _allResults.where((r) => _bookmarks.contains(r['fileUrl'])).map((r) {
                    return CupertinoListTile(
                      leading: const Icon(CupertinoIcons.heart_fill, size: 18, color: AppColors.danger),
                      title: Text((r['code'] ?? '').toString(), style: AppTypography.body()),
                      subtitle: Text((r['sizeStr'] ?? '').toString(), style: AppTypography.caption()),
                      trailing: const Icon(CupertinoIcons.arrow_down_circle, size: 20, color: AppColors.accent),
                      onTap: () { Navigator.pop(ctx); _addMagnet(r['fileUrl']); },
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }

  Widget _fallbackCover() => Container(
    color: AppColors.of(AppColors.separator),
    child: const Center(child: Icon(CupertinoIcons.film, color: AppColors.placeholder, size: 28)),
  );

  Widget _shimmerPlaceholder() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final t = (_shimmerCtrl.value * 2).clamp(0.0, 1.0);
        return Container(
          color: Color.lerp(AppColors.skeletonBase, AppColors.skeletonHighlight, t > 1 ? 2 - t : t),
        );
      },
    );
  }

  Widget _buildGridSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(
            decoration: BoxDecoration(color: AppColors.of(AppColors.card), borderRadius: BorderRadius.circular(10)),
            child: const SkeletonBar(width: double.infinity, height: double.infinity),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _emptyHint(String text, {IconData icon = CupertinoIcons.tray, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.of(AppColors.placeholder)),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: AppTypography.subtitle(color: AppColors.of(AppColors.tertiaryLabel))),
            if (action != null) ...[const SizedBox(height: 20), action],
          ],
        ),
      ),
    );
  }
}

// ── 粘性 Tab 头委托 ──
class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabHeaderDelegate({required this.child, required double minHeight, required double maxHeight})
      : _minHeight = minHeight, _maxHeight = maxHeight;

  final double _minHeight;
  final double _maxHeight;

  @override
  double get minExtent => _minHeight;
  @override
  double get maxExtent => _maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate old) => child != old.child;
}

// ── 全屏模式下 Overlay ──
class _FullScreenOverlay extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(String url) onAdd;
  final void Function(String magnet) onBookmark;
  final bool isBookmarked;

  const _FullScreenOverlay({
    required this.item, required this.onAdd, required this.onBookmark, required this.isBookmarked,
  });

  @override
  Widget build(BuildContext context) {
    final code = (item['code'] ?? '').toString();
    final sizeStr = (item['sizeStr'] ?? '').toString();
    final date = (item['date'] ?? '').toString();
    final magnet = (item['fileUrl'] ?? '').toString();

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(code, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('$sizeStr${date.isNotEmpty ? '  ·  $date' : ''}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
                onPressed: () => onAdd(magnet),
                child: const Icon(CupertinoIcons.arrow_down_circle, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                color: isBookmarked ? AppColors.danger : Colors.white24,
                borderRadius: BorderRadius.circular(20),
                onPressed: () => onBookmark(magnet),
                child: Icon(
                  isBookmarked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 20, color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
