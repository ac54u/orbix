import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/splash_screen.dart';
import 'controllers/torrent_controller.dart';
import 'widgets/torrent_cell.dart';

void main() {
  runApp(const OrbixApp());
}

class OrbixApp extends StatelessWidget {
  const OrbixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Orbix',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        primaryColor: CupertinoColors.activeBlue,
      ),
      home: const SplashScreen(), // 启动决策：自动登录 / 欢迎页 / 登录页
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 登录成功进入此页面后，自动注入并初始化 TorrentController 开始数据轮询
  final TorrentController controller = Get.put(TorrentController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const TorrentListScreen(),
          const Center(child: Text('统计 (开发中)')),
          const Center(child: Text('搜索 (开发中)')),
          const Center(child: Text('设置 (开发中)')),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _currentIndex,
        activeColor: CupertinoColors.activeBlue,
        backgroundColor: Colors.white.withOpacity(0.9),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.arrow_down_circle_fill), label: '种子'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.graph_square_fill), label: '统计'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.search), label: '搜索'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class TorrentListScreen extends StatelessWidget {
  const TorrentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TorrentController controller = Get.find<TorrentController>();

    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('种子', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.add_circled_solid, size: 28, color: Colors.black),
            onPressed: () {
              // TODO: 预留添加种子的弹窗逻辑位置
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 顶端全局速度卡片面板
                Row(
                  children: [
                    Expanded(child: Obx(() => _buildSpeedCard('上传', controller.uploadSpeed.value, CupertinoIcons.arrow_up_circle_fill, CupertinoColors.activeBlue))),
                    const SizedBox(width: 16),
                    Expanded(child: Obx(() => _buildSpeedCard('下载', controller.downloadSpeed.value, CupertinoIcons.arrow_down_circle_fill, CupertinoColors.systemTeal))),
                  ],
                ),
                const SizedBox(height: 10),
                // 连接状态提示（断线或同步异常时显示）
                Obx(() => controller.isConnected.value
                  ? const SizedBox.shrink()
                  : const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text("数据同步中或连接异常...", style: TextStyle(color: CupertinoColors.systemRed, fontSize: 12)),
                    )
                ),
              ],
            ),
          ),
        ),
        // 响应式种子任务列表
        Obx(() {
          if (controller.torrents.isEmpty && controller.isConnected.value) {
            return const SliverFillRemaining(
              child: Center(child: Text("当前没有任何下载任务", style: TextStyle(color: CupertinoColors.systemGrey))),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final torrentData = controller.torrents[index];
                return TorrentCell(torrent: torrentData);
              },
              childCount: controller.torrents.length,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSpeedCard(String title, String speed, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(speed, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.black)),
        ],
      ),
    );
  }
}