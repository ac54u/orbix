import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 统一的「连接中」遮罩：磨砂玻璃质感 + 渐入缩放动画，随系统明暗自适应。
/// 用 rootNavigator 弹出，关闭时 `Navigator.of(context, rootNavigator: true).pop()`。
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
    AppColors.watch(context); // 随明暗即时重建
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final surface = (dark ? const Color(0xFF1C1C1E) : Colors.white);

    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
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
                color: surface.withOpacity(dark ? 0.62 : 0.80),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(dark ? 0.10 : 0.55),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(dark ? 0.45 : 0.18),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.of(AppColors.secondaryLabel),
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
