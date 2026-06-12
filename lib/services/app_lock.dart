import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用锁（iOS 原生 Face ID / 生物识别）。
///
/// 仅负责「开关状态读写 + 设备能力探测 + 触发系统验证」，
/// 具体的锁屏时机（冷启动 / 切回前台）由 [AppLockGate] 控制。
class AppLock {
  AppLock._();
  static final AppLock instance = AppLock._();

  static const String _prefKey = 'app_lock_face_id';

  final LocalAuthentication _auth = LocalAuthentication();

  /// 是否已开启应用锁（用户在设置页的选择）。
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// 写入开关状态。
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// 设备是否支持生物识别 / 设备密码验证（无 Face ID 的设备返回 false 时应禁用开关）。
  Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('AppLock.canAuthenticate 失败: $e');
      return false;
    }
  }

  /// 当前可用的生物识别是否含 Face ID（用于把开关文案写成「Face ID」）。
  Future<bool> hasFaceId() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      return list.contains(BiometricType.face);
    } catch (_) {
      return false;
    }
  }

  /// 触发一次系统验证。成功返回 true。
  /// [biometricOnly] 为 false 时允许 Face ID 失败后回退到设备密码，避免被锁死。
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // 验证期间 App 被切走也不中断
          biometricOnly: false, // 允许回退设备密码
        ),
      );
    } catch (e) {
      debugPrint('AppLock.authenticate 失败: $e');
      return false;
    }
  }
}
