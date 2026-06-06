import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ServerConfig {
  String url;
  String username;
  String password;

  ServerConfig({required this.url, required this.username, required this.password});
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

  // 1. 登录并获取 Cookie（带详细结果，供测试连接使用）
  Future<ConnectResult> connect() async {
    if (currentServer == null) {
      return const ConnectResult(ConnectStatus.unknown, '尚未配置服务器信息');
    }
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
    try {
      final response = await _dio.get('/api/v2/sync/maindata', queryParameters: {'rid': rid});
      return response.data;
    } catch (e) {
      print("同步数据失败: $e");
      return null;
    }
  }
}