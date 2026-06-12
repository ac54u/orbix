import 'package:flutter/cupertino.dart';
import 'app_colors.dart';

/// SF Pro 字重表：用字重而非字号撑开层级。
///
/// iOS 系统字体默认即 .SF Pro Text / Display，无需 fontFamily。
/// 所有方法接受可选 color，默认 AppColors.label。
class AppTypography {
  AppTypography._();

  /// 仪表盘 Hero 数字：超大、超细。
  ///
  /// 启用 tabular figures，避免实时数字跳变时各位宽度抖动。
  static TextStyle hero({Color? color}) => TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w200,
        height: 1.0,
        letterSpacing: -1.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? AppColors.of(AppColors.label),
      );

  /// `CupertinoNavigationBar` 中间标题：17pt w600，iOS 标准。
  static TextStyle navTitle({Color? color}) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.of(AppColors.label),
      );

  /// 页面顶部 large title（"设置"/"种子"/"统计"）。
  static TextStyle largeTitle({Color? color}) => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color ?? AppColors.of(AppColors.label),
      );

  /// 实体名称 / 列表组内主标题（如服务器名）。
  static TextStyle cardTitle({Color? color}) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color ?? AppColors.of(AppColors.label),
      );

  /// inset grouped section 上方小灰字头。
  static TextStyle sectionHeader({Color? color}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        color: color ?? AppColors.of(AppColors.secondaryLabel),
      );

  /// 列表 tile 主文字。
  static TextStyle body({Color? color}) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.of(AppColors.label),
      );

  /// 列表 tile 右侧 additionalInfo / 副标题。
  static TextStyle subtitle({Color? color}) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.of(AppColors.secondaryLabel),
      );

  /// 极小辅助说明 / 状态文本（torrents 状态文本走这个）。
  static TextStyle caption({Color? color}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.of(AppColors.secondaryLabel),
      );
}
