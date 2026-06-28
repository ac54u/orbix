# Orbix 项目状态盘点 (Project Audit)

> 审计日期：2026-06-28 · 版本 v1.0.10

---

## 一、App 主界面

| Tab | 文件 | 功能 |
|-----|------|------|
| 种子 | `Views/TorrentListView.swift` | 种子列表 + 6 种筛选 + 滑动删除 + 全局速度浮标 + 全局控制面板 |
| 传输 | `Views/StatsView.swift` | 实时速度 / 传输量 / 连接 / 磁盘 / 概览计数 |
| 搜索 | `Views/SearchView.swift` + `Views/QBitSearchView.swift` | 141ppv 网页搜刮 + 多源搜索（qB/Prowlarr/Radarr） |
| 设置 | `Views/SettingsView.swift` | 服务器信息 / Face ID / OTA 更新 |

- 默认进入搜索 Tab，连续点击搜索 Tab 3 次触发开发者模式彩蛋
- 长按桌面图标 → "搜索"快捷操作

---

## 二、所有 View 清单

| # | 文件 | 用途 |
|---|------|------|
| 1 | `SplashView.swift` | 启动动画，决策导航目标 |
| 2 | `WelcomeView.swift` | 首次引导页 |
| 3 | `LoginView.swift` | 服务器配置表单 |
| 4 | `ServerSelectionView.swift` | 服务器选择列表 |
| 5 | `ServerManagementView.swift` | 服务器编辑/删除管理 |
| 6 | `MainTabView.swift` | 4 Tab 根导航 |
| 7 | `TorrentListView.swift` | 种子列表 + 全局控制 |
| 8 | `TorrentDetailView.swift` | 种子详情（14 个区域） |
| 9 | `StatsView.swift` | 传输统计仪表盘 |
| 10 | `SearchView.swift` | 141ppv 照片墙搜索 |
| 11 | `QBitSearchView.swift` | 多源聚合搜索 |
| 12 | `AddTorrentView.swift` | 添加种子 |
| 13 | `SettingsView.swift` | 应用设置 |
| 14 | `ContentView.swift` | 根容器 + 深度链接 |

---

## 三、种子详情页 — 完整功能

`TorrentDetailView.swift` 包含 14 个区域：

1. **仪表盘** — 名称 / 进度% / 状态 / 速度 / 进度条
2. **错误提示** — 红色告警框
3. **操作按钮** — 暂停/启动 / 强制 / 校验 / 汇报
4. **传输统计** — DL/UL 速度 / 已下载/上传 / 分享率 / ETA / 种子/吸血数
5. **属性信息** — 总大小 / 保存路径 / 分类 / 标签 / Hash
6. **添加时间** — 添加时间 + 完成时间
7. **文件列表** — 文件名 / 大小 / 进度% / 进度条 → "管理"按钮
8. **Trackers** — 状态 / 种子数·下载数 / URL → "管理"按钮
9. **Peers** — IP:端口 / 国家 / 上传速度 / 进度%
10. **高级控制 Sheet** — 修改路径 / 重命名 / 单种子限速 / 顺序下载
11. **文件优先级 Sheet** — 多选批量设优先级（忽略/正常/高/最高）
12. **Tracker 管理 Sheet** — 添加/删除 Tracker URL
13. **删除确认** — 仅删任务 / 删任务+文件
14. **2 秒自动刷新** — 拉取 torrent + properties + files + trackers + peers

---

## 四、半屏弹窗汇总

| 弹窗 | 触发位置 | 功能 |
|------|----------|------|
| 下载弹窗 | QBitSearchView (qB/Prowlarr) | 分类选择 + 保存路径 → addMagnet |
| Radarr 添加弹窗 | QBitSearchView (Radarr) | 海报 + 质量配置 + 根目录 + 自动搜刮 → addMovie |
| 全局控制面板 | TorrentListView 工具栏 | 乌龟模式开关 + 全局限速 |
| 高级微操面板 | TorrentDetailView 工具栏 | 路径/重命名/限速/顺序下载 |
| 文件优先级 | TorrentDetailView 文件区 | 批量选择 + 菜单设优先级 |
| Tracker 管理 | TorrentDetailView Tracker 区 | 添加/删除 Tracker |

---

## 五、API 封装 — QBitApi（actor，36 个方法）

