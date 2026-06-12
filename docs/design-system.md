# Orbix Design System

> 「特斯拉 iOS App」式的极致克制、沉浸、原生（iOS HIG）。Dark Mode Only。
> 用字重而非字号撑层级，用空间而非分隔线划分组，用语义色而非字面量定义状态。

---

## 0. 设计哲学

### Tesla iOS 风的四条铁律

1. **纯黑虚空** —— Scaffold 永远 `#000000`，OLED 像素直接熄灭。组件漂浮其上。
2. **去装饰化** —— 禁用阴影、渐变填充、色块徽章。色彩只在状态信息里出现。
3. **字重撑层级** —— 不靠堆字号；用 `w200 / w400 / w600 / w700` 拉对比。
4. **数据如仪表** —— 关键数字给仪表盘式 Hero 位（超大超细 + tabular figures）。

### 不能做的事（anti-patterns）

| 禁 | 理由 |
|---|---|
| `Card / ElevatedButton / FloatingActionButton` | Material elevation 系语言，与 iOS 不匹配 |
| `withOpacity()` | 已弃用，永远用 `withValues(alpha:)` |
| `Color(0xFF...)` 状态色字面量 | 失去 dark/light 通道自适应；用 `CupertinoColors.systemX` |
| `Colors.X` / `package:flutter/material.dart` | 全栈 Cupertino-only；服务层例外（debugPrint） |
| 内联 `TextStyle(fontSize: ...)` | 用 `AppTypography` 8 个 token |
| 色块 chip 状态徽章 | 改纯彩色文本或裸 Cupertino 图标 |
| 粗 6pt 圆角进度条 | 一律 2pt 极细方端 |
| 大圆角独立浮卡 × N | 整组 inset grouped，只有外层有圆角 |

---

## 1. Color Tokens (`lib/theme/app_colors.dart`)

### 1.1 结构色（语义）

| Token | 值 | 用途 |
|---|---|---|
| `AppColors.groupedBg` | `#000000` | Scaffold / 大背景 / CupertinoListSection 外区 |
| `AppColors.mainBg` | `#000000` | main_screen 根背景 |
| `AppColors.plainBg` | `#000000` | splash / welcome / server-selection 根背景 |
| `AppColors.card` | `#1C1C1E` | inset 卡 / 列表组面 / toast 底 / connecting dialog 底 |
| `AppColors.label` | `#FFFFFF` | 主标题、活动行名称、Hero 数字默认 |
| `AppColors.secondaryLabel` | `#AEAEB2` | 副标题、subtitle、捕获灰 |
| `AppColors.tertiaryLabel` | `#6E6E73` | 次要数据 / 极弱化 / 元信息 dot 分隔符 |
| `AppColors.separator` | `#38383A` | 0.5pt hairline / 2pt 进度线底色 |
| `AppColors.placeholder` | `#48484A` | 占位 / 失效灰 / 抓手 / 空态图标 |
| `AppColors.accentSoftBg` | `#0A2A4D` | 浅强调底（已废弃；新页面**勿用**色块底） |

### 1.2 骨架屏色

| Token | 值 | 用途 |
|---|---|---|
| `AppColors.skeletonBase` | `#2A2A2C` | 比 card #1C1C1E 略亮，呼吸最低点 |
| `AppColors.skeletonHighlight` | `#3A3A3C` | 呼吸最高点 |

### 1.3 调用约定

```dart
// 普通调用：当前 build 上下文里解析
AppColors.of(AppColors.card)

// 用于明暗切换时主动重建：build() 顶部
AppColors.watch(context);
```

### 1.4 系统语义色（直接用 Cupertino）

不要重新包装。直接用：

| 用途 | Token |
|---|---|
| 强调色 / CTA / 链接 | `CupertinoColors.systemBlue` |
| 成功 / 做种中 / HTTPS 锁 | `CupertinoColors.systemGreen` |
| 警告 / 校验中 / 分享率 ≥ 1.0 | `CupertinoColors.systemOrange` |
| 错误 / 删除 | `CupertinoColors.systemRed` |
| 下载中（次蓝） | `Color(0xFF5AC8FA)` —— 仅 stats 任务概览，无 token |

需要更精确的 dark 通道时（如 dark 下 systemBlue 是 #0A84FF，浅是 #007AFF）：

```dart
final accent = CupertinoColors.systemBlue.resolveFrom(context);
```

---

## 2. Typography Tokens (`lib/theme/app_typography.dart`)

