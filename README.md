# Orbix

> 一款精致的 iOS 端 qBittorrent 远程客户端，原生 SwiftUI 构建，专为 iOS 17+ 打造。

Orbix 让你在 iPhone 上优雅地管理远程 qBittorrent 服务器：实时查看下载/做种、管理任务、查看详情、监控服务器状态，并支持联网搜种与 OTA 更新。

---

## ✨ 功能

- **多服务器管理**：添加 / 切换 / 编辑 / 删除多个 qBittorrent 服务器
- **任务列表**：实时进度、状态、上下行速度、分享率、ETA；按「全部 / 下载中 / 做种中 / 活动中 / 已暂停 / 已完成」筛选
- **任务详情**：进度、传输统计、保存路径/时间、文件列表；启动 / 暂停 / 强制启动 / 校验 / 重新通告 / 删除
- **添加任务**：支持磁力链接、种子 URL 以及 `.torrent` 文件上传；可指定分类 / 标签 / 保存路径
- **统计仪表盘**：实时速度、会话与累计传输量、全局分享率、磁盘剩余、连接状态、DHT 节点、任务概览
- **联网搜种**：通过 141ppv.com 爬虫搜索种子，点按即可加入下载
- **日文→中文翻译**：查看搜索详情时自动翻译简介
- **应用锁**：支持 Face ID 生物识别，后台 8 秒自动锁定
- **OTA 更新**：通过 GitHub Releases 检测更新并下载安装
- **深色模式**：全局深色设计

## 📱 环境要求

- iOS 17.0+
- 一台可访问的 **qBittorrent** 服务器，且已开启 **Web UI**
- [TrollStore](https://github.com/opa334/TrollStore)（安装未签名 .ipa）

## 🧱 技术栈

- **Swift 5.9** + **SwiftUI**
- **UIKit**（UIDocumentPicker, UIActivityViewController 等）
- **URLSession** `async/await` — 网络请求
- **UserDefaults** — 本地持久化
- **LocalAuthentication** — Face ID 生物识别
- **XcodeGen** — 项目文件生成

## 🚀 构建与安装

### GitHub Actions（推荐）

每次推送到 `master` 或手动触发 workflow，自动在 macOS runner 上构建**未签名** `.ipa`：

1. 打开仓库 [Actions](https://github.com/ac54u/Orbix/actions) 页面
2. 点击最新成功的 `Build Orbix IPA` workflow
3. 在 Artifacts 中下载 `Orbix-Unsigned-IPA.zip`
4. 解压得到 `Orbix.ipa`
5. 用 TrollStore 打开安装

### 打 Release

```bash
git tag v1.1.0
git push --tags
```

Actions 自动构建并发布到 GitHub Releases。

## 📂 项目结构

```
ios/Orbix/
├── OrbixApp.swift              # App 入口
├── ContentView.swift           # 根导航
├── Info.plist
├── Theme/
│   ├── AppColors.swift         # 12 个颜色 token
│   ├── AppTypography.swift     # 8 个字体 token
│   └── AppMotion.swift         # 动画曲线与时长
├── Models/
│   ├── ServerConfig.swift      # 服务器配置
│   ├── TorrentInfo.swift       # 种子 / 传输 / 文件模型
│   ├── ScrapedTorrent.swift    # 搜索结果模型
│   └── AppRelease.swift        # GitHub Release 模型
├── Services/
│   ├── QBitApi.swift           # qBittorrent Web API v2 客户端
│   ├── AppLockService.swift    # Face ID 应用锁
│   ├── PersistenceService.swift # UserDefaults 持久化
│   ├── TorrentSearchService.swift # 141ppv.com 爬虫
│   ├── TranslateService.swift  # Google Translate 日→中
│   └── UpdateService.swift     # GitHub OTA 更新
├── Views/
│   ├── SplashView.swift        # 启动决策页
│   ├── WelcomeView.swift       # 首次欢迎页
│   ├── ServerSelectionView.swift # 服务器选择
│   ├── LoginView.swift         # 添加/编辑服务器表单
│   ├── ServerManagementView.swift # 服务器管理
│   ├── MainTabView.swift       # 4 Tab 主界面
│   ├── TorrentListView.swift   # 种子列表 + 过滤
│   ├── TorrentDetailView.swift # 种子详情
│   ├── AddTorrentView.swift    # 添加种子
│   ├── StatsView.swift         # 统计仪表盘
│   ├── SearchView.swift        # 联网搜种
│   └── SettingsView.swift      # 设置 + OTA 更新
└── Components/
    ├── GlowingLogo.swift       # 发光 Logo
    ├── ProgressBar.swift       # 进度条
    ├── SkeletonBar.swift       # 骨架屏
    ├── ToastView.swift         # HUD 提示
    ├── ConnectingDialog.swift  # 连接对话框
    └── MediaViewer.swift       # 图片浏览器
```

## ⚙️ 配置说明

- 如需自定义 GitHub 仓库地址，修改 `Services/UpdateService.swift` 中的 `repo` 属性
- 所有颜色 / 字体 / 动画 token 集中在 `Theme/` 目录下
- 应用通过 qBittorrent Web API v2 通信；CSRF 请求自动附带 `Referer` / `Origin` 头

## 📌 版本

当前版本：**v1.0.9**（SwiftUI 重写版）

---

仅供个人学习与自用，请遵守当地法律法规合理使用。