### 认证 & 服务器管理
| 方法 | 端点 |
|------|------|
| `connect()` | POST `/auth/login` |
| `loadServers()` / `upsertServer()` / `removeServer()` | 本地 |

### 种子 CRUD
| 方法 | 端点 |
|------|------|
| `getTorrents()` | GET `/torrents/info` |
| `getTorrentByHash(_:)` | GET `/torrents/info?hashes=` |
| `getProperties(_:)` | GET `/torrents/properties?hash=` |
| `getTorrentFiles(_:)` | GET `/torrents/files?hash=` |
| `getTorrentTrackers(_:)` | GET `/torrents/trackers?hash=` |
| `getTorrentPeers(_:)` | GET `/sync/torrentPeers?hash=` |
| `getCategories()` | GET `/torrents/categories` |
| `syncMainData(rid:)` | GET `/sync/maindata?rid=` |

### 种子操作
| 方法 | 端点 |
|------|------|
| `startTorrent(_:)` | POST `/torrents/start` |
| `stopTorrent(_:)` | POST `/torrents/stop` |
| `forceStartTorrent(_:)` | POST `/torrents/setForceStart` |
| `recheckTorrent(_:)` | POST `/torrents/recheck` |
| `reannounceTorrent(_:)` | POST `/torrents/reannounce` |
| `deleteTorrent(_:deleteFiles:)` | POST `/torrents/delete` |
| `setTorrentLocation(_:location:)` | POST `/torrents/setLocation` |
| `renameTorrent(_:name:)` | POST `/torrents/rename` |
| `setTorrentDownloadLimit(_:limit:)` | POST `/torrents/setDownloadLimit` |
| `setTorrentUploadLimit(_:limit:)` | POST `/torrents/setUploadLimit` |
| `toggleSequentialDownload(_:)` | POST `/torrents/toggleSequentialDownload` |
| `setFilePriorities(_:indices:priority:)` | POST `/torrents/filePrio` |
| `addTrackers(_:urls:)` | POST `/torrents/addTrackers` |
| `removeTrackers(_:urls:)` | POST `/torrents/removeTrackers` |

### 添加种子
| 方法 | 端点 |
|------|------|
| `addMagnet(_:category:tags:savePath:)` | POST `/torrents/add` |
| `addTorrent(bytes:filename:...)` | POST `/torrents/add` (multipart) |

### 搜索
| 方法 | 端点 |
|------|------|
| `getSearchPlugins()` | GET `/search/plugins` |
| `startSearch(pattern:plugins:category:)` | POST `/search/start` |
| `getSearchStatus(id:)` | GET `/search/status?id=` |
| `getSearchResults(id:limit:offset:)` | GET `/search/results?id=&limit=&offset=` |
| `stopSearch(id:)` | POST `/search/stop` |
| `deleteSearch(id:)` | POST `/search/delete` |

### 偏好 & 限速
| 方法 | 端点 |
|------|------|
| `getPreferences()` | GET `/app/preferences` |
| `setPreferences(_:)` | POST `/app/setPreferences` |
| `setGlobalDownloadLimit(_:)` | → setPreferences |
| `setGlobalUploadLimit(_:)` | → setPreferences |
| `toggleSpeedLimitsMode()` | POST `/transfer/toggleSpeedLimitsMode` |

### 其他
| 方法 | 端点 |
|------|------|
| `getTransferInfo()` | GET `/transfer/info` |
| `getAppVersion()` | GET `/app/version` |

---

## 六、API 封装 — ProwlarrApi / RadarrApi

### ProwlarrApi（enum，2 个方法）
| 方法 | 端点 |
|------|------|
| `search(query:indexerIds:)` | `{apiURL}/api/v1/search?query=...&type=search` |
| `getIndexers()` | `{apiURL}/api/v1/indexer` |

### RadarrApi（enum，5 个方法）
| 方法 | 端点 |
|------|------|
| `lookup(query:)` | `{apiURL}/api/v3/movie/lookup?term=...` |
| `getMovies()` | `{apiURL}/api/v3/movie` |
| `getQualityProfiles()` | `{apiURL}/api/v3/qualityprofile` |
| `getRootFolders()` | `{apiURL}/api/v3/rootfolder` |
| `addMovie(...)` | POST `{apiURL}/api/v3/movie` |

