// Orbix 单元测试：覆盖 URL 拼接的容错逻辑（纯函数，无需启动 UI）。
import 'package:flutter_test/flutter_test.dart';
import 'package:orbix/services/qbit_api.dart';

void main() {
  group('QBitApi.buildUrl', () {
    test('普通主机 + 端口', () {
      expect(QBitApi.buildUrl('192.168.1.2', '8080', false),
          'http://192.168.1.2:8080');
    });

    test('开启 HTTPS', () {
      expect(QBitApi.buildUrl('nas.local', '8443', true),
          'https://nas.local:8443');
    });

    test('端口 443 强制 https 且省略默认端口', () {
      expect(QBitApi.buildUrl('example.com', '443', false),
          'https://example.com');
    });

    test('端口 80 强制 http 且省略默认端口', () {
      expect(QBitApi.buildUrl('example.com', '80', true),
          'http://example.com');
    });

    test('粘贴完整 URL 时以其协议/端口为准', () {
      expect(QBitApi.buildUrl('https://example.com:9090', '8080', false),
          'https://example.com:9090');
    });

    test('去除主机结尾多余斜杠', () {
      expect(QBitApi.buildUrl('192.168.1.2/', '8080', false),
          'http://192.168.1.2:8080');
    });
  });
}
