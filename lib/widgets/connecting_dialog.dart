import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';

/// 统一的「连接中」遮罩：磨砂玻璃 + 渐入缩放动画。
///
/// 用 rootNavigator 弹出；关闭：`Navigator.of(context, rootNavigator: true).pop()`。
Future<void> showConnectingDialog(BuildContext context, {String text = '连接中…'}) {
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConnectingDialog(text: text),
  );
}

class _ConnectingDialog extends StatelessWidget {
  final String text;
  const _ConnectingDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: 152,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
              decoration: BoxDecoration(
                color:
                    AppColors.of(AppColors.card).withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: CupertinoColors.white.withValues(alpha: 0.10),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(radius: 16),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: AppTypography.subtitle().copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