---

## 七、其他 Service

| Service | 类型 | 方法数 |
|---------|------|--------|
| `CredentialsManager` | ObservableObject | `save()` / `remove()` / `credential(for:)` / @Published x3 |
| `PersistenceService` | Singleton | 书签 / 更新缓存 / 应用锁 |
| `AppLockService` | ObservableObject | Face ID 验证 / 锁定 / 生命周期监听 |
| `UpdateService` | actor | `check()` → UpdateCheck / `downloadIpa()` |
| `TranslateService` | actor | `toChinese()` 日→中翻译 |
| `TorrentSearchService` | actor | 141ppv 搜索/翻页/热门 |
| `ImageCache` | Singleton | NSCache 解码图片缓存 |

---

## 八、模型汇总（~25 个）

| 类型 | 文件 |
|------|------|
| TorrentInfo / TorrentStatus / TransferInfo / ServerState | TorrentInfo.swift |
| TorrentProperties / TorrentFile / TorrentTracker / TorrentPeer | TorrentInfo.swift |
| TorrentPeersResponse / SyncMainData / Category / SearchPlugin / SearchResult | TorrentInfo.swift |
| ServerConfig / ConnectStatus / ConnectResult | ServerConfig.swift |
| ScrapedTorrent | ScrapedTorrent.swift |
| AppRelease / UpdateCheck | AppRelease.swift |
| ServiceCredential / ServiceKind | CredentialsManager.swift |
| RadarrMovie / RadarrImage / QualityProfile / RootFolder | RadarrApi.swift |
| ProwlarrSearchResult | ProwlarrApi.swift |

---

## 九、❌ 未集成功能

### Arr 家族
| 服务 | 状态 | 优先级 |
|------|------|--------|
| **Sonarr**（电视剧） | 完全缺失 | 🔴 高 |
| Lidarr（音乐） | 完全缺失 | 🟡 中 |
| Readarr（电子书） | 完全缺失 | 🟢 低 |
| Whisparr（成人） | 完全缺失 | 🟢 低 |
| Bazarr（字幕） | 完全缺失 | 🟡 中 |
| Overseerr / Jellyseerr（请求系统） | 完全缺失 | 🟡 中 |
| Tautulli（监控统计） | 完全缺失 | 🟢 低 |
| SABnzbd / NZBGet（Usenet） | 完全缺失 | 🟢 低 |

### qBittorrent 未集成
| 功能 | 优先级 |
|------|--------|
| 批量操作（多选） | 🔴 高 |
| 排序（按名称/大小/日期/进度/分享率） | 🔴 高 |
| RSS 订阅 + 自动下载规则 | 🟡 中 |
| 分类/标签管理 UI（创建/编辑/删除） | 🟡 中 |
| 队列优先级（上移/下移/置顶/置底） | 🟡 中 |
| 超级做种 / 首尾优先 | 🟢 低 |
| 自动种子管理（分享率达标后删除） | 🟢 低 |
| 种子文件导出 | 🟢 低 |

### App 级别
| 功能 | 优先级 |
|------|--------|
| 推送通知（完成/错误/磁盘不足） | 🟡 中 |
| iPad 适配（侧边栏/分屏） | 🟡 中 |
| 多语言（当前仅中文） | 🟢 低 |
| Siri 快捷指令 / App Intents | 🟢 低 |
| Widget（桌面/锁屏） | 🟢 低 |
| 缓存管理 | 🟢 低 |
| 搜索历史 | 🟢 低 |
| 连接健康监测 / 自动重连 | 🟢 低 |

### 网页搜刮
| 功能 | 优先级 |
|------|--------|
| 多数据源（目前仅 141ppv.com） | 🟡 中 |
| 分类/日期筛选 | 🟢 低 |

---

## 十、总结

Orbix 已是一个成熟的 qBittorrent 远程客户端，种子管理、传输统计、搜索聚合（含 Prowlarr/Radarr）均完备。

App 整体完成度：**~70%**（以完整媒体聚合中心为标准）

**下一阶段建议优先做：**
1. 🔴 Sonarr 电视剧管理集成
2. 🔴 种子批量操作 + 排序
3. 🟡 分类/标签管理 UI
4. 🟡 RSS 订阅
