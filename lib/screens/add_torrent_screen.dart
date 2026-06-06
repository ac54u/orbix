import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../services/qbit_api.dart';

class AddTorrentScreen extends StatefulWidget {
  const AddTorrentScreen({super.key});

  @override
  State<AddTorrentScreen> createState() => _AddTorrentScreenState();
}

class _AddTorrentScreenState extends State<AddTorrentScreen> {
  // 状态变量
  bool _isLinkMode = true; // true: 链接模式, false: 文件模式
  bool _isInputValid = false; // 控制“添加”按钮的激活状态
  bool _submitting = false; // 提交中

  // 文件模式选中的种子
  List<int>? _pickedBytes;
  String? _pickedName;

  // 控制器
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();

  // 颜色常量
  static const Color _bgColor = Color(0xFFF2F2F7);
  static const Color _cardColor = Colors.white;
  static const Color _textColor = Color(0xFF1C1C1E);
  static const Color _hintColor = Color(0xFFC4C4C6);
  static const Color _sectionColor = Color(0xFF8E8E93);
  static const Color _dividerColor = Color(0xFFE5E5EA);
  static const Color _accent = Color(0xFF007AFF);

  @override
  void initState() {
    super.initState();
    // 链接框有内容时激活“添加”
    _linkController.addListener(_refreshValid);
  }

  @override
  void dispose() {
    _linkController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  // 根据当前模式刷新“添加”按钮可用状态
  void _refreshValid() {
    final valid = _isLinkMode
        ? _linkController.text.trim().isNotEmpty
        : _pickedBytes != null;
    if (valid != _isInputValid) {
      setState(() => _isInputValid = valid);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      debugPrint('选择文件失败: $e');
    }
    if (!mounted || result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) {
      _snack('无法读取文件内容', ok: false);
      return;
    }
    if (!f.name.toLowerCase().endsWith('.torrent')) {
      _snack('请选择 .torrent 文件', ok: false);
      return;
    }
    setState(() {
      _pickedBytes = f.bytes;
      _pickedName = f.name;
    });
    _refreshValid();
  }

  // 点击“添加”
  Future<void> _handleAdd() async {
    if (!_isInputValid || _submitting) return;
    setState(() => _submitting = true);

    final category = _categoryController.text.trim();
    final tags = _tagsController.text.trim();
    final path = _pathController.text.trim();

    bool ok;
    if (_isLinkMode) {
      ok = await QBitApi().addMagnet(
        _linkController.text.trim(),
        category: category,
        tags: tags,
        savePath: path,
      );
    } else {
      ok = await QBitApi().addTorrentBytes(
        _pickedBytes!,
        _pickedName!,
        category: category,
        tags: tags,
        savePath: path,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Get.back(result: true);
      _snack('任务已添加到下载队列', ok: true);
    } else {
      _snack('添加失败，请检查链接/文件或服务器', ok: false);
    }
  }

  void _snack(String msg, {required bool ok}) {
    Get.snackbar(
      ok ? '成功' : '失败',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      backgroundColor: const Color(0xFF1C1C1E),
      colorText: Colors.white,
      icon: Icon(
        ok ? CupertinoIcons.checkmark_circle : CupertinoIcons.exclamationmark_circle,
        color: ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildTopBar(),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSegmentedControl(),
                    const SizedBox(height: 24),
                    if (_isLinkMode) ...[
                      _buildSectionTitle("种子链接"),
                      const SizedBox(height: 8),
                      _buildLinkInput(),
                      const SizedBox(height: 8),
                      _buildSubText("支持 magnet: 或 http(s) 链接，可多行批量添加"),
                    ] else ...[
                      _buildSectionTitle("种子文件"),
                      const SizedBox(height: 8),
                      _buildFilePicker(),
                      const SizedBox(height: 8),
                      _buildSubText("从「文件」App 选择 .torrent 文件"),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionTitle("可选设置"),
                    const SizedBox(height: 8),
                    _buildSettingsGroup(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —— 顶部导航栏 ——
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPillButton(
            text: "取消",
            onTap: () => Get.back(),
            isActive: true,
          ),
          const Text(
            "添加种子",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          _buildAddButton(),
        ],
      ),
    );
  }

  // 圆角胶囊按钮（取消）
  Widget _buildPillButton({
    required String text,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? _textColor : _hintColor,
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // “添加”按钮：激活时高亮蓝色，提交中显示菊花
  Widget _buildAddButton() {
    final active = _isInputValid && !_submitting;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: active ? _handleAdd : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CupertinoActivityIndicator(radius: 8),
              )
            : Text(
                "添加",
                style: TextStyle(
                  color: active ? Colors.white : _hintColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // —— 分段控制器（链接 / 文件）——
  Widget _buildSegmentedControl() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSegmentItem("链接", true)),
          Expanded(child: _buildSegmentItem("文件", false)),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String title, bool isLink) {
    final isSelected = _isLinkMode == isLink;
    return GestureDetector(
      onTap: () {
        setState(() => _isLinkMode = isLink);
        _refreshValid();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF3FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? _accent : _sectionColor,
          ),
        ),
      ),
    );
  }

  // —— 链接输入 ——
  Widget _buildLinkInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _linkController,
        maxLines: 5,
        autofocus: true,
        cursorColor: _accent,
        style: const TextStyle(fontSize: 16, color: _textColor),
        decoration: const InputDecoration(
          hintText: "磁力链接或种子 URL",
          hintStyle: TextStyle(color: _hintColor, fontSize: 16),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // —— 文件选择 ——
  Widget _buildFilePicker() {
    final picked = _pickedName != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              picked ? CupertinoIcons.doc_fill : CupertinoIcons.doc_text_search,
              color: picked ? _accent : _sectionColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                picked ? _pickedName! : "点击选择 .torrent 文件",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: picked ? _textColor : _hintColor,
                ),
              ),
            ),
            if (picked)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _pickedBytes = null;
                    _pickedName = null;
                  });
                  _refreshValid();
                },
                child: const Icon(CupertinoIcons.clear_circled_solid,
                    color: _hintColor, size: 20),
              )
            else
              const Icon(CupertinoIcons.chevron_right, color: _hintColor, size: 16),
          ],
        ),
      ),
    );
  }

  // —— 可选设置 ——
  Widget _buildSettingsGroup() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildSettingRow("分类", "点击输入", _categoryController, false),
          _buildSettingRow("标签", "多个标签用逗号分隔", _tagsController, false),
          _buildSettingRow("保存路径", "留空＝服务器默认", _pathController, true),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
      String title, String hint, TextEditingController controller, bool isLast) {
    return Container(
      decoration: BoxDecoration(
        // 修复点：border 需要 Border 而非 BorderSide
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 16, color: _textColor)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              cursorColor: _accent,
              style: const TextStyle(fontSize: 16, color: _textColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // —— 辅助 ——
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 14, color: _sectionColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSubText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: _sectionColor),
      ),
    );
  }
}