8 个 token。所有方法接 `color?` 参数，默认从 `AppColors` 解析。

| Token | size | weight | letterSpacing | 用途 | 关键调用点 |
|---|---|---|---|---|---|
| `hero()` | 56 | w200 | -1.5 | 仪表盘 Hero 数字（**自动启用 tabular figures**） | stats Hero 总速 / detail Hero 百分比 |
| `navTitle()` | 17 | w600 | — | `CupertinoNavigationBar.middle` 中间标题 | 5 处 nav bar |
| `largeTitle()` | 34 | w700 | -0.5 | 页面顶部 large title | "种子" / "统计" / "搜索" / "设置" / "Orbix" |
| `cardTitle()` | 22 | w700 | -0.4 | 实体名称 / 入口 tile 大标题 | 服务器名（设置卡）/ splash "Orbix" |
| `sectionHeader()` | 13 | w400 | 0.0 | inset grouped section 上方小灰字头 | 所有 section header |
| `body()` | 17 | w400 | — | 列表 tile 主文字 / 一般文本 | 几乎所有正文 |
| `subtitle()` | 15 | w400 | — | 列表 tile additionalInfo / 副标题 | 大量 tile 右侧值 / 副信息 |
| `caption()` | 12 | w500 | — | 状态文本 / 极小辅助 / 元信息内联 | 状态彩文 / 速度脚注 / 时间戳 |

### 关键铁律

1. **能用 token 就不要内联 `TextStyle()`**。
2. **同号不同重比不同号同重更"苹果"**。一个 17pt 段落，标题 w600 + 正文 w400 比 22pt + 15pt 更克制。
3. **不要堆叠 `.copyWith(fontSize: ...)` 改字号**。如果发现重复模式（如 nav title），抽 token。
4. **数字数据用 `hero()` 或显式 `fontFeatures: [FontFeature.tabularFigures()]`** 避免抖动。

---

## 3. Motion Tokens (`lib/theme/app_motion.dart`)

```dart
class AppMotion {
  static const Cubic standard = Cubic(0.2, 0.8, 0.2, 1.0);

  static const Duration fast = Duration(milliseconds: 220);     // 按钮反馈、tab 下划线
  static const Duration medium = Duration(milliseconds: 350);   // AnimatedSize、modal 出现
  static const Duration slow = Duration(milliseconds: 450);     // 大区块展开 / 转场
  static const Duration skeleton = Duration(milliseconds: 1400); // 骨架屏呼吸周期
}
```

### 使用约定

| 场景 | 用什么 |
|---|---|
| 视觉切换（tab 下划线、segmented、AnimatedContainer） | `AppMotion.fast` + `AppMotion.standard` |
| 折叠 / 展开（AnimatedSize 速度卡） | `AppMotion.medium` + `AppMotion.standard` |
| 弹层 / 全屏过渡 | Cupertino 系统默认，无需手动指定 |
| 骨架屏 | `AppMotion.skeleton` + `Curves.easeInOut`（对称呼吸需要） |
| 业务延时（连接遮罩最小展示时间） | 直接 `Duration(milliseconds: 600/700)`，**不**走 AppMotion |

### 反例

- ❌ `Duration(milliseconds: 200)` —— 用 `AppMotion.fast`
- ❌ `Curves.easeOut` —— 用 `AppMotion.standard`
- ❌ `Curves.bounceOut` —— Tesla 风从不弹簧

---

## 4. Spacing & Layout

### 4.1 水平边距

| 上下文 | 左边距 | 备注 |
|---|---|---|
| 页面 large title | **20pt** | "种子" / "统计" / "设置" 等 |
| inset 卡容器（自绘） | **16pt** | margin: `EdgeInsets.symmetric(horizontal: 16)` |
| `CupertinoListSection.insetGrouped` | 系统默认（约 16pt 外 / 36pt 内对齐） | 不要手动覆盖 |
| section header（自绘，跨容器对齐） | **36pt** 左 | 对齐到 inset 卡内容起点 |

### 4.2 垂直节奏

| 间距 | 用途 |
|---|---|
| **6pt / 8pt** | 行内紧凑（标题与 subtitle 之间，icon 与 label 之间） |
| **10pt / 12pt** | tile 内主行间距 |
| **14pt / 16pt** | 模块间小停顿 |
| **18pt / 22pt** | Hero 区元素间 |
| **24pt / 32pt** | section 间 / Hero 上下 padding |

**不**强求 4pt grid —— iOS HIG 本身允许 6/14/18/22 等非倍数值。

### 4.3 进度线尺寸

