import 'dart:async';
import 'package:get/get.dart';
import '../services/qbit_api.dart';

class TorrentController extends GetxController {
  final QBitApi api = QBitApi();
  Timer? _pollingTimer;
  int _rid = 0; // qBit 增量更新的游标

  // UI 绑定的响应式变量
  var downloadSpeed = "0 B/s".obs;
  var uploadSpeed = "0 B/s".obs;
  var torrents = [].obs;
  var isConnected = false.obs;

  @override
  void onInit() {
    super.onInit();
    // 此时 API 实例里已经有了登录页传入的 ServerConfig
    // 我们只需要把连接状态设为 true，并直接开启轮询拉取数据即可
    isConnected.value = true;
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchData();
    });
  }

  void _fetchData() async {
    final data = await api.syncMainData(_rid);
    if (data != null) {
      // 更新游标
      if (data['rid'] != null) _rid = data['rid'];

      // 更新全局速度
      if (data['server_state'] != null) {
        downloadSpeed.value = _formatBytes(data['server_state']['dl_info_speed']);
        uploadSpeed.value = _formatBytes(data['server_state']['up_info_speed']);
      }

      // 更新种子列表 (实际业务中需要处理增量更新合并，这里做简要演示)
      if (data['torrents'] != null) {
        Map<String, dynamic> torrentMap = data['torrents'];
        List<dynamic> updatedList = [];
        torrentMap.forEach((hash, info) {
          info['hash'] = hash;
          updatedList.add(info);
        });
        torrents.value = updatedList;
      }
    }
  }

  // 简单的字节转换工具
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B/s";
    const suffixes = ["B/s", "KB/s", "MB/s", "GB/s"];
    var i = 0;
    double b = bytes.toDouble();
    while (b > 1024 && i < 3) { b /= 1024; i++; }
    return "${b.toStringAsFixed(2)} ${suffixes[i]}";
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    super.onClose();
  }
}