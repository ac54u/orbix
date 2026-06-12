import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

/// App 自更新：查 GitHub Releases → 比对版本 → 交给 TrollStore 安装。
///
/// iOS 沙盒禁止 App 静默安装 ipa，但 TrollStore（1.3+）劫持了系统
/// `apple-magnifier://` scheme，`install?url=<ipa>` 会让 TrollStore
/// 自行下载并永久安装。因此本服务只负责「发现新版 + 把 ipa 直链交给
/// TrollStore」，不自己下载二进制。
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// 发布仓库（GitHub Actions 在此打 release，并把 .ipa 作为资源上传）。
  static const String repo = 'ac54u/orbix';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Accept': 'application/vnd.github+json'},
  ));

  /// 拼出 TrollStore 安装链接。打开它即触发 TrollStore 下载+安装该 ipa。
  static String trollStoreInstallUrl(String ipaUrl) =>
      'apple-magnifier://install?url=${Uri.encodeComponent(ipaUrl)}';

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

  /// 检查更新：返回当前版本、是否有新版、以及最新 release。
  Future<UpdateCheck> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version; // 如 "1.0.0"
    try {
      // 取最近若干条（含 prerelease），挑出「最新且带 .ipa 资源」的一条。
      final resp = await _dio.get(
        'https://api.github.com/repos/$repo/releases',
        queryParameters: {'per_page': 10},
      );
      final data = resp.data;
      if (data is! List) {
        return UpdateCheck(
            hasUpdate: false, currentVersion: current, error: '无法解析发布信息');
      }

      AppRelease? best;
      for (final r in data) {
        if (r is! Map) continue;
        if (r['draft'] == true) continue;
        final asset = _pickIpa(r['assets']);
        if (asset == null) continue;
        final rel = AppRelease(
          version: (r['tag_name'] ?? '')
              .toString()
              .replaceFirst(RegExp(r'^v', caseSensitive: false), ''),
          tag: (r['tag_name'] ?? '').toString(),
          notes: (r['body'] ?? '').toString().trim(),
          ipaUrl: (asset['browser_download_url'] ?? '').toString(),
          ipaSize: (asset['size'] is num) ? (asset['size'] as num).toInt() : 0,
          htmlUrl: (r['html_url'] ?? '').toString(),
        );
        // releases 接口按时间倒序，第一条带 ipa 的即最新。
        best = rel;
        break;
      }

      if (best == null) {
        return UpdateCheck(
            hasUpdate: false,
            currentVersion: current,
            error: '未找到可安装的发布（缺少 .ipa 资源）');
      }
      final hasUpdate = compareVersions(best.version, current) > 0;
      return UpdateCheck(
        hasUpdate: hasUpdate,
        currentVersion: current,
        latest: best,
      );
    } on DioException catch (e) {
      debugPrint('检查更新失败: $e');
      final msg = e.response?.statusCode == 403
          ? 'GitHub 接口请求过于频繁，请稍后再试'
          : '网络异常，无法连接 GitHub';
      return UpdateCheck(
          hasUpdate: false, currentVersion: current, error: msg);
    } catch (e) {
      debugPrint('检查更新失败: $e');
      return UpdateCheck(
          hasUpdate: false, currentVersion: current, error: '检查更新失败');
    }
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