```dart
SizedBox(
  height: 2,  // ←  全 App 三处进度线统一 2pt
  child: Stack(
    children: [
      Container(color: AppColors.of(AppColors.separator)),
      FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(color: themeColor),
      ),
    ],
  ),
)
```

- 高度 **永远 2pt**
- **方端无圆头**（不要套 ClipRRect）
- 底色 separator `#38383A`，填充 themeColor

### 4.4 圆角值

| 用途 | 半径 |
|---|---|
| inset 卡容器 | **10pt** |
| CTA `CupertinoButton.filled` | **14pt** |
| Toast 胶囊 | **22pt** |
| Connecting dialog | **24pt** |
| Sheet 顶部（自定义） | **16pt** |
| Logo 圆（splash/welcome） | 完整圆形 |
| Sheet 抓手 | 3pt（5×36 灰色 pill） |

---

## 5. Component Contracts

### 5.1 `CupertinoPageScaffold`

```dart
CupertinoPageScaffold(
  backgroundColor: AppColors.of(AppColors.groupedBg),
  navigationBar: CupertinoNavigationBar(...),  // 见 5.2
  child: SafeArea(top: false, child: ...),
)
```

### 5.2 `CupertinoNavigationBar`

**5 处统一模板**：

```dart
CupertinoNavigationBar(
  backgroundColor: AppColors.of(AppColors.groupedBg).withValues(alpha: 0.85),
  border: Border(
    bottom: BorderSide(
      color: AppColors.of(AppColors.separator),
      width: 0.0,  // 让系统按设备像素绘 hairline
    ),
  ),
  previousPageTitle: '父页名',  // 替代默认 chevron
  middle: Text('标题', style: AppTypography.navTitle()),
  trailing: CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,  // 紧贴右上角，去掉默认 44pt 触控空心
    onPressed: ...,
    child: const Icon(CupertinoIcons.X, color: CupertinoColors.systemBlue, size: 22),
  ),
)
```

### 5.3 `CupertinoListSection.insetGrouped`

**首选**用于：键值对信息、设置项、纯文本列表。

```dart
CupertinoListSection.insetGrouped(
  header: Text('SECTION 标题', style: AppTypography.sectionHeader()),
  footer: Text('解释文本', style: AppTypography.caption()),  // 可选
  children: [
    CupertinoListTile(
      title: Text('键', style: AppTypography.body()),
      additionalInfo: Text('值', style: AppTypography.subtitle()),
    ),
    CupertinoListTile.notched(  // 有 leading 图标时用 notched
      leading: Icon(CupertinoIcons.X, color: ..., size: 22),
      title: ...,
      subtitle: ...,
      trailing: const CupertinoListTileChevron(),  // 可点行才加
      onTap: ...,
    ),
  ],
)
```

**何时改用自绘 inset 容器**：行需要 2pt 进度线 / 行需要 Slidable / 默认 hairline 不合适。

```dart
Container(
  margin: const EdgeInsets.symmetric(horizontal: 16),
  decoration: BoxDecoration(
    color: AppColors.of(AppColors.card),
    borderRadius: BorderRadius.circular(10),
  ),
  clipBehavior: Clip.hardEdge,
  child: Column(children: [...]),
)
```

### 5.4 `CupertinoFormSection.insetGrouped` + 文本字段

```dart
CupertinoFormSection.insetGrouped(
  header: Text('服务器信息', style: AppTypography.sectionHeader()),
  children: [
    CupertinoTextFormFieldRow(
      controller: _hostController,
      placeholder: '主机',
      keyboardType: TextInputType.url,
      style: AppTypography.body(),
      placeholderStyle: AppTypography.body(color: AppColors.of(AppColors.placeholder)),
      prefix: Icon(CupertinoIcons.link, color: AppColors.of(AppColors.secondaryLabel), size: 20),
    ),
    // 需要 suffix（如密码眼睛）：CupertinoFormRow + CupertinoTextField.borderless
    CupertinoFormRow(
      prefix: Icon(CupertinoIcons.lock, ..., size: 20),
      child: Row(children: [
        Expanded(child: CupertinoTextField.borderless(...)),
        GestureDetector(child: Icon(CupertinoIcons.eye_fill, ...)),
      ]),
    ),
  ],
)
```

### 5.5 Toast HUD (`lib/widgets/toast.dart`)

替代所有 SnackBar / Get.snackbar。

```dart
Toast.success(context, '已添加');
Toast.error(context, '网络异常');
Toast.show(context, '提示', type: ToastType.neutral);
```

