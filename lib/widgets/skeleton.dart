import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// 极简骨架条：在 #1C1C1E 的列表组面上做 #2A2A2C ↔ #3A3A3C 的呼吸闪烁。
///
/// 替代菊花 spinner 作为加载态。多个 SkeletonBar 共享同一节奏，因
/// 各自持有同步起跳的 AnimationController；视觉上保持一致。
class SkeletonBar extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBar({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  });

  @override
  State<SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<SkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.skeleton)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.skeletonBase,
              AppColors.skeletonHighlight,
              Curves.easeInOut.transform(_ctrl.value),
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
