import 'package:flutter/cupertino.dart';

import '../services/app_lock.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 全局引用门控状态，供设置页开关即时同步（无需重启 App）。
final GlobalKey<AppLockGateState> appLockGateKey =
    GlobalKey<AppLockGateState>();

/// 应用锁门：套在整个 App 之上（main 的 builder）。
///
/// 时机（用户在设置页开启后生效）：
///  - 冷启动：进入即锁，弹 Face ID；
///  - 切回前台：离开超过 [_resumeGrace] 才重新锁，避免快速切 App 频繁打扰。
///
/// Face ID 系统弹窗自身会让 App 短暂 inactive/resumed，用 [_authenticating]
/// 作守卫，避免把弹窗引起的生命周期变化误判为「离开/回到前台」造成死循环。
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => AppLockGateState();
}

class AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  static const Duration _resumeGrace = Duration(seconds: 8);

  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;
  DateTime? _bgAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final on = await AppLock.instance.isEnabled();
    if (!mounted || !on) return;
    setState(() {
      _enabled = true;
      _locked = true;
    });
    _promptAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || _authenticating) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _bgAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_locked) {
        // 回到一个已锁的界面：直接再弹一次 Face ID。
        _promptAuth();
        return;
      }
      final bg = _bgAt;
      _bgAt = null;
      if (bg != null && DateTime.now().difference(bg) >= _resumeGrace) {
        setState(() => _locked = true);
        _promptAuth();
      }
    }
  }

  Future<void> _promptAuth() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await AppLock.instance.authenticate('验证身份以解锁 Orbix');
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _locked = false;
    });
  }

  /// 供外部（设置页开关）即时同步状态，省去重启 App。
  void syncEnabled(bool value) {
    if (!mounted) return;
    setState(() {
      _enabled = value;
      if (!value) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              authenticating: _authenticating,
              onUnlock: _promptAuth,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool authenticating;
  final VoidCallback onUnlock;
  const _LockScreen({required this.authenticating, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent.resolveFrom(context);
    return ColoredBox(
      color: AppColors.of(AppColors.plainBg),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF366EF6), Color(0xFF0E52BA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.lock_fill,
                  color: CupertinoColors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              Text('Orbix 已锁定', style: AppTypography.cardTitle()),
              const SizedBox(height: 8),
              Text('需要验证身份后才能继续',
                  style: AppTypography.subtitle()),
              const SizedBox(height: 36),
              if (authenticating)
                const CupertinoActivityIndicator(radius: 12)
              else
                CupertinoButton.filled(
                  onPressed: onUnlock,
                  child: const Text('用 Face ID 解锁'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
