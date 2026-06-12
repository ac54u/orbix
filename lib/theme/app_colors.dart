import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// 语义化配色：Dark Mode Only，逐像素对齐 Tesla iOS App。
///
/// 全部色值采样自 App Store 官方截图（无损 PNG，2026-06）：
///  - 背景不是纯黑，是 #161718 深灰；
///  - 表面体系 = 白色低透明度叠加：卡片 ≈5% (#1E1F20)，浮起胶囊 ≈7.5% (#282829)；
///  - 强调蓝是 Tesla 蓝 #366EF6（"Discharging" 文字采样），非 iOS systemBlue；
///  - 文字灰全是纯中性灰（#909191），不带 iOS 的蓝偏。
///
/// 保留 `CupertinoDynamicColor` API 是为了不动现有调用点，亮色通道直接
/// 同步为深色值；未来如需恢复明暗双主题，只动这里即可。
///
/// 用法：`AppColors.of(AppColors.card)`，在 build 期间解析。
class AppColors {
  AppColors._();

  // —— 背景 ——
  /// Scaffold 根背景：Tesla 深灰 #161718（采样自首页/列表/弹层，全局一致）。
  static const groupedBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF161718), darkColor: Color(0xFF161718));
  static const mainBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF161718), darkColor: Color(0xFF161718));
  static const plainBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF161718), darkColor: Color(0xFF161718));

  // —— 卡片 / 列表组表面 ——
  /// inset grouped section 内表面：白 5% 叠加 ≈ #1E1F20（Tesla 图表填充同级）。
  static const card = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF1E1F20), darkColor: Color(0xFF1E1F20));

  /// 浮起表面（底部 Tab 胶囊 / 弹出菜单）：#282829，采样自 Tesla 底部 tab bar。
  static const elevated = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF282829), darkColor: Color(0xFF282829));

  // —— 文字 ——
  /// 主文字：#FAFAFA（Tesla 不用纯白）。
  static const label = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFAFAFA), darkColor: Color(0xFFFAFAFA));
  /// 次级文字 / 图标灰：#909191，纯中性，无 iOS 蓝偏。
  static const secondaryLabel = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF909191), darkColor: Color(0xFF909191));
  /// 极弱的三级文字（次要数据：DHT 节点数 / 剩余空间等"背景信息"）。
  static const tertiaryLabel = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF6B6C6D), darkColor: Color(0xFF6B6C6D));

  // —— 分隔线 / 描边（0.5pt hairline）——
  /// #2E2E2F：Tesla 列表 hairline 与 chip 描边同值。
  static const separator = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF2E2E2F), darkColor: Color(0xFF2E2E2F));

  // —— 占位 / 失效灰 ——
  static const placeholder = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF4A4B4C), darkColor: Color(0xFF4A4B4C));

  // —— 强调色 ——
  /// Tesla 蓝：采样自 "Discharging" 文字。替代 iOS systemBlue。
  static const accent = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF366EF6), darkColor: Color(0xFF366EF6));
  /// 深一档的 Tesla 蓝（地图定位按钮采样），用于渐变收尾/按压态。
  static const accentDark = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF0E52BA), darkColor: Color(0xFF0E52BA));
  /// 成功/做种绿：采样自 Solar 发电曲线。
  static const success = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF03B661), darkColor: Color(0xFF03B661));
  /// 警告琥珀：Tesla UI 几乎不用橙；由能量图电网黄线提亮派生，压饱和保持克制。
  static const warning = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFE6A23C), darkColor: Color(0xFFE6A23C));
  /// 错误红：采样自方向盘加热警示框（深底上的 Tesla 亮红）。
  static const danger = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFF5255), darkColor: Color(0xFFFF5255));

  // —— 浅强调底（蓝 tint 表面）——
  /// #1C2438：采样自 Tesla 蓝色图表的半透明填充区。
  static const accentSoftBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF1C2438), darkColor: Color(0xFF1C2438));

  // —— 骨架屏：base/highlight 在 card (#1E1F20) 之上做微妙横移 ——
  static const Color skeletonBase = Color(0xFF242526);
  static const Color skeletonHighlight = Color(0xFF2E2F30);

  /// 用当前界面亮度解析动态色；无 context（极早期）时回退到默认值。
  static Color of(CupertinoDynamicColor c) {
    final ctx = Get.context;
    return ctx != null ? CupertinoDynamicColor.resolve(c, ctx) : c.color;
  }

  /// 在页面 build() 顶部调用：让该页订阅系统明暗变化。
  ///
  /// 锁暗色后此调用本质上是 no-op，保留以兼容既有调用点；如未来恢复
  /// 双主题，无需再补订阅逻辑。
  static void watch(BuildContext context) {
    MediaQuery.platformBrightnessOf(context);
  }
}
