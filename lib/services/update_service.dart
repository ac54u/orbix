import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一个可安装的 release（从 GitHub Releases 解析而来）。
class AppRelease {
  /// 归一化版本号（去掉前缀 v），如 "1.1.0"。
  final String version;

  /// 原始 tag，如 "v1.1.0"。
  final String tag;

  /// release 说明 / 更新日志（GitHub release body）。
  final String notes;

  /// `.ipa` 资源的直链（交给 TrollStore 下载安装）。
  final String ipaUrl;

  /// `.ipa` 体积（字节），用于展示。
  final int ipaSize;

  /// release 网页地址（无 ipa 时的兜底，用浏览器打开）。
  final String htmlUrl;

  const AppRelease({
    required this.version,
    required this.tag,
    required this.notes,
    required this.ipaUrl,
    required this.ipaSize,
    required this.htmlUrl,
  });
}

/// 检测结果。
class UpdateCheck {
  /// 是否有比当前更高的版本。
  final bool hasUpdate;

  /// 当前 app 版本号（如 "1.0.0"）。
  final String currentVersion;

  /// 最新可安装 release（没有可用 release 时为 null）。
  final AppRelease? latest;

  /// 检测失败时的错误描述（成功为 null）。
  final String? error;

  const UpdateCheck({
    required this.hasUpdate,
    required this.currentVersion,
    this.latest,
    this.error,
  });
}

/// App 自更新：查 GitHub Releases → 比对版本 → App 内下载 ipa → 交给 TrollStore。
///
/// 早期方案依赖 `apple-magnifier://install?url=` scheme，但该 scheme 易被系统
/// 「放大器」App 抢注，导致点更新跳进放大器。现改为：本服务直接把 ipa 下载到
/// 临时目录，UI 层再唤起 iOS 原生分享面板，由用户选「拷贝到 TrollStore」安装，
/// 全程不依赖任何 URL scheme。
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// 发布仓库（GitHub Actions 在此打 release，并把 .ipa 作为资源上传）。
  static const String repo = 'ac54u/orbix';

  /// 本地缓存 TTL（秒）—— 成功结果 30 分钟内不重复请求，避免触发 GitHub
  /// 匿名 API 限流（60 次/小时/ip）。
  static const int _cacheTtlSeconds = 30 * 60;

  /// SharedPreferences 键前缀。
  static const String _prefTs = 'update_ts';
  static const String _prefVer = 'update_ver';
  static const String _prefTag = 'update_tag';
  static const String _prefNotes = 'update_notes';
  static const String _prefIpa = 'update_ipa';
  static const String _prefSize = 'update_size';
  static const String _prefHtml = 'update_html';
  static const String _prefAppVer = 'update_app_ver';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Accept': 'application/vnd.github+json'},
  ));

  /// 比较两个版本号：a>b 返回正、a<b 返回负、相等返回 0。
  /// 按 `.`/`-`/`+` 拆段逐段比数字，容错前缀 v 与非数字段。
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .trim()
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split(RegExp(r'[.\-+]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final pa = parts(a), pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  // ── 本地缓存 ────────────────────────────────────────────────────────

  /// 尝试从 SharedPreferences 读取未过期的缓存结果。
  /// 返回 null 表示无缓存/已过期/app 刚升级，需要发起网络请求。
  Future<AppRelease?> _loadCache(String currentAppVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_prefTs) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - ts > _cacheTtlSeconds) return null;
      // App 升级后缓存失效：上次存的服务器最新版可能已经比自己还旧。
      final cachedAppVer = prefs.getString(_prefAppVer) ?? '';
      if (cachedAppVer != currentAppVersion) return null;
      final ver = prefs.getString(_prefVer);
      if (ver == null || ver.isEmpty) return null;
      return AppRelease(
        version: ver,
        tag: prefs.getString(_prefTag) ?? '',
        notes: prefs.getString(_prefNotes) ?? '',
        ipaUrl: prefs.getString(_prefIpa) ?? '',
        ipaSize: prefs.getInt(_prefSize) ?? 0,
        htmlUrl: prefs.getString(_prefHtml) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// 把 release 写入缓存（同时记下当前 app 版本，用于升级后自动失效）。
  Future<void> _saveCache(AppRelease rel, String currentAppVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTs, DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await prefs.setString(_prefVer, rel.version);
      await prefs.setString(_prefTag, rel.tag);
      await prefs.setString(_prefNotes, rel.notes);
      await prefs.setString(_prefIpa, rel.ipaUrl);
      await prefs.setInt(_prefSize, rel.ipaSize);
      await prefs.setString(_prefHtml, rel.htmlUrl);
      await prefs.setString(_prefAppVer, currentAppVersion);
    } catch (_) {
      // 缓存写入失败不影响主流程
    }
  }

  // ── 网络请求 ────────────────────────────────────────────────────────

  /// 检查更新：优先走缓存（30 min TTL），缓存未命中时先试 `/releases/latest`
  /// 轻量端点，404 时回退到列表端点（取最近 5 条）。
  Future<UpdateCheck> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version; // 如 "1.0.0"

    // 1. 命中缓存：直接复用，仅重新比对当前版本。
    //    若 app 刚升级过，缓存的 app 版本与当前不同会自动失效。
    final cached = await _loadCache(current);
    if (cached != null) {
      final hasUpdate = compareVersions(cached.version, current) > 0;
      return UpdateCheck(
        hasUpdate: hasUpdate,
        currentVersion: current,
        latest: cached,
      );
    }

    // 2. 尝试 /releases/latest（仅返回最新非 draft 非 prerelease 的正式发布）。
    try {
      final rel = await _fetchLatest();
      if (rel != null) {
        await _saveCache(rel, current);
        return UpdateCheck(
          hasUpdate: compareVersions(rel.version, current) > 0,
          currentVersion: current,
          latest: rel,
        );
      }
    } on DioException catch (e) {
      // 404 表示没有正式发布（可能全是 prerelease / draft），回退到列表端点。
      if (e.response?.statusCode != 404) {
        debugPrint('检查更新 /latest 失败: $e');
        return _rateLimitError(e, current);
      }
    }

    // 3. 回退：列表端点（覆盖 prerelease）。
    try {
      final rel = await _fetchFromList();
      if (rel != null) {
        await _saveCache(rel, current);
        return UpdateCheck(
          hasUpdate: compareVersions(rel.version, current) > 0,
          currentVersion: current,
          latest: rel,
        );
      }
      return UpdateCheck(
          hasUpdate: false,
          currentVersion: current,
          error: '未找到可安装的发布（缺少 .ipa 资源）');
    } on DioException catch (e) {
      debugPrint('检查更新 /releases 列表失败: $e');
      return _rateLimitError(e, current);
    } catch (e) {
      debugPrint('检查更新异常: $e');
      return UpdateCheck(
          hasUpdate: false, currentVersion: current, error: '检查更新失败');
    }
  }

  /// 调用 `/repos/$repo/releases/latest`（轻量，不计列表翻页）。
  Future<AppRelease?> _fetchLatest() async {
    final resp = await _dio.get(
      'https://api.github.com/repos/$repo/releases/latest',
    );
    final data = resp.data;
    if (data is! Map) return null;
    if (data['draft'] == true) return null;
    return _parseRelease(data);
  }

  /// 回退：调列表接口，取最近 5 条中第一条含 .ipa 的。
  Future<AppRelease?> _fetchFromList() async {
    final resp = await _dio.get(
      'https://api.github.com/repos/$repo/releases',
      queryParameters: {'per_page': 5},
    );
    final data = resp.data;
    if (data is! List) return null;
    for (final r in data) {
      if (r is! Map) continue;
      if (r['draft'] == true) continue;
      final rel = _parseRelease(r);
      if (rel != null) return rel;
    }
    return null;
  }

  /// 从 API 返回的 release JSON 解析为 [AppRelease]；无 .ipa 资源时返回 null。
  AppRelease? _parseRelease(Map data) {
    final asset = _pickIpa(data['assets']);
    if (asset == null) return null;
    return AppRelease(
      version: (data['tag_name'] ?? '')
          .toString()
          .replaceFirst(RegExp(r'^v', caseSensitive: false), ''),
      tag: (data['tag_name'] ?? '').toString(),
      notes: (data['body'] ?? '').toString().trim(),
      ipaUrl: (asset['browser_download_url'] ?? '').toString(),
      ipaSize: (asset['size'] is num) ? (asset['size'] as num).toInt() : 0,
      htmlUrl: (data['html_url'] ?? '').toString(),
    );
  }

  /// 限流专用错误提示。
  UpdateCheck _rateLimitError(DioException e, String currentVersion) {
    final msg = e.response?.statusCode == 403
        ? 'GitHub 接口请求过于频繁，请稍后再试'
        : '网络异常，无法连接 GitHub';
    return UpdateCheck(
        hasUpdate: false, currentVersion: currentVersion, error: msg);
  }

  /// 把 release 的 .ipa 下载到临时目录，返回本地文件路径。
  /// [onProgress] 回传 (已收字节, 总字节)；总字节未知时 total 为 -1。
  /// 走独立 receiveTimeout=0（不限时），避免大文件被 8s 超时打断。
  Future<String> downloadIpa(
    AppRelease rel, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeTag = rel.tag.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '${dir.path}/Orbix-$safeTag.ipa';
    await _dio.download(
      rel.ipaUrl,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(receiveTimeout: Duration.zero),
    );
    return path;
  }

  /// 从 assets 数组里挑第一个 `.ipa`。
  Map? _pickIpa(dynamic assets) {
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is Map &&
          (a['name'] ?? '').toString().toLowerCase().endsWith('.ipa')) {
        return a;
      }
    }
    return null;
  }
}
