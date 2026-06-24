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
/// 按「最新」列表页（/new?page=N）抓取，客户端按关键字过滤标题/代码。
class TorrentSearchService {
  TorrentSearchService._();
  static final TorrentSearchService instance = TorrentSearchService._();

  static const String _base = 'https://www.141ppv.com';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,ja;q=0.8',
      'Referer': '$_base/',
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

  Future<List<ScrapedTorrent>?> _fetchPage(int page) async {
    final url = page == 1 ? '$_base/new' : '$_base/new?page=$page';
    try {
      final resp = await _dio.get(url);
      if (resp.data is String) {
        return _parseList(resp.data as String);
      }
    } catch (e) {
      debugPrint('141ppv page $page fetch error: $e');
    }
    return null;
  }

  List<ScrapedTorrent> _parseList(String html) {
    final items = <ScrapedTorrent>[];
    final cardRE = RegExp(r'<div\s+class="card\s+mb-3">', caseSensitive: false);
    final magnetRE = RegExp(
      r'href="(magnet:\?xt=urn:btih:[^"]+)"',
      caseSensitive: false,
    );
    final thumbRE = RegExp(
      r'<img[^>]*\s+src="([^"]+)"[^>]*>',
      caseSensitive: false,
    );
    final codeRE = RegExp(
      r'<a[^>]*\s+href="/torrent/([^"]+)"[^>]*>([^<]+)</a>',
      caseSensitive: false,
    );
    final dateRE = RegExp(
      r'<a[^>]*\s+href="/date/([^"]*)"[^>]*>([^<]+)</a>',
      caseSensitive: false,
    );
    final sizeRE = RegExp(
      r'(\d+\.?\d*\s*(?:GB|MB|TB|KB))',
      caseSensitive: false,
    );

    final cardMatches = cardRE.allMatches(html).toList();
    for (int i = 0; i < cardMatches.length; i++) {
      final cardStart = cardMatches[i].start;
      final cardEnd = (i + 1 < cardMatches.length)
          ? cardMatches[i + 1].start
          : html.length;
      final cardHtml = html.substring(cardStart, cardEnd);

      try {
        final magnetM = magnetRE.firstMatch(cardHtml);
        if (magnetM == null) continue;
        final magnet = magnetM.group(1)!;

        final thumbM = thumbRE.firstMatch(cardHtml);
        final thumb = (thumbM != null) ? thumbM.group(1)! : '';

        final codeM = codeRE.firstMatch(cardHtml);
        if (codeM == null) continue;
        final code = codeM.group(1)!.trim();
        final title = codeM.group(2)!.trim();

        final dateM = dateRE.firstMatch(cardHtml);
        final date = (dateM != null) ? dateM.group(2)!.trim() : '';

        final sizeM = sizeRE.firstMatch(cardHtml);
        final size = (sizeM != null) ? sizeM.group(1)!.trim() : '';

        items.add(ScrapedTorrent(
          code: code,
          title: title.isNotEmpty ? title : code,
          size: size,
          date: date,
          thumbnail: thumb.startsWith('http') ? thumb : null,
          magnet: magnet,
          torrentUrl: '$_base/download/$code.torrent',
          pageUrl: '$_base/torrent/$code',
        ));
      } catch (e) {
        debugPrint('141ppv parse item error: $e');
      }
    }

    return items;
  }

  /// 抓取详情页并提取作品简介，自动翻译为中文。
  Future<String?> fetchDescription(String pageUrl) async {
    try {
      final resp = await _dio.get<String>(pageUrl,
          options: Options(responseType: ResponseType.plain));
      final html = resp.data ?? '';
      if (html.isEmpty) return null;

      String? desc;

      // 1. 从卡片的可见文本 <p class="level has-text-grey-dark">
      final visibleRE = RegExp(
        r'<p\s+class="level\s+has-text-grey-dark">\s*(.*?)\s*</p>',
        caseSensitive: false,
        dotAll: true,
      );
      final visibleM = visibleRE.firstMatch(html);
      if (visibleM != null) {
        desc = visibleM.group(1)?.trim();
        if (desc != null) {
          desc = desc.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        }
      }

      // 2. 降级：meta description（去掉前缀）
      if (desc == null || desc.isEmpty) {
        final raw = _extractMetaDesc(html);
        if (raw != null) desc = raw;
      }

      if (desc == null || desc.isEmpty) return null;

      try {
        final translated = await TranslateService.instance.toChinese(desc);
        return translated;
      } catch (_) {
        return desc;
      }
    } catch (e) {
      debugPrint('fetchDescription error: $e');
      return null;
    }
  }

  String? _extractMetaDesc(String html) {
    for (final re in [
      RegExp(
        r'<meta[^>]*name="description"[^>]*content="([^"]*)"',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<meta[^>]*property="og:description"[^>]*content="([^"]*)"',
        caseSensitive: false,
        dotAll: true,
      ),
    ]) {
      final m = re.firstMatch(html);
      if (m != null) {
        final raw = m.group(1)?.trim() ?? '';
        if (raw.isNotEmpty) {
          return raw.replaceFirst(RegExp(
            r'^[^(]+\([^)]+\)\s*-\s*[^-]+-\s*',
            caseSensitive: false,
          ), '');
        }
      }
    }
    return null;
  }
}
