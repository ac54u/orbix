# Orbix

> 一款精致的 iOS 端 qBittorrent 远程客户端，基于 Flutter 打造，遵循 iOS 设计规范。

Orbix 让你在 iPhone 上优雅地管理远程 qBittorrent 服务器：实时查看下载/做种、管理任务、查看详情、监控服务器状态，并支持本地任务搜索与联网搜种。

---

## ✨ 功能

- **多服务器管理**：添加 / 切换 / 编辑 / 删除多个 qBittorrent 服务器；长按服务器可编辑，新增以 iOS Page Sheet 半屏弹出。
- **任务列表**：实时进度、状态、上下行速度、分享率、ETA；按「全部 / 下载中 / 做种中 / 活动中 / 已暂停 / 已完成」筛选。
- **任务详情**：点击卡片查看进度、传输统计、保存路径/时间等信息以及文件列表，并可启动 / 暂停 / 强制启动 / 校验 / 重新汇报 / 删除。
- **添加任务**：支持磁力链接、种子 URL，以及从本地选择 `.torrent` 文件上传；可指定分类 / 标签 / 保存路径。
- **统计仪表盘**：实时速度、会话与累计传输量、全局分享率、磁盘剩余、连接状态、DHT 节点，以及按状态分组的任务概览。
- **搜索**：
  - *本地任务*：按名称实时筛选自己的任务。
  - *联网搜种*：调用 qBittorrent 搜索引擎跨站点搜索，点按即可加入下载（需服务端安装搜索插件）。
- **完整深色模式**：配色跟随系统明暗自动切换。
- **会话自愈**：请求遇到会话过期（401/403）会自动重新登录并重试。

## 📱 环境要求

- iOS 设备（本项目仅面向 iOS，已移除其它平台配置）。
- 一台可访问的 **qBittorrent** 服务器，且已开启 **Web UI**。
- 联网搜种功能需在 qBittorrent 桌面端「搜索 → 搜索插件」中安装并启用插件。

## 🧱 技术栈

- **Flutter**（Dart `>=3.0.0 <4.0.0`）
- **GetX** — 路由与状态管理
- **Dio** + **dio_cookie_manager** / **cookie_jar** — HTTP 与会话 Cookie
- **shared_preferences** — 本地保存服务器配置
- **file_picker** — 选择本地 `.torrent` 文件

## 🚀 构建与安装

### 本地构建（需 Flutter 环境与 Xcode）

```bash
flutter pub get
flutter run                 # 连接设备 / 模拟器直接运行
flutter build ios --release # 生产构建
```

### GitHub Actions（无签名 IPA）

仓库内置 [`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml)：每次推送到 `master` 或手动触发（workflow_dispatch）会在 macOS runner 上构建一个**未签名**的 `Orbix.ipa`，作为 Artifact 上传。

你可以用 [AltStore](https://altstore.io/) / [Sideloadly](https://sideloadly.io/) 等工具用自己的 Apple ID 重签并侧载到设备。

## 📂 项目结构

```
lib/
├── main.dart                       # 入口 & 主题（亮/暗）
├── theme/
│   └── app_colors.dart             # 语义化动态配色（随明暗解析）
├── services/
│   └── qbit_api.dart               # qBittorrent WebUI API v2 封装（单例）
└── screens/
    ├── splash_screen.dart          # 启动决策：自动登录 / 欢迎 / 登录
    ├── welcome_screen.dart         # 首次欢迎页
    ├── login_screen.dart           # 添加 / 编辑服务器（整页 + Page Sheet）
    ├── main_screen.dart            # 主界面：任务列表 + 底部 Tab + 设置
    ├── torrent_detail_screen.dart  # 任务详情
    ├── add_torrent_screen.dart     # 添加任务（磁力 / URL / 文件）
    ├── stats_screen.dart           # 统计仪表盘
    └── search_screen.dart          # 本地搜索 + 联网搜种
```

## ⚙️ 配置说明

- 默认 Bundle ID 为 `com.example.orbix`,侧载/签名前请在 `ios/Runner.xcodeproj` 中改为你自己的标识。
- 应用通过 qBittorrent Web API v2 通信；CSRF 相关请求会自动附带 `Referer` / `Origin` 头。

## 📌 版本

当前版本：**v1.0.0**（首个发布版）。

---

仅供个人学习与自用，请遵守当地法律法规合理使用。
