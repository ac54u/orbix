import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  String name;
  String url;
  String username;
  String password;
  // 保留原始字段，便于设置页展示与回填编辑（旧调用不传也能用）
  String host;
  String port;
  bool https;

  ServerConfig({
    this.name = '',
    required this.url,
    required this.username,
    required this.password,
    this.host = '',
    this.port = '',
    this.https = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'username': username,
        'password': password,
        'host': host,
        'port': port,
        'https': https,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
        name: (j['name'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        host: (j['host'] ?? '').toString(),
        port: (j['port'] ?? '').toString(),
        https: j['https'] == true,
      );
}

/// 连接测试的结果分类，便于 UI 给出准确提示
enum ConnectStatus { ok, authFailed, network, unknown }

class ConnectResult {
  final ConnectStatus status;
  final String message;
  const ConnectResult(this.status, this.message);
  bool get success => status == ConnectStatus.ok;
}

class QBitApi {
  late Dio _dio;
  late CookieJar _cookieJar;
  ServerConfig? currentServer;

  // 单例模式，确保全局只有一个 API 实例
  static final QBitApi _instance = QBitApi._internal();
  factory QBitApi() => _instance;

  QBitApi._internal() {
    _cookieJar = CookieJar();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  void setServer(ServerConfig config) {
    currentServer = config;
    _dio.options.baseUrl = config.url;
  }

  /// 智能拼接服务器 URL，容错常见填写错误：
  ///  - 主机里粘贴了完整网址 → 以其协议/端口为准
  ///  - 端口 443 → 强制 https；端口 80 → 强制 http（端口比开关更可靠）
  ///  - 协议默认端口（https:443 / http:80）自动省略
  static String buildUrl(String hostRaw, String portRaw, bool https) {
    final host0 = hostRaw.trim();
    final port = portRaw.trim();

    // 用户直接粘贴了完整 URL：以 URL 内的协议/端口为准
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(host0)) {
      final u = Uri.tryParse(host0);
      if (u != null && u.host.isNotEmpty) {
        final s = u.scheme.toLowerCase();
        if (u.hasPort) return '$s://${u.host}:${u.port}';
        if (port.isNotEmpty) return '$s://${u.host}:$port';
        return '$s://${u.host}';
      }
    }

    final host = host0.replaceAll(RegExp(r'/+$'), ''); // 去结尾斜杠
    String scheme;
    if (port == '443') {
      scheme = 'https';
    } else if (port == '80') {
      scheme = 'http';
    } else {
      scheme = https ? 'https' : 'http';
    }
    final isDefaultPort =
        (scheme == 'https' && port == '443') || (scheme == 'http' && port == '80');
    if (port.isEmpty || isDefaultPort) return '$scheme://$host';
    return '$scheme://$host:$port';
  }

  /// 从本地读取已保存的服务器配置；没有有效配置时返回 null。
  /// 同时兼容旧版本保存的完整 qbit_url。
  static Future<ServerConfig?> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('qbit_username');
    final password = prefs.getString('qbit_password') ?? '';

    String? host = prefs.getString('qbit_host');
    String? port = prefs.getString('qbit_port');
    bool https = prefs.getBool('qbit_https') ?? false;

    // 旧版只存了完整 url，拆出 scheme/host/port
    final legacy = prefs.getString('qbit_url');
    if (host == null && legacy != null && legacy.isNotEmpty) {
      final parsed = Uri.tryParse(legacy);
      if (parsed != null) {
        https = parsed.scheme == 'https';
        host = parsed.host;
        if (parsed.hasPort) port = parsed.port.toString();
      }
    }

    if (host == null || host.trim().isEmpty || username == null || username.trim().isEmpty) {
      return null;
    }

    final url = buildUrl(host, port ?? '', https);
    return ServerConfig(
      name: prefs.getString('qbit_name') ?? '',
      url: url,
      username: username.trim(),
      password: password,
      host: host.trim(),
      port: (port ?? '').trim(),
      https: https,
    );
  }

  // ——— 多服务器管理（设置页「切换服务器」用）———
  // 设计：`qbit_servers` 存服务器列表（JSON）；扁平 key 表示「当前活动服务器」，
  // 由 loadSavedConfig() 读取，供自动登录与主界面使用。两者保持同步。
  static const String _kServers = 'qbit_servers';

  /// 读取已保存的服务器列表。首次会把旧版单服务器迁移成列表。
  static Future<List<ServerConfig>> loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kServers);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => ServerConfig.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.url.isNotEmpty)
            .toList();
        return list;
      } catch (_) {
        // 解析失败则回退到迁移逻辑
      }
    }
    // 迁移：旧版单服务器（扁平 key）→ 列表
    final legacy = await loadSavedConfig();
    if (legacy != null) {
      await _saveServers([legacy]);
      return [legacy];
    }
    return [];
  }

  static Future<void> _saveServers(List<ServerConfig> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kServers, jsonEncode(servers.map((s) => s.toJson()).toList()));
  }

  /// 新增/更新一个服务器（按 url+username 去重）。
  static Future<void> upsertServer(ServerConfig s) async {
    final list = await loadServers();
    final idx =
        list.indexWhere((e) => e.url == s.url && e.username == s.username);
    if (idx >= 0) {
      list[idx] = s;
    } else {
      list.add(s);
    }
    await _saveServers(list);
  }

  /// 删除一个服务器。
  static Future<void> removeServer(ServerConfig s) async {
    final list = await loadServers();
    list.removeWhere((e) => e.url == s.url && e.username == s.username);
    await _saveServers(list);
  }

  /// 把某服务器设为「当前活动服务器」：写回扁平 key，
  /// 这样下次自动登录 / loadSavedConfig() 都会用它。
  static Future<void> setActiveServer(ServerConfig s) async {
    final prefs = await SharedPreferences.getInstance();
    String host = s.host, port = s.port;
    bool https = s.https;
    // 兼容只带 url 的旧记录：从 url 反推 host/port/https
    if (host.isEmpty) {
      final u = Uri.tryParse(s.url);
      if (u != null) {
        https = u.scheme == 'https';
        host = u.host;
        port = u.hasPort ? u.port.toString() : '';
      }
    }
    await prefs.setString('qbit_name', s.name);
    await prefs.setString('qbit_host', host);
    await prefs.setString('qbit_port', port);
    await prefs.setString('qbit_username', s.username);
    await prefs.setString('qbit_password', s.password);
    await prefs.setBool('qbit_https', https);
    await prefs.remove('qbit_url');
  }

  // 1. 登录并获取 Cookie（带详细结果，供测试连接使用）
  Future<ConnectResult> connect() async {
    if (currentServer == null) {
      return const ConnectResult(ConnectStatus.unknown, '尚未配置服务器信息');
    }
    // 关键：先清空旧会话 cookie。否则带着上次的有效 QBT_SID 时，
    // qBittorrent 会忽略本次密码直接返回成功，导致错误密码也“连接成功”。
    await _cookieJar.deleteAll();
    try {
      final response = await _dio.post(
        '/api/v2/auth/login',
        data: {
          'username': currentServer!.username,
          'password': currentServer!.password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // 部分 qBittorrent 开启了 CSRF 校验，需带上 Referer/Origin
          headers: {
            'Referer': currentServer!.url,
            'Origin': currentServer!.url,
          },
          // 不让 Dio 因 401/403 抛异常，由我们自己判断状态码
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // 不同 qBittorrent 版本成功表现不一：
      //   - 旧版：200 且 body 为 "Ok."
      //   - 新版：204 空响应体（仅靠 Set-Cookie）
      // 失败统一为 401/403。因此以状态码为准，兼容旧版文本。
      final code = response.statusCode ?? 0;
      if (code == 200 || code == 204) {
        final ok = code == 204 ||
            response.data.toString().toLowerCase().contains('ok');
        if (ok) return const ConnectResult(ConnectStatus.ok, '连接成功');
        // 200 但 body 为 "Fails." 的旧版失败情况
        return const ConnectResult(ConnectStatus.authFailed, '用户名或密码错误');
      }
      if (code == 401 || code == 403) {
        return const ConnectResult(ConnectStatus.authFailed, '用户名或密码错误');
      }
      return ConnectResult(ConnectStatus.unknown, '服务器返回异常状态码：$code');
    } on DioException catch (e) {
      return ConnectResult(ConnectStatus.network, _describeDioError(e));
    } catch (e) {
      return ConnectResult(ConnectStatus.unknown, e.toString());
    }
  }

  // 兼容旧调用：只关心成功与否
  Future<bool> login() async => (await connect()).success;

  String _describeDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查地址、端口或服务器是否在线';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请检查网络、地址和端口';
      case DioExceptionType.badCertificate:
        return 'HTTPS 证书校验失败';
      default:
        return e.message ?? '网络请求失败';
    }
  }

  // 2. 获取主数据 (增量同步)
  Future<Map<String, dynamic>?> syncMainData(int rid) async {
    final r = await _authedGet('/api/v2/sync/maindata', query: {'rid': rid});
    final data = r?.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  // 3. 种子列表
  Future<List<dynamic>> getTorrents() async {
    final r = await _authedGet('/api/v2/torrents/info');
    final data = r?.data;
    return data is List ? data : [];
  }

  // 4. 全局传输信息（含 dl_info_speed / up_info_speed）
  Future<Map<String, dynamic>> getTransferInfo() async {
    final r = await _authedGet('/api/v2/transfer/info');
    final data = r?.data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// 单个种子的「通用属性」（保存路径、做种/分享、连接数、各类时间等）
  Future<Map<String, dynamic>?> getProperties(String hash) async {
    final r = await _authedGet('/api/v2/torrents/properties',
        query: {'hash': hash});
    final data = r?.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// 单个种子在列表中的最新快照（按 hash 过滤，返回那条 Map）
  Future<Map<String, dynamic>?> getTorrentByHash(String hash) async {
    final r = await _authedGet('/api/v2/torrents/info', query: {'hashes': hash});
    final data = r?.data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first);
    }
    return null;
  }

  /// 种子内的文件列表（名称、大小、进度、优先级）
  Future<List<dynamic>> getTorrentFiles(String hash) async {
    final r = await _authedGet('/api/v2/torrents/files', query: {'hash': hash});
    final data = r?.data;
    return data is List ? data : [];
  }

  // ——— 种子操作（长按菜单）———
  // qBittorrent v5.x（Web API 2.11+）把 resume/pause 改名为 start/stop。
  // 这些接口成功时返回 200。

  /// 启动（继续）
  Future<bool> startTorrent(String hash) =>
      _torrentAction('/api/v2/torrents/start', {'hashes': hash});

  /// 暂停（停止）
  Future<bool> stopTorrent(String hash) =>
      _torrentAction('/api/v2/torrents/stop', {'hashes': hash});

  /// 强制启动（无视队列/做种限制）
  Future<bool> forceStartTorrent(String hash) => _torrentAction(
      '/api/v2/torrents/setForceStart', {'hashes': hash, 'value': 'true'});

  /// 强制重新校验
  Future<bool> recheckTorrent(String hash) =>
      _torrentAction('/api/v2/torrents/recheck', {'hashes': hash});

  /// 强制重新汇报（向 Tracker 重新汇报）
  Future<bool> reannounceTorrent(String hash) =>
      _torrentAction('/api/v2/torrents/reannounce', {'hashes': hash});

  /// 删除任务；deleteFiles=true 时连同已下载文件一并删除
  Future<bool> deleteTorrent(String hash, {bool deleteFiles = false}) =>
      _torrentAction('/api/v2/torrents/delete',
          {'hashes': hash, 'deleteFiles': deleteFiles ? 'true' : 'false'});

  // ——— 添加任务 ———

  /// 添加磁力链接 / 种子 URL（支持多行，每行一个）；可带分类/标签/保存路径。
  /// 返回 null＝成功；非空字符串＝失败原因（直接给用户看）。
  Future<String?> addMagnet(
    String urls, {
    String? category,
    String? tags,
    String? savePath,
  }) =>
      _postAdd(() => FormData.fromMap(_addFields(
            {'urls': urls},
            category: category,
            tags: tags,
            savePath: savePath,
          )));

  /// 添加本地 .torrent 文件（字节）；可带分类/标签/保存路径。
  /// 返回 null＝成功；非空字符串＝失败原因。
  Future<String?> addTorrentBytes(
    List<int> bytes,
    String filename, {
    String? category,
    String? tags,
    String? savePath,
  }) =>
      _postAdd(() => FormData.fromMap(_addFields(
            {'torrents': MultipartFile.fromBytes(bytes, filename: filename)},
            category: category,
            tags: tags,
            savePath: savePath,
          )));

  /// 把可选的分类/标签/保存路径并入 add 表单（空值不发，避免覆盖服务器默认）
  Map<String, dynamic> _addFields(
    Map<String, dynamic> base, {
    String? category,
    String? tags,
    String? savePath,
  }) {
    if (category != null && category.trim().isNotEmpty) {
      base['category'] = category.trim();
    }
    if (tags != null && tags.trim().isNotEmpty) {
      base['tags'] = tags.trim();
    }
    if (savePath != null && savePath.trim().isNotEmpty) {
      base['savepath'] = savePath.trim();
    }
    return base;
  }

  /// POST /api/v2/torrents/add，401/403 自动重登重试。
  /// FormData 是一次性的（流读完即失效），重试时用 build() 重新构造。
  /// 返回 null＝成功；非空字符串＝失败原因（用于直接提示用户、便于排查）。
  Future<String?> _postAdd(FormData Function() build) async {
    // 放宽超时：上传 .torrent + qB 处理 + 远程往返常超过全局 3 秒，
    // 否则会“服务器已添加成功、客户端却超时报失败”。
    // 关键：带上 Referer/Origin，否则开启 CSRF 校验的 qBittorrent 会 403，
    // 即便登录成功也无法添加（登录请求本就带了这两个头）。
    final opts = Options(
      validateStatus: (s) => s != null && s < 500,
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        if (currentServer != null) 'Referer': currentServer!.url,
        if (currentServer != null) 'Origin': currentServer!.url,
      },
    );

    // 添加前记录已有种子的 hash 集合：qB 的 add 响应（"Ok."/"Fails."）并不可靠，
    // 以“列表里是否真的多了新种子”为准来判定成功，避免误报失败。
    Set<String> hashesOf(List<dynamic> list) => list
        .map((t) => (t is Map ? t['hash'] : null)?.toString() ?? '')
        .where((h) => h.isNotEmpty)
        .toSet();
    Set<String> before = {};
    try {
      before = hashesOf(await getTorrents());
    } catch (_) {}
    // 核对是否真的新增了种子。qB 收到 .torrent 后是异步解析入库的，
    // add 接口返回的瞬间列表里往往还没有它，故轮询几次给入库留时间。
    // 返回 true=确实新增；false=可达但始终没新增；null=列表一直拉不到。
    Future<bool?> addedNew() async {
      bool reachable = false;
      for (var i = 0; i < 5; i++) {
        try {
          if (hashesOf(await getTorrents()).difference(before).isNotEmpty) {
            return true;
          }
          reachable = true;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 400));
      }
      return reachable ? false : null;
    }

    try {
      var r = await _dio.post('/api/v2/torrents/add',
          data: build(), options: opts);
      if (r.statusCode == 401 || r.statusCode == 403) {
        final res = await connect();
        if (!res.success) return '登录已失效：${res.message}';
        r = await _dio.post('/api/v2/torrents/add',
            data: build(), options: opts);
      }
      final code = r.statusCode ?? 0;
      if (code == 403) return '服务器拒绝（403），可能开启了 CSRF/Host 校验';
      if (code == 415) return '不支持的请求格式（415）';
      if (code < 200 || code >= 300) return '服务器返回状态码 $code';
      // "Fails." 既可能是“重复种子（其实已在列表）”，也可能是“链接/文件无效”。
      // 以列表为准：真的多了新种子就是成功；否则才提示已存在/无效。
      if (r.data.toString().toLowerCase().contains('fail')) {
        if (await addedNew() == true) return null;
        return '该种子已在列表中，或链接/文件无效';
      }
      return null;
    } on DioException catch (e) {
      print("添加任务失败: $e");
      // 字节已发出、服务器可能已同步处理，只是回执超时。以列表核对：
      // 确实新增→成功；无法核对（连服务器都不通）→乐观当成功，避免误报；
      // 能核对且没新增→服务器确实没收到，照实报错。
      if (e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return (await addedNew() == false) ? _describeDioError(e) : null;
      }
      return _describeDioError(e);
    }
  }

  /// 带会话保活的种子操作 POST：401/403（会话过期）时自动重登一次再重试。
  Future<bool> _torrentAction(String path, Map<String, dynamic> form) async {
    final opts = Options(
      contentType: Headers.formUrlEncodedContentType,
      validateStatus: (s) => s != null && s < 500,
    );
    try {
      var r = await _dio.post(path, data: form, options: opts);
      if (r.statusCode == 401 || r.statusCode == 403) {
        final res = await connect(); // 清旧 cookie 并重新登录
        if (!res.success) return false;
        r = await _dio.post(path, data: form, options: opts);
      }
      return r.statusCode == 200;
    } on DioException catch (e) {
      print("操作失败 $path: $e");
      return false;
    }
  }

  /// 带会话保活的 GET：遇到 401/403（会话过期）时自动重新登录并重试一次。
  /// 让数据页无需关心登录态，断线/换会话后能自愈。
  Future<Response?> _authedGet(String path, {Map<String, dynamic>? query}) async {
    final opts = Options(validateStatus: (s) => s != null && s < 500);
    try {
      var r = await _dio.get(path, queryParameters: query, options: opts);
      if (r.statusCode == 401 || r.statusCode == 403) {
        final res = await connect(); // connect() 会清旧 cookie 并重新登录
        if (!res.success) return null;
        r = await _dio.get(path, queryParameters: query, options: opts);
      }
      return r.statusCode == 200 ? r : null;
    } on DioException catch (e) {
      print("请求失败 $path: $e");
      return null;
    }
  }
}