特性：
- 顶部居中浮动胶囊，毛玻璃 sigma 18
- 22pt 圆角 + 0.5pt separator 描边
- `card.withValues(alpha: 0.78)` 半透底
- ~1.6s 自动消失 + 同时只允许一个（新调用顶掉旧的）
- 不可点关闭（`IgnorePointer`）

### 5.6 Skeleton (`lib/widgets/skeleton.dart`)

替代所有数据加载菊花。

```dart
SkeletonBar(width: 100, height: 14)
SkeletonBar(width: 22, height: 22, borderRadius: BorderRadius.all(Radius.circular(11))) // 圆形
```

**用法**：在初始加载状态构造与正式内容**同构**的骨架结构（同样的 section + tile 数量 + 大致宽度），避免数据到达后布局跳变。

### 5.7 Connecting Dialog (`lib/widgets/connecting_dialog.dart`)

连接服务器时的全局状态遮罩。

```dart
showConnectingDialog(context, text: '连接中…');
// 关闭：Navigator.of(context, rootNavigator: true).pop();
```

特性：152×152 圆角磨砂胶囊 + 中心菊花 + 240ms 渐入 scale 0.92→1.0。

### 5.8 Modal popup（sheet）

**禁用** `Get.bottomSheet`（走 Material）。**用** `showCupertinoModalPopup`：

```dart
final result = await showCupertinoModalPopup<bool>(
  context: context,
  builder: (_) => LoginScreen(editServer: s, asSheet: true),
);
```

**键盘适配**：Cupertino modal 不自动避让，sheet 实现侧需要：

```dart
Padding(
  padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
  child: Container(
    height: maxHeight - mq.viewInsets.bottom,
    ...
  ),
)
```

**下拉关闭手势**：Cupertino modal 自身不带，sheet 实现侧需自绘。参考实现见
`lib/screens/login_screen.dart` 的 `_LoginScreenState`：

1. 用 `with SingleTickerProviderStateMixin` + `AnimationController _settle`
2. 维护 `double _dragY = 0`（>=0），用 `Transform.translate(offset: Offset(0, _dragY))` 包裹整个 sheet
3. 只在**抓手 + 头部行**包 `GestureDetector(onVerticalDrag*)` —— **不要**覆盖滚动表单（会与表单自身滚动冲突）
4. 放手判定：速度 > 700px/s **或** 位移 > 120px → settle 到 `screenHeight` + `Get.back()`；否则 settle 回 0
5. settle 用 `Tween<double>.animate(CurvedAnimation(curve: AppMotion.standard))`，时长 `AppMotion.fast`
6. 拖动开始时 `_settle.stop()` + `FocusScope.of(context).unfocus()` —— 主动收键盘

⚠ 该实现目前仅 LoginScreen 用。第二个 sheet 出现时考虑抽 `DraggableSheet` 组件。

---

## 6. Pattern Catalog

### 6.1 Hero 数据区

**Stats Hero（总速度）**：

```
[小灰标签 caption tertiary]
[大数字 hero() label 白]
[单位 subtitle secondary]
[间距 22pt]
[↓ ↑ 细分 caption]
```

**Detail Hero（任务百分比）**：

```
[任务名 body secondary 居中, 多行]
[大数字 hero(color: themeColor)]
[状态行 icon + subtitle(themeColor)]
[2pt 极细进度线]
[↓ ↑ 速度脚注 caption]
```

### 6.2 元信息内联 dot 分隔

主屏种子行 / search 联网行 / Toast 等位置都用此模式：

```dart
final dotStyle = AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel));
final spans = <InlineSpan>[];
void addSpan(String text, {Color? color}) {
  if (spans.isNotEmpty) spans.add(TextSpan(text: '  ·  ', style: dotStyle));
  spans.add(TextSpan(text: text, style: AppTypography.caption(color: color)));
}
addSpan('下载中', color: CupertinoColors.systemBlue);
addSpan('↓ 1.2 MB/s');
addSpan('42%');
// → Text.rich(TextSpan(children: spans), maxLines: 1, overflow: ellipsis)
```

**dot 字符是 `'  ·  '`（两空格 + 中点 + 两空格）**，颜色 tertiaryLabel。

### 6.3 状态文本 + 裸图标（取代 chip）

**禁** `Container(decoration: bg color chip)` 包文字。**用**：

