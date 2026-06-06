import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/qbit_api.dart';
import '../main.dart'; // 用于跳转到首页

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // —— 设计令牌（一处定义，全页复用，避免数值漂移）——
  static const Color _ink = Color(0xFF1C1C1E);        // 主文字：近黑带暖调，不用纯黑
  static const Color _inkMuted = Color(0xFF6E6E73);   // 次要文字：比 systemGrey 更深，过 4.5:1 对比
  static const Color _accent = Color(0xFF007AFF);     // 唯一强调色，全页锁定
  static const Color _fieldBg = Colors.white;
  static const Color _hairline = Color(0xFFE5E5EA);   // 分隔线
  static const double _radius = 14.0;                 // 统一圆角刻度

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 聚焦态：用于给输入框绘制聚焦边框
  final FocusNode _urlFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText; // 表单内联错误，替代纯弹窗

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    // 聚焦变化时重绘边框
    for (final node in [_urlFocus, _usernameFocus, _passwordFocus]) {
      node.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // 尝试读取本地保存的账号密码
  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('qbit_url') ?? 'http://';
      _usernameController.text = prefs.getString('qbit_username') ?? 'admin';
      _passwordController.text = prefs.getString('qbit_password') ?? '';
    });
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (url.isEmpty || username.isEmpty) {
      setState(() => _errorText = "服务器地址和用户名不能为空");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    // 1. 设置 API 实例
    final api = QBitApi();
    api.setServer(ServerConfig(url: url, username: username, password: password));

    // 2. 发起登录请求
    bool success = await api.login();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // 3. 登录成功，保存凭据到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qbit_url', url);
      await prefs.setString('qbit_username', username);
      await prefs.setString('qbit_password', password);

      // 4. 跳转到首页，并销毁登录页防止返回
      Get.offAll(() => const MainScreen());
    } else {
      setState(() => _errorText = "连接失败，请检查地址或账号密码是否正确");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS 分组背景
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrand(),
                  const SizedBox(height: 36),
                  _buildForm(),
                  // 内联错误：有内容时才占位，平滑展开
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _errorText == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.exclamationmark_circle_fill,
                                    color: CupertinoColors.systemRed, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorText!,
                                    style: const TextStyle(
                                        color: CupertinoColors.systemRed,
                                        fontSize: 13,
                                        height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // —— 品牌区：单一 logo，做出层次与同色调投影，而非扁平蓝方块 ——
  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A84FF), Color(0xFF0060DF)],
            ),
            borderRadius: BorderRadius.circular(_radius + 6),
            boxShadow: [
              // 投影染成强调色，而非纯黑，制造发光浮起感
              BoxShadow(
                color: _accent.withOpacity(0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(CupertinoIcons.cloud_download_fill,
              color: Colors.white, size: 38),
        ),
        const SizedBox(height: 22),
        const Text(
          "连接到 Orbix",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.5, // 大字号收紧字距，更精致
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "填写你的 qBittorrent 服务器信息",
          style: TextStyle(color: _inkMuted, fontSize: 15, height: 1.3),
        ),
      ],
    );
  }

  // —— 表单卡片：iOS 分组样式，聚焦时高亮所在行 ——
  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildField(
            controller: _urlController,
            focusNode: _urlFocus,
            icon: CupertinoIcons.link,
            placeholder: "服务器地址，例：http://192.168.1.2:8080",
            keyboardType: TextInputType.url,
            showDivider: true,
          ),
          _buildField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            icon: CupertinoIcons.person_fill,
            placeholder: "用户名",
            showDivider: true,
          ),
          _buildField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            icon: CupertinoIcons.lock_fill,
            placeholder: "密码",
            obscure: _obscurePassword,
            showDivider: false,
            suffix: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Padding(
                padding: const EdgeInsets.only(right: 14, left: 8),
                child: Icon(
                  _obscurePassword
                      ? CupertinoIcons.eye_slash_fill
                      : CupertinoIcons.eye_fill,
                  color: _inkMuted,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String placeholder,
    required bool showDivider,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    final bool focused = focusNode.hasFocus;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: showDivider
              ? const BorderSide(color: _hairline, width: 0.5)
              : BorderSide.none,
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        padding: const EdgeInsets.symmetric(vertical: 16),
        placeholder: placeholder,
        placeholderStyle: const TextStyle(color: _inkMuted, fontSize: 15),
        style: const TextStyle(color: _ink, fontSize: 16),
        cursorColor: _accent,
        decoration: const BoxDecoration(color: Colors.transparent),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          // 图标随聚焦变色，给出清晰的当前行反馈
          child: Icon(icon, color: focused ? _accent : _inkMuted, size: 20),
        ),
        suffix: suffix,
      ),
    );
  }

  // —— 主按钮：填充式，按下有物理回弹，加载/禁用态清晰 ——
  Widget _buildLoginButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _isLoading ? null : _handleLogin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: _isLoading ? _accent.withOpacity(0.6) : _accent,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                    color: _accent.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Text(
                "连接服务器",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
