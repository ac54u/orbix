import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/qbit_api.dart';
import 'main_screen.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 色彩与样式常量，匹配 iOS 设置页风格
  // 强调/状态色固定（明暗皆可读），结构色随系统明暗动态解析
  static const Color _accent = CupertinoColors.activeBlue;
  static const Color _errorColor = CupertinoColors.destructiveRed;
  static const Color _successColor = Color(0xFF34C759);
  static const double _radius = 12.0;
  // 动态结构色
  Color get _bgColor => AppColors.of(AppColors.groupedBg);
  Color get _cardColor => AppColors.of(AppColors.card);
  Color get _hairline => AppColors.of(AppColors.separator);
  Color get _textColor => AppColors.of(AppColors.label);
  Color get _placeholderColor => AppColors.of(AppColors.placeholder);
  Color get _sectionTitleColor => AppColors.of(AppColors.secondaryLabel);

  // 表单控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _useHttps = false;
  bool _obscurePassword = true;
  bool _isTesting = false;
  ConnectResult? _testResult; // 测试结果（成功/失败 + 原因）

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    // 兼容旧版本保存的完整 url：拆出 scheme/host/port
    final legacyUrl = prefs.getString('qbit_url');
    String? host = prefs.getString('qbit_host');
    String? port = prefs.getString('qbit_port');
    bool https = prefs.getBool('qbit_https') ?? false;
    if (host == null && legacyUrl != null && legacyUrl.isNotEmpty) {
      final parsed = Uri.tryParse(legacyUrl);
      if (parsed != null) {
        https = parsed.scheme == 'https';
        host = parsed.host;
        if (parsed.hasPort) port = parsed.port.toString();
      }
    }
    setState(() {
      _nameController.text = prefs.getString('qbit_name') ?? '';
      _hostController.text = host ?? '';
      _portController.text = port ?? '8080';
      _usernameController.text = prefs.getString('qbit_username') ?? 'admin';
      _passwordController.text = prefs.getString('qbit_password') ?? '';
      _useHttps = https;
    });
  }

  // 由 HTTPS 开关 + 主机 + 端口拼出最终 URL（智能容错见 QBitApi.buildUrl）
  String _buildUrl() =>
      QBitApi.buildUrl(_hostController.text, _portController.text, _useHttps);

  void _toast(String title, String msg, {bool error = false}) {
    Get.snackbar(
      title,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: _radius,
      backgroundColor: const Color(0xFF1C1C1E),
      colorText: Colors.white,
      icon: Icon(
        error ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.checkmark_circle,
        color: error ? _errorColor : _successColor,
      ),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();

    if (host.isEmpty || username.isEmpty) {
      _toast('无法保存', '主机地址和用户名不能为空', error: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qbit_name', _nameController.text.trim());
    await prefs.setString('qbit_host', host);
    await prefs.setString('qbit_port', _portController.text.trim());
    await prefs.setString('qbit_username', username);
    await prefs.setString('qbit_password', _passwordController.text.trim());
    await prefs.setBool('qbit_https', _useHttps);
    await prefs.remove('qbit_url'); // 清理旧版遗留键

    final cfg = ServerConfig(
      name: _nameController.text.trim(),
      url: _buildUrl(),
      username: username,
      password: _passwordController.text.trim(),
      host: host,
      port: _portController.text.trim(),
      https: _useHttps,
    );
    // 加入/更新服务器列表（供设置页切换）
    await QBitApi.upsertServer(cfg);

    final api = QBitApi();
    api.setServer(cfg);
    Get.offAll(() => const MainScreen());
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();

    if (host.isEmpty || username.isEmpty) {
      setState(() => _testResult =
          const ConnectResult(ConnectStatus.unknown, '请先填写主机地址和用户名'));
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final api = QBitApi();
    api.setServer(ServerConfig(
      url: _buildUrl(),
      username: username,
      password: _passwordController.text.trim(),
    ));

    final result = await api.connect();

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text('添加服务器',
            style: TextStyle(color: _textColor, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: canPop
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Get.back(),
                child: const Text('取消', style: TextStyle(color: _accent, fontSize: 16)),
              )
            : null,
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _handleSave,
            child: const Text('保存',
                style: TextStyle(color: _accent, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 服务器信息
              _buildSectionHeader('服务器信息'),
              _buildCardGroup([
                _buildTextField(_nameController, '名称（可选）', icon: CupertinoIcons.tag, isLast: false),
                _buildTextField(_hostController, '主机，例：192.168.1.2',
                    icon: CupertinoIcons.link, keyboardType: TextInputType.url, isLast: false),
                _buildTextField(_portController, '端口',
                    icon: CupertinoIcons.number, keyboardType: TextInputType.number, isLast: true),
              ]),

              // 2. 认证
              _buildSectionHeader('认证'),
              _buildCardGroup([
                _buildTextField(_usernameController, '用户名',
                    icon: CupertinoIcons.person, isLast: false),
                _buildTextField(_passwordController, '密码',
                    icon: CupertinoIcons.lock, obscure: _obscurePassword, isLast: true,
                    suffix: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 16),
                        child: Icon(
                          _obscurePassword
                              ? CupertinoIcons.eye_slash_fill
                              : CupertinoIcons.eye_fill,
                          color: _sectionTitleColor,
                          size: 18,
                        ),
                      ),
                    )),
              ]),

              // 3. 使用 HTTPS
              const SizedBox(height: 24),
              _buildCardGroup([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.lock_shield, color: _sectionTitleColor, size: 20),
                          const SizedBox(width: 10),
                          Text('使用 HTTPS', style: TextStyle(fontSize: 16, color: _textColor)),
                        ],
                      ),
                      CupertinoSwitch(
                        value: _useHttps,
                        onChanged: (val) => setState(() {
                          _useHttps = val;
                          _testResult = null; // 改了协议，旧的测试结果作废
                        }),
                      ),
                    ],
                  ),
                ),
              ]),

              // 4. 测试连接区
              const SizedBox(height: 24),
              _buildCardGroup([_buildTestRow(), ..._buildResultPanel()]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // —— 辅助组件构建方法 ——

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6, top: 24),
      child: Text(title, style: TextStyle(color: _sectionTitleColor, fontSize: 13)),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String placeholder, {
    required IconData icon,
    bool obscure = false,
    bool isLast = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        // 修复点：border 需要 Border，而非 BorderSide
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _hairline, width: 0.5)),
      ),
      child: CupertinoTextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        padding: const EdgeInsets.symmetric(vertical: 14),
        placeholder: placeholder,
        placeholderStyle: TextStyle(color: _placeholderColor, fontSize: 16),
        style: TextStyle(color: _textColor, fontSize: 16),
        cursorColor: _accent,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, color: _sectionTitleColor, size: 20),
        ),
        suffix: suffix,
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
    );
  }

  Widget _buildTestRow() {
    final bool ok = _testResult?.success ?? false;
    final bool failed = _testResult != null && !_testResult!.success;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onPressed: _isTesting ? null : _testConnection,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isTesting ? '测试中…' : '测试连接',
            style: const TextStyle(fontSize: 16, color: _accent),
          ),
          if (_isTesting)
            const CupertinoActivityIndicator()
          else if (ok)
            const Icon(CupertinoIcons.checkmark_circle_fill, color: _successColor, size: 22)
          else if (failed)
            const Icon(CupertinoIcons.xmark_circle_fill, color: _errorColor, size: 22),
        ],
      ),
    );
  }

  // 测试结果面板：成功为绿、失败为红，并按错误类型给出针对性提示
  List<Widget> _buildResultPanel() {
    final r = _testResult;
    if (r == null || _isTesting) return [];

    if (r.success) {
      return [
        Divider(height: 1, thickness: 0.5, color: _hairline),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              Icon(CupertinoIcons.checkmark_seal_fill, color: _successColor, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('连接成功，凭据有效，可以保存了',
                    style: TextStyle(color: _successColor, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ];
    }

    // 失败：标题与排查清单随错误类型变化
    String title;
    List<String> hints;
    switch (r.status) {
      case ConnectStatus.authFailed:
        title = '认证失败';
        hints = ['用户名是否正确', '密码是否正确'];
        break;
      case ConnectStatus.network:
        title = '网络连接失败';
        hints = ['服务器是否在线', '主机地址和端口是否正确', 'HTTPS 开关是否与服务器一致'];
        break;
      default:
        title = '连接失败';
        hints = ['请检查服务器配置'];
    }

    return [
      Divider(height: 1, thickness: 0.5, color: _hairline),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                    color: _errorColor, size: 16),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        color: _errorColor, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            // 排查清单用次要色，避免整块刺眼的红
            ...hints.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $h',
                      style: TextStyle(color: _sectionTitleColor, fontSize: 13, height: 1.4)),
                )),
            const SizedBox(height: 8),
            Text('详细信息：${r.message}',
                style: TextStyle(color: _placeholderColor, fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    ];
  }
}