```dart
// 文本：直接彩色字
Text('已完成', style: AppTypography.caption(color: AppColors.of(AppColors.secondaryLabel)))

// 图标：裸 Cupertino icon
Icon(CupertinoIcons.pause_circle_fill, color: AppColors.of(AppColors.secondaryLabel), size: 22)
```

### 6.4 分段控件

**禁** 自绘 GestureDetector + Container chip。**用**：

```dart
CupertinoSlidingSegmentedControl<int>(
  groupValue: _index,
  children: { 0: _label('A'), 1: _label('B') },
  onValueChanged: (v) => setState(() => _index = v ?? 0),
)

Widget _label(String t) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(t, style: AppTypography.body().copyWith(fontSize: 14)),
);
```

### 6.5 下划线 tab（多选项滚动场景）

当 segmented 装不下 6+ 项时（main_screen 筛选）：

```dart
ListView.separated(  // 横向滚
  scrollDirection: Axis.horizontal,
  ...
  itemBuilder: (_, i) => GestureDetector(
    onTap: () => setState(() => _filter = key),
    child: Column(children: [
      Text(label, style: AppTypography.subtitle(color: ...).copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: -0.1,
      )),
      const SizedBox(height: 6),
      AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: 1.5,
        width: selected ? 24 : 0,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBlue,
          borderRadius: BorderRadius.all(Radius.circular(1)),
        ),
      ),
    ]),
  ),
)
```

### 6.6 拉刷新

```dart
CustomScrollView(
  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  slivers: [
    CupertinoSliverRefreshControl(onRefresh: _fetchData),
    SliverToBoxAdapter(child: _content()),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ],
)
```

**禁** Material `RefreshIndicator`。

### 6.7 空态

居中、克制、无大色块：

```dart
Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.tray, size: 40, color: AppColors.of(AppColors.placeholder)),
        const SizedBox(height: 14),
        Text(
          '暂无内容',
          textAlign: TextAlign.center,
          style: AppTypography.subtitle(color: AppColors.of(AppColors.tertiaryLabel)),
        ),
      ],
    ),
  ),
)
```

---

## 7. Page Contracts

下表 = 各页期望布局的速查。**修改任意页时必读对应行**。

| 页面 | 顶部 | 主体 | 关键 token |
|---|---|---|---|
| **splash** | logo 88pt + 柔光 35% + cloud_download_fill | "Orbix" cardTitle + 菊花 | `cardTitle / accent.withValues(0.35)` |
| **welcome** | logo 88pt + 柔光 40% | largeTitle + 1 个 inset section 3 行 feature + CTA filled(14pt) | `largeTitle / sectionHeader / body / subtitle` |
| **server-selection** | logo 84pt arrow_down + 柔光 45% | largeTitle + 1 个 inset section（cloud_fill leading 24pt + chevron）+ 底部 settings 文本按钮 | `largeTitle / body / caption / sectionHeader` |
| **server-management** | CupertinoNavigationBar + previousPageTitle '设置' | **单 inset 容器** + Slidable 行（连接/编辑/删除）+ 0.5pt 左缩 hairline | `navTitle / body / caption` + Slidable 系统色 |
| **login（整页）** | CupertinoNavigationBar 取消/标题/保存 | 4 个 `CupertinoFormSection.insetGrouped`：服务器/认证/HTTPS/测试 | `navTitle / body / caption / subtitle` |
| **login（sheet）** | 抓手 5×36 + 取消/标题/保存 + 0.5pt hairline | 同上 `_formBody()` 共用 | 同上 |
| **main-screen 顶栏** | "种子" largeTitle + 裸 add icon + 下划线 6 tab + 行内速度 | — | `largeTitle / subtitle / caption` |
| **main-screen 列表** | — | 单 inset 容器 + 行 = 22pt icon + 名 w600 + 元信息 dot + 2pt 进度 | `body.copyWith(w600) / caption` |
| **main-screen Tab Bar** | — | DecoratedBox top BorderSide 0.5pt + SafeArea bottom + 4 tab(icon + 10pt label) | 10pt 自定义 + systemBlue / secondaryLabel |
| **stats** | "统计" largeTitle | Hero 区（标签 + 56pt w200 数字 + 单位 + ↓↑ 脚注）+ 4 inset section | `hero / caption / subtitle / body / sectionHeader` |
| **search** | "搜索" largeTitle + SlidingSegmentedControl + SearchTextField | 本地/联网 切换：CupertinoListSection + tile（双行 subtitle 含内联 ↑↓） | `largeTitle / body.copyWith(w600) / caption` |
| **add-torrent** | CupertinoNavigationBar 取消/标题/添加(active) | SlidingSegmentedControl + 1 个 inset section（链接/文件）+ 1 个可选 form section | `navTitle / body / subtitle / caption` |
| **torrent-detail nav** | CupertinoNavigationBar + previousPageTitle '种子' + 红色 delete | — | `navTitle` + systemRed |
| **torrent-detail Hero** | — | 名 secondary + Hero 百分比 themeColor + 状态行 + 2pt 进度 + ↓↑ | `hero(color: themeColor) / subtitle / caption` |
| **torrent-detail 操作** | — | 4 个裸 CupertinoButton 横排 | `caption` + systemX |
| **torrent-detail 信息** | — | 3 inset section（传输/信息/文件）+ Menlo 等宽长字段 + 文件行 2pt 进度 | `body / subtitle / caption` + `fontFamily: 'Menlo'` |
| **Toast** | — | 顶部居中胶囊 22pt 圆角 + 毛玻璃 + icon + 文字 | `body.copyWith(fontSize: 14, w500)` |
| **Connecting Dialog** | — | 152×152 圆角磨玻璃 + 菊花 + subtitle 文字 | `subtitle.copyWith(w600, letterSpacing 0.3)` |

