import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/qbit_api.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;

  // 动态数据源
  List<dynamic> _torrents = [];
  int _totalDlSpeed = 0; // 全局下载速度 (Bytes/s)
  int _totalUpSpeed = 0; // 全局上传速度 (Bytes/s)
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchData(); // 初始拉取一次
    // 每 2 秒刷新一次，保持与服务器实时同步
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // —— 核心网络请求逻辑 ——
  Future<void> _fetchData() async {
    final api = QBitApi();
    try {
      final torrents = await api.getTorrents();
      final transferInfo = await api.getTransferInfo();
      if (mounted) {
        setState(() {
          _torrents = torrents;
          _totalDlSpeed = transferInfo['dl_info_speed'] ?? 0;
          _totalUpSpeed = transferInfo['up_info_speed'] ?? 0;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint("获取数据失败: $e");
    }
  }

  // —— 数据格式化工具 ——

  String _formatSpeed(int bytes) {
    if (bytes == 0) return "0 B/s";
    if (bytes < 1024) return "$bytes B/s";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB/s";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB/s";
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return "0 B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  String _formatEta(int seconds) {
    if (seconds == 8640000 || seconds < 0) return "∞"; // qBittorrent 用 8640000 表示无限
    int d = seconds ~/ 86400;
    int h = (seconds % 86400) ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (d > 0) return "${d}d ${h}h";
    if (h > 0) return "${h}h ${m}m";
    if (m > 0) return "${m}m ${s}s";
    return "${s}s";
  }

  // 将 qBittorrent 状态码转为 UI 文本与颜色（兼容新版 stopped* / 旧版 paused*）
  Map<String, dynamic> _parseState(String state) {
    switch (state) {
      case 'downloading':
      case 'metaDL':
      case 'forcedDL':
        return {"text": "下载中", "color": const Color(0xFF007AFF), "isDl": true};
      case 'stalledDL':
        return {"text": "等待下载", "color": const Color(0xFF007AFF), "isDl": true};
      case 'uploading':
      case 'forcedUP':
        return {"text": "上传中", "color": const Color(0xFF34C759), "isDl": false};
      case 'stalledUP':
        return {"text": "做种中", "color": const Color(0xFF34C759), "isDl": false};
      case 'pausedDL':
      case 'stoppedDL':
        return {"text": "已暂停", "color": const Color(0xFF8E8E93), "isDl": true};
      case 'pausedUP':
      case 'stoppedUP':
        return {"text": "已完成", "color": const Color(0xFF8E8E93), "isDl": false};
      case 'checkingUP':
      case 'checkingDL':
      case 'checkingResumeData':
        return {"text": "校验中", "color": const Color(0xFFFF9500), "isDl": true};
      case 'queuedDL':
      case 'queuedUP':
        return {"text": "排队中", "color": const Color(0xFF8E8E93), "isDl": false};
      case 'error':
      case 'missingFiles':
        return {"text": "错误", "color": const Color(0xFFFF3B30), "isDl": false};
      default:
        return {"text": state, "color": const Color(0xFF8E8E93), "isDl": false};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // 按底部 tab 切换页面（统计/搜索/设置为占位）
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildTorrentPage(),
                  _buildPlaceholder("统计"),
                  _buildPlaceholder("搜索"),
                  _buildPlaceholder("设置"),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.withOpacity(0.1)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildPlaceholder(String name) {
    return Center(
      child: Text("$name · 开发中",
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 16)),
    );
  }

  // 种子主页面
  Widget _buildTorrentPage() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildTopBar(),
            const SizedBox(height: 24),
            const Text(
              "种子",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildSpeedSummary(),
            const SizedBox(height: 24),
            _buildDynamicTorrentList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCircleButton(CupertinoIcons.bars, isOutlined: true),
        _buildCircleButton(CupertinoIcons.add, isOutlined: false),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, {required bool isOutlined}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOutlined ? Colors.transparent : const Color(0xFF007AFF),
        border: isOutlined ? Border.all(color: const Color(0xFF007AFF), width: 1.5) : null,
      ),
      child: Icon(icon, color: isOutlined ? const Color(0xFF007AFF) : Colors.white, size: 22),
    );
  }

  // 全局速度总览
  Widget _buildSpeedSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildSpeedCard(
            title: "上传",
            speedStr: _formatSpeed(_totalUpSpeed),
            icon: CupertinoIcons.arrow_up_circle_fill,
            color: const Color(0xFF007AFF),
            gradientColors: [const Color(0xFF007AFF), const Color(0xFF007AFF).withOpacity(0.1)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSpeedCard(
            title: "下载",
            speedStr: _formatSpeed(_totalDlSpeed),
            icon: CupertinoIcons.arrow_down_circle_fill,
            color: const Color(0xFF5AC8FA),
            gradientColors: [const Color(0xFF5AC8FA), const Color(0xFF5AC8FA).withOpacity(0.1)],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedCard({
    required String title,
    required String speedStr,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
  }) {
    final parts = speedStr.split(' ');
    final number = parts[0];
    final unit = parts.length > 1 ? parts[1] : "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(number, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(colors: gradientColors, begin: Alignment.centerLeft, end: Alignment.centerRight),
            ),
          )
        ],
      ),
    );
  }

  // —— 动态渲染服务器返回的种子列表 ——
  Widget _buildDynamicTorrentList() {
    if (_torrents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            _loaded ? "暂无种子任务" : "加载中…",
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: _torrents.map((t) {
        final name = t['name'] ?? "未知任务";
        final totalSize = (t['total_size'] ?? 0) as int;
        final progress = (t['progress'] ?? 0.0).toDouble();
        final stateInfo = _parseState(t['state'] ?? "");
        final dlspeed = (t['dlspeed'] ?? 0) as int;
        final upspeed = (t['upspeed'] ?? 0) as int;
        final ratio = (t['ratio'] ?? 0.0).toDouble();
        final eta = (t['eta'] ?? 8640000) as int;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildTorrentCard(
            title: name,
            size: _formatSize(totalSize),
            progress: progress,
            progressText: "${(progress * 100).toStringAsFixed(1)}%",
            statusText: stateInfo["text"],
            themeColor: stateInfo["color"],
            isDownloading: stateInfo["isDl"],
            downSpeed: _formatSpeed(dlspeed),
            upSpeed: _formatSpeed(upspeed),
            ratio: ratio.toStringAsFixed(2),
            eta: _formatEta(eta),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTorrentCard({
    required String title,
    required String size,
    required double progress,
    required String progressText,
    required String statusText,
    required Color themeColor,
    required bool isDownloading,
    required String downSpeed,
    required String upSpeed,
    required String ratio,
    required String eta,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDownloading ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_up_circle_fill,
                color: themeColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(size, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progressText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 6,
                width: constraints.maxWidth,
                decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(3)),
                child: Row(
                  children: [
                    Container(
                      width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                      decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(3)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(CupertinoIcons.arrow_down_circle_fill, downSpeed, const Color(0xFF007AFF)),
              _buildStatItem(CupertinoIcons.arrow_up_circle_fill, upSpeed, const Color(0xFF34C759)),
              _buildStatItem(CupertinoIcons.graph_square, ratio, const Color(0xFFFF9500)),
              _buildStatItem(CupertinoIcons.time, eta, const Color(0xFF8E8E93)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, CupertinoIcons.arrow_down_circle_fill, "种子"),
          _buildNavItem(1, CupertinoIcons.chart_bar_alt_fill, "统计"),
          _buildNavItem(2, CupertinoIcons.search, "搜索"),
          _buildNavItem(3, CupertinoIcons.gear_alt, "设置"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF007AFF) : const Color(0xFF8E8E93);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}
