import 'package:dio/dio.dart';
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

  const ScrapedTorrent({
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

  /// 搜索种子：从 /new 列表抓取 [pages] 页，按 [query] 过滤标题/代码。
  ///
  /// 返回 [ScrapedTorrent] 列表（已去重），空列表表示无结果或网络异常。
  Future<List<ScrapedTorrent>> search(String query,
      {int pages = 3}) async {
    final q = query.trim().toLowerCase();
    final results = <ScrapedTorrent>[];
    final seen = <String>{};

    for (var page = 1; page <= pages; page++) {
      final url = page == 1 ? '$_base/new' : '$_base/new?page=$page';
      try {
        final resp = await _dio.get(url);
        if (resp.data is! String) continue;
        final items = _parseList(resp.data as String);
        for (final item in items) {
          final key = item.magnet.isNotEmpty
              ? item.magnet
              : item.code;
          if (seen.contains(key)) continue;
          seen.add(key);
          if (q.isEmpty ||
              item.code.toLowerCase().contains(q) ||
              item.title.toLowerCase().contains(q)) {
            results.add(item);
          }
        }
      } on DioException catch (e) {
        debugPrint('141ppv page $page fetch error: $e');
        // 单页失败不阻断后续页
        continue;
      }
    }
    return results;
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
}
