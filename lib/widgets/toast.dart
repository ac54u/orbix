import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';

/// Toast 类型：决定前缀图标 + 配色。
enum ToastType { neutral, success, error }

/// Cupertino HUD toast：顶部居中、磨砂玻璃、自动消失。
///
/// 通过 `OverlayEntry` 挂在 root overlay 上，**不依赖 `Scaffold`/`ScaffoldMessenger`**。
/// 同时只允许一个 toast 存在，新调用会平滑顶掉旧的。
///
/// 用法：
/// ```dart
/// Toast.success(context, '已添加');
/// Toast.error(context, '网络异常');
/// Toast.show(context, '中性提示');
/// ```
class Toast {
  Toast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.neutral,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    _dismiss();

    final entry = OverlayEntry(
      builder: (_) => _ToastView(message: message, type: type),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, _dismiss);
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: ToastType.error);

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final ToastType type;
  const _ToastView({required this.message, required this.type});

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.medium)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topInset + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) {
              final t = AppMotion.standard.transform(_ctrl.value);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -10 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: _Pill(message: widget.message, type: widget.type),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String message;
  final ToastType type;
  const _Pill({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = _styleFor(type);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color:
                AppColors.of(AppColors.card).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.of(AppColors.separator),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 16),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message,
                  style: AppTypography.body().copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData?, Color) _styleFor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return (
          CupertinoIcons.check_mark_circled_solid,
          AppColors.success,
        );
      case ToastType.error:
        return (
          CupertinoIcons.exclamationmark_circle_fill,
          AppColors.danger,
        );
      case ToastType.neutral:
        return (null, AppColors.of(AppColors.label));
    }
  }
}
