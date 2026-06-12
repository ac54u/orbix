import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../widgets/toast.dart';
import 'main_screen.dart';

/// 登录 / 添加 / 编辑服务器页。
///
/// 两种呈现：整页（首次启动）与底部 Page Sheet（设置页添加/编辑）。
class LoginScreen extends StatefulWidget {
  final ServerConfig? editServer;
  final bool asSheet;

  const LoginScreen({super.key, this.editServer, this.asSheet = false});

  bool get isEditing => editServer != null;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _useHttps = false;
  bool _obscurePassword = true;
  bool _isTesting = false;
  ConnectResult? _testResult;

  // —— sheet 下拉关闭手势 ——
  // _dragY 是当前 sheet 相对原位的纵向位移（px，≥0）。手指拖动时累加，
  // 放手后由 _settle 控制器驱动 Tween 回 0 或 screenHeight。
  late final AnimationController _settle;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: AppMotion.fast);
    _initFields();
  }

  @override
  void dispose() {
    _settle.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // —— 下拉手势：开始时停掉 settle 动画，并主动收键盘 ——
  void _onSheetDragStart(DragStartDetails d) {
    _settle.stop();
    FocusScope.of(context).unfocus();
  }

  // 仅向下拖（往上夹回 0），1:1 跟随手指
  void _onSheetDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragY = (_dragY + d.delta.dy).clamp(0.0, double.infinity);
    });
  }

  // 放手判定：速度 > 700px/s 或位移 > 120px 触发关闭；否则回弹
  void _onSheetDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    final shouldClose = velocity > 700 || _dragY > 120;
    if (shouldClose) {
      _settleSheetTo(MediaQuery.of(context).size.height, closeAfter: true);
    } else {
      _settleSheetTo(0, closeAfter: false);
    }
  }

  // 通用 settle：从当前 _dragY tween 到 targetY，完成后可选 Get.back
  void _settleSheetTo(double targetY, {required bool closeAfter}) {
    _settle.stop();
    final animation = Tween<double>(begin: _dragY, end: targetY)
        .animate(CurvedAnimation(parent: _settle, curve: AppMotion.standard));
    void onTick() {
      if (!mounted) return;
      setState(() => _dragY = animation.value);
    }
    void onStatus(AnimationStatus s) {
      if (s == AnimationStatus.completed) {
        animation.removeListener(onTick);
        _settle.removeStatusListener(onStatus);
        if (closeAfter && mounted) Get.back(result: false);
      }
    }
    animation.addListener(onTick);
    _settle.addStatusListener(onStatus);
    _settle.forward(from: 0);
  }

  void _initFields() {
    final s = widget.editServer;
    if (s != null) {
      final u = Uri.tryParse(s.url);
      final host = s.host.isNotEmpty ? s.host : (u?.host ?? '');
      final port = s.port.isNotEmpty
          ? s.port
          : (u != null && u.hasPort ? u.port.toString() : '8080');
      _nameController.text = s.name;
      _hostController.text = host;
      _portController.text = port;
      _usernameController.text = s.username;
      _passwordController.text = s.password;
      _useHttps = s.https || (u?.scheme == 'https');
    } else {
      _nameController.text = '';
      _hostController.text = '';
      _portController.text = '8080';
      _usernameController.text = 'admin';
      _passwordController.text = '';
      _useHttps = false;
    }
  }

  String _buildUrl() =>
      QBitApi.buildUrl(_hostController.text, _portController.text, _useHttps);

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();

    if (host.isEmpty || username.isEmpty) {
      Toast.error(context, '主机地址和用户名不能为空');
      return;
    }

    final cfg = ServerConfig(
      name: _nameController.text.trim(),
      url: _buildUrl(),
      username: username,
      password: _passwordController.text.trim(),
      host: host,
      port: _portController.text.trim(),
      https: _useHttps,
    );

    final old = widget.editServer;
    if (old != null) {
      // —— 编辑模式 ——
      if (old.url != cfg.url || old.username != cfg.username) {
        await QBitApi.removeServer(old);
      }
      await QBitApi.upsertServer(cfg);

      final active = await QBitApi.loadSavedConfig();
      final wasActive = active != null &&
          active.url == old.url &&
          active.username == old.username;
      if (wasActive) {
        await QBitApi.setActiveServer(cfg);
        QBitApi().setServer(cfg);
        unawaited(QBitApi().connect());
      }
      if (!mounted) return;
      Get.back(result: true);
      return;
    }

    // —— 新增模式 ——
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qbit_name', _nameController.text.trim());
    await prefs.setString('qbit_host', host);
    await prefs.setString('qbit_port', _portController.text.trim());
    await prefs.setString('qbit_username', username);
    await prefs.setString('qbit_password', _passwordController.text.trim());
    await prefs.setBool('qbit_https', _useHttps);
    await prefs.remove('qbit_url');

    await QBitApi.upsertServer(cfg);
    final api = QBitApi();
    api.setServer(cfg);

    if (widget.asSheet) {
      unawaited(api.connect());
      if (!mounted) return;
      Get.back(result: true);
      return;
    }
    Get.offAll(() => const MainScreen());
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();

    if (host.isEmpty || username.isEmpty) {
      setState(() => _testResult = const ConnectResult(
          ConnectStatus.unknown, '请先填写主机地址和用户名'));
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
    AppColors.watch(context);
    return widget.asSheet ? _buildSheet(context) : _buildFullPage(context);
  }

  // —— 整页呈现（首次启动）——
  Widget _buildFullPage(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.groupedBg),
      navigationBar: CupertinoNavigationBar(
        backgroundColor:
            AppColors.of(AppColors.groupedBg).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: AppColors.of(AppColors.separator),
            width: 0.0,
          ),
        ),
        leading: canPop
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => Get.back(),
                child: Text(
                  '取消',
                  style: AppTypography.body().copyWith(
                    color: AppColors.accent,
                  ),
                ),
              )
            : null,
        middle: Text(
          widget.isEditing ? '编辑服务器' : '添加服务器',
          style: AppTypography.navTitle(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _handleSave,
          child: Text(
            '保存',
            style: AppTypography.body().copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: _formBody(),
        ),
      ),
    );
  }

  // —— 底部 Page Sheet 呈现（设置页添加/编辑）——
  //
  // 三件事一次办：
  // ① `Padding(bottom: viewInsets.bottom)` —— Cupertino modal 不自动避让键盘，
  //    手动把 sheet 抬到键盘之上；
  // ② `Transform.translate(offset: _dragY)` —— 跟随下拉手势平移整个 sheet；
  // ③ 顶部抓手 + 头部行包在 `GestureDetector` 里，手势只在非滚动区生效，
  //    放手后由 `_settle` 控制器决定回弹 or 平滑下滑关闭。
  Widget _buildSheet(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.92;
    final keyboard = mq.viewInsets.bottom;
    final height = (maxHeight - keyboard).clamp(0.0, maxHeight);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Transform.translate(
        offset: Offset(0, _dragY),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.of(AppColors.groupedBg),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // —— 可拖拽区：抓手 + 头部 + hairline。整段绑垂直拖手势 ——
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onSheetDragStart,
                onVerticalDragUpdate: _onSheetDragUpdate,
                onVerticalDragEnd: _onSheetDragEnd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 抓手
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.of(AppColors.placeholder),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // 头部：取消 / 标题 / 保存
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () => Get.back(),
                            child: Text(
                              '取消',
                              style: AppTypography.body().copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          Text(
                            widget.isEditing ? '编辑服务器' : '添加服务器',
                            style: AppTypography.navTitle(),
                          ),
                          CupertinoButton(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: _handleSave,
                            child: Text(
                              '保存',
                              style: AppTypography.body().copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 0.5pt hairline 分隔
                    Container(
                      height: 0.5,
                      color: AppColors.of(AppColors.separator),
                    ),
                  ],
                ),
              ),
              // —— 表单滚动区，独立 scroll，不参与 sheet 下拉 ——
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: _formBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // —— 表单主体（整页与 sheet 共用）——
  Widget _formBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 服务器信息
        CupertinoFormSection.insetGrouped(
          backgroundColor: AppColors.of(AppColors.groupedBg),
          decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
          header: Text('服务器信息', style: AppTypography.sectionHeader()),
          children: [
            _textRow(_nameController, '名称（可选）', CupertinoIcons.tag),
            _textRow(_hostController, '主机，例：192.168.1.2',
                CupertinoIcons.link,
                keyboardType: TextInputType.url),
            _textRow(_portController, '端口', CupertinoIcons.number,
                keyboardType: TextInputType.number),
          ],
        ),

        // 2. 认证
        CupertinoFormSection.insetGrouped(
          backgroundColor: AppColors.of(AppColors.groupedBg),
          decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
          header: Text('认证', style: AppTypography.sectionHeader()),
          children: [
            _textRow(_usernameController, '用户名', CupertinoIcons.person),
            _passwordRow(),
          ],
        ),

        // 3. HTTPS
        CupertinoFormSection.insetGrouped(
          backgroundColor: AppColors.of(AppColors.groupedBg),
          decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
          children: [
            CupertinoFormRow(
              prefix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.lock_shield,
                      color: AppColors.of(AppColors.secondaryLabel),
                      size: 20),
                  const SizedBox(width: 12),
                  Text('使用 HTTPS', style: AppTypography.body()),
                ],
              ),
              child: CupertinoSwitch(
                value: _useHttps,
                onChanged: (val) => setState(() {
                  _useHttps = val;
                  _testResult = null;
                }),
              ),
            ),
          ],
        ),

        // 4. 测试连接
        CupertinoFormSection.insetGrouped(
          backgroundColor: AppColors.of(AppColors.groupedBg),
          decoration: BoxDecoration(color: AppColors.of(AppColors.card)),
          footer: _buildTestFooter(),
          children: [_buildTestRow()],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _textRow(
    TextEditingController controller,
    String placeholder,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return CupertinoTextFormFieldRow(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      style: AppTypography.body(),
      placeholderStyle: AppTypography.body(
        color: AppColors.of(AppColors.placeholder),
      ),
      prefix: Icon(
        icon,
        color: AppColors.of(AppColors.secondaryLabel),
        size: 20,
      ),
    );
  }

  Widget _passwordRow() {
    return CupertinoFormRow(
      prefix: Icon(
        CupertinoIcons.lock,
        color: AppColors.of(AppColors.secondaryLabel),
        size: 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField.borderless(
              controller: _passwordController,
              obscureText: _obscurePassword,
              placeholder: '密码',
              style: AppTypography.body(),
              placeholderStyle: AppTypography.body(
                color: AppColors.of(AppColors.placeholder),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                _obscurePassword
                    ? CupertinoIcons.eye_slash_fill
                    : CupertinoIcons.eye_fill,
                color: AppColors.of(AppColors.secondaryLabel),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestRow() {
    final bool ok = _testResult?.success ?? false;
    final bool failed = _testResult != null && !_testResult!.success;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isTesting ? null : _testConnection,
      child: CupertinoFormRow(
        prefix: Text(
          _isTesting ? '测试中…' : '测试连接',
          style: AppTypography.body().copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: _isTesting
            ? const CupertinoActivityIndicator(radius: 10)
            : ok
                ? const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: AppColors.success,
                    size: 22,
                  )
                : failed
                    ? const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppColors.danger,
                        size: 22,
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }

  // —— 测试结果作为 section footer 呈现（iOS Settings 风格的解释文本）——
  Widget? _buildTestFooter() {
    final r = _testResult;
    if (r == null || _isTesting) return null;

    if (r.success) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '连接成功，凭据有效，可以保存了',
          style: AppTypography.caption(
            color: AppColors.success,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      );
    }

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

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption(
              color: AppColors.danger,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final h in hints)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $h',
                style: AppTypography.caption().copyWith(height: 1.4),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '详细信息：${r.message}',
            style: AppTypography.caption(
              color: AppColors.of(AppColors.tertiaryLabel),
            ).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
