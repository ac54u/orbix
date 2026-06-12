import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// 语义化配色：Dark Mode Only。
///
/// 项目自 Tesla 风重构起锁定深色，亮色通道直接同步为深色值——保留
/// `CupertinoDynamicColor` API 是为了不动现有调用点，未来如需恢复明
/// 暗双主题，只动这里即可。
///
/// 用法：`AppColors.of(AppColors.card)`，在 build 期间解析。
class AppColors {
  AppColors._();

  // —— 背景 ——
  /// Scaffold 根背景：纯黑 #000，与 Cupertino 系统 grouped bg 暗值一致。
  static const groupedBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF000000), darkColor: Color(0xFF000000));
  static const mainBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF000000), darkColor: Color(0xFF000000));
  static const plainBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF000000), darkColor: Color(0xFF000000));

  // —— 卡片 / 列表组表面 ——
  /// inset grouped section 内表面：#1C1C1E。
  static const card = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF1C1C1E), darkColor: Color(0xFF1C1C1E));

  // —— 文字 ——
  static const label = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFFFFFF), darkColor: Color(0xFFFFFFFF));
  static const secondaryLabel = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFAEAEB2), darkColor: Color(0xFFAEAEB2));
  /// 极弱的三级文字（次要数据：DHT 节点数 / 剩余空间等"背景信息"）。
  static const tertiaryLabel = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF6E6E73), darkColor: Color(0xFF6E6E73));

  // —— 分隔线（0.5pt hairline，而非粗实线）——
  static const separator = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF38383A), darkColor: Color(0xFF38383A));

  // —— 占位 / 失效灰 ——
  static const placeholder = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF48484A), darkColor: Color(0xFF48484A));

  // —— 浅强调底（兼容旧代码，新页面避免使用色块底）——
  static const accentSoftBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF0A2A4D), darkColor: Color(0xFF0A2A4D));

  // —— 骨架屏：base/highlight 在 card (#1C1C1E) 之上做微妙横移 ——
  static const Color skeletonBase = Color(0xFF2A2A2C);
  static const Color skeletonHighlight = Color(0xFF3A3A3C);

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
