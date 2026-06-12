import 'package:flutter/animation.dart';

/// 全局动效 token：曲线 + 时长。
///
/// 设计原则：比 iOS 默认稍慢一档，让"克制"也有呼吸感。
class AppMotion {
  AppMotion._();

  /// 默认缓动曲线：苹果常用的 expressive curve。
  static const Cubic standard = Cubic(0.2, 0.8, 0.2, 1.0);

  /// 小元素状态切换（按钮反馈、图标变化）。
  static const Duration fast = Duration(milliseconds: 220);

  /// 页面内组件出现 / 消失、分段切换。
  static const Duration medium = Duration(milliseconds: 350);

  /// 大区块展开 / 折叠、模态过渡。
  static const Duration slow = Duration(milliseconds: 450);

  /// 骨架屏闪烁周期（明暗各一次）。
  static const Duration skeleton = Duration(milliseconds: 1400);
}