---

## 8. 文件地图

```
lib/
├── main.dart                    # GetCupertinoApp + CupertinoThemeData(brightness: dark)
├── theme/
│   ├── app_colors.dart          # 11 色 token + skeleton 色
│   ├── app_typography.dart      # 8 typography token
│   └── app_motion.dart          # 1 曲线 + 4 时长
├── widgets/
│   ├── toast.dart               # Cupertino HUD
│   ├── skeleton.dart            # 骨架屏 widget
│   └── connecting_dialog.dart   # 全局连接遮罩
├── screens/                     # 10 个 Cupertino-only 页面
│   ├── splash_screen.dart
│   ├── welcome_screen.dart
│   ├── server_selection_screen.dart
│   ├── server_management_screen.dart
│   ├── login_screen.dart        # 整页 + sheet 共用 _formBody
│   ├── main_screen.dart         # 顶栏 + 4 tab + ServerSettingsPage 私有 class
│   ├── stats_screen.dart
│   ├── search_screen.dart
│   ├── add_torrent_screen.dart
│   └── torrent_detail_screen.dart
└── services/
    └── qbit_api.dart            # 唯一非 Cupertino 的层（service 层）
```

---

## 9. 新页面的 checklist

加新页面 / 改既有页面前，对照下列：

- [ ] `import 'package:flutter/cupertino.dart';` —— 不要 import material
- [ ] 用 `CupertinoPageScaffold`，不要 `Scaffold`
- [ ] 用 `CupertinoNavigationBar`（按 5.2 模板），不要 `AppBar`
- [ ] 所有 `Text` 走 `AppTypography.X()`，不内联 `TextStyle(fontSize:)`
- [ ] 颜色走 `AppColors.of()` 或 `CupertinoColors.systemX`，不字面量
- [ ] 列表用 `CupertinoListSection.insetGrouped` 或自绘 inset 容器（borderRadius 10pt）
- [ ] 文本输入用 `CupertinoFormSection + CupertinoTextFormFieldRow`，不 Material `TextField`
- [ ] 拉刷新用 `CupertinoSliverRefreshControl`，不 Material `RefreshIndicator`
- [ ] 加载用 `SkeletonBar`，不菊花 `CircularProgressIndicator`
- [ ] 通知用 `Toast.success/error()`，不 `Get.snackbar` / `SnackBar`
- [ ] 半屏弹层用 `showCupertinoModalPopup`，不 `Get.bottomSheet`
- [ ] 进度条永远 2pt + 方端
- [ ] 动效用 `AppMotion.fast/medium/slow` + `AppMotion.standard`，不 `Duration(milliseconds: ...)` 字面量
- [ ] 状态色块 chip → 改纯彩色文本 + 裸 Cupertino 图标
- [ ] 跑 `flutter analyze` 必须 0 issues

---

## 10. 维护规则

1. **加新 token 前先问**：现有 token 能否 cover？真的需要新 token，还是只是 `.copyWith()` 的一次性 override？
2. **token 应有明确语义名**（`hero` / `navTitle`），**不**用尺寸名（`fontSize56`）。
3. **改 token 数值**会影响全 App，需经过设计 review。
4. **删 token** 前 grep 确认无引用。
5. 任何"复制粘贴 3 次以上的 widget tree"应抽公共组件或 token。
