import 'package:dio/dio.dart';
import 'torrent_translate_service.dart';
import 'package:flutter/foundation.dart';

/// 141ppv.com 爬虫搜索结果项。
class ScrapedTorrent {
  /// 种子代码，如 "PPV4921425"。
  final String code;

  /// 标题（日文原文）。
  final String title;

  /// 文件大小字符串，如 "5.3 GB"。
  final String size;

  /// 日期字符串，如 "Jun. 17, 2026"。
  final String date;

  /// 缩略图 URL。
  final String? thumbnail;

  /// 磁力链接。
  final String magnet;

  /// .torrent 文件直链。
  final String torrentUrl;

  /// 详情页 URL。
  final String pageUrl;

  String? description;

  ScrapedTorrent({
    required this.code,
    required this.title,
    required this.size,
    required this.date,
    this.thumbnail,
    required this.magnet,
    required this.torrentUrl,
    required this.pageUrl,
  });
}

/// 141ppv.com 爬虫搜索服务。
///
/// 网站无原生搜索框，按「最新」列表页（/new?page=N）抓取，
/// 客户端按关键字过滤标题/代码，分页加载更多。
class TorrentSearchService {
  TorrentSearchService._();
  static final TorrentSearchService instance = TorrentSearchService._();

  static const String _base = 'https://www.141ppv.com';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml',
    },
  ));

  /// 搜索种子：从 /new 列表并发抓取 [pages] 页，按 [query] 过滤标题/代码。
  ///
  /// [startPage] 指定起始页（1 为最新），用于深层翻页。
  /// 返回 [ScrapedTorrent] 列表（已去重），空列表表示无结果或网络异常。
  Future<List<ScrapedTorrent>> search(
    String query, {
    int pages = 10,
    int startPage = 1,
  }) async {
    final q = query.trim().toLowerCase();
    final results = <ScrapedTorrent>[];
    final seen = <String>{};

    // 并发抓取：每批 5 页，避免压垮对方服务器
    const batchSize = 5;
    for (var batch = startPage; batch < startPage + pages; batch += batchSize) {
      final end = (batch + batchSize - 1).clamp(batch, startPage + pages - 1);
      final futures = <Future<List<ScrapedTorrent>?>>[];
      for (var p = batch; p <= end; p++) {
        futures.add(_fetchPage(p));
      }
      final batchResults = await Future.wait(futures);
      for (final items in batchResults) {
        if (items == null) continue;
        for (final item in items) {
          final key = item.magnet.isNotEmpty ? item.magnet : item.code;
          if (seen.contains(key)) continue;
          seen.add(key);
          if (q.isEmpty ||
              item.code.toLowerCase().contains(q) ||
              item.title.toLowerCase().contains(q)) {
            results.add(item);
          }
        }
      }
    }
    return results;
  }

  /// 抓取单页，失败返回 null。
  Future<List<ScrapedTorrent>?> _fetchPage(int page) async {
    final url = page == 1 ? '$_base/new' : '$_base/new?page=$page';
    try {
      final resp = await _dio.get(url);
      if (resp.data is String) {
        return _parseList(resp.data as String);
      }
    } on DioException catch (e) {
      debugPrint('141ppv page $page fetch error: $e');
    }
    return null;
  }

  /// 解析列表页 HTML，提取每个种子条目。
  List<ScrapedTorrent> _parseList(String html) {
    final items = <ScrapedTorrent>[];

    // 每个种子条目：从 magnet 链接定位，向前搜索图片/代码，向后收尾。
    // 正则：匹配 <a href="magnet:?xt=urn:btih:..."> 及其上下文。
    final magnetRE = RegExp(
      r'<img[^>]*\s+src="([^"]+)"[^>]*>'
      r'[\s\S]*?'
      r'<a[^>]*\s+href="(/torrent/([^"]+))"[^>]*>([^<]+)</a>'
      r'[\s\S]*?'
      r'<a[^>]*\s+href="(/date/[^"]*)"[^>]*>([^<]+)</a>'
      r'[\s\S]*?'
      r'<a[^>]*\s+href="(magnet:\?xt=urn:btih:[^"]+)"',
      caseSensitive: false,
    );

    for (final m in magnetRE.allMatches(html)) {
      final thumb = m.group(1) ?? '';
      final torrentPath = m.group(2) ?? '';  // /torrent/CODE
      final code = m.group(3) ?? '';
      final nameFromH5 = m.group(4) ?? '';
      final date = m.group(6) ?? '';
      final magnet = m.group(7) ?? '';

      if (code.isEmpty || magnet.isEmpty) continue;

      // 提取 SIZE：在 h5 的 <a> 之后、</h5> 之前。
      final size = _extractSize(html, m.start, m.end) ?? '';

      items.add(ScrapedTorrent(
        code: code.trim(),
        title: nameFromH5.trim().isNotEmpty
            ? nameFromH5.trim()
            : code.trim(),
        size: size,
        date: date.trim(),
        thumbnail: thumb.startsWith('http') ? thumb : null,
        magnet: magnet,
        torrentUrl: '$_base/download/$code.torrent',
        pageUrl: '$_base$torrentPath',
      ));
    }

    return items;
  }

  /// 在 magnet 匹配区间内提取文件大小。
  String? _extractSize(String html, int start, int end) {
    // h5 内通常是 "CODE 5.3 GB" 格式
    final snippet = html.substring(
      (start - 300).clamp(0, html.length),
      end,
    );
    final sizeRE = RegExp(
      r'(\d+\.?\d*\s*(GB|MB|TB|KB))',
      caseSensitive: false,
    );
    final m = sizeRE.firstMatch(snippet);
    return m?.group(1)?.trim();
  }

  /// 抓取详情页并提取作品简介，自动翻译为中文。
  Future<String?> fetchDescription(String pageUrl) async {
    try {
      final resp = await _dio.get(pageUrl);
      if (resp.data is! String) return null;
      final html = resp.data as String;

      // 在 "作品詳細" 后的 panel-body 找描述
      final re = RegExp(
        r'作品詳細[\s\S]*?<div[^>]*class="panel-body"[^>]*>([\s\S]*?)</div>',
        caseSensitive: false,
      );
      final m = re.firstMatch(html);
      String? desc;
      if (m != null) {
        desc = m.group(1)?.trim();
        if (desc != null) {
          desc = desc.replaceAll(RegExp(r'<[^>]*>'), '');
          desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }

      if (desc == null || desc.isEmpty) {
        // Fallback: og:description
        final ogRE = RegExp(
          r'<meta[^>]*property="og:description"[^>]*content="([^"]*)"',
          caseSensitive: false,
        );
        final ogM = ogRE.firstMatch(html);
        desc = ogM?.group(1)?.trim();
      }

      if (desc == null || desc.isEmpty) return null;

      // 翻译为中文
      final translated = await TranslateService.instance.toChinese(desc);
      return translated;
    } catch (e) {
      debugPrint('fetchDescription error: $e');
      return null;
    }
  }
}
