import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// 语义化动态配色：跟随系统明暗自动解析。
///
/// 只覆盖会随明暗「翻车」的结构色——背景 / 卡片表面 / 文字 / 分隔线 /
/// 占位灰 / 浅强调底。强调色与状态色（蓝/绿/红/橙）、品牌渐变、低透明度
/// 黑色阴影在明暗下都可读，保持原值不动，以降低改动面与风险。
///
/// 用法：`AppColors.of(AppColors.card)`，在 build 期间解析当前界面亮度。
class AppColors {
  AppColors._();

  // —— 背景 ——
  static const groupedBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFF2F2F7), darkColor: Color(0xFF000000));
  static const mainBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFF4F5F9), darkColor: Color(0xFF000000));
  static const plainBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFFFFFF), darkColor: Color(0xFF000000));

  // —— 卡片 / 控件表面 ——
  static const card = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFFFFFF), darkColor: Color(0xFF1C1C1E));

  // —— 文字 ——
  static const label = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF1C1C1E), darkColor: Color(0xFFFFFFFF));
  static const secondaryLabel = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF6E6E73), darkColor: Color(0xFFAEAEB2));

  // —— 分隔线 / 进度槽 ——
  static const separator = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFE5E5EA), darkColor: Color(0xFF38383A));

  // —— 占位 / 失效灰 ——
  static const placeholder = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFC7C7CC), darkColor: Color(0xFF48484A));

  // —— 浅强调底（选中项底 / 图标圆底）——
  static const accentSoftBg = CupertinoDynamicColor.withBrightness(
      color: Color(0xFFE5F0FF), darkColor: Color(0xFF0A2A4D));

  /// 用当前界面亮度解析动态色；无 context（极早期）时回退到浅色值。
  static Color of(CupertinoDynamicColor c) {
    final ctx = Get.context;
    return ctx != null ? CupertinoDynamicColor.resolve(c, ctx) : c.color;
  }
}
