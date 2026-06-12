import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/toast.dart';

/// 添加种子页：支持磁力链接 / URL / 本地 .torrent 文件，三选一。
class AddTorrentScreen extends StatefulWidget {
  const AddTorrentScreen({super.key});

  @override
  State<AddTorrentScreen> createState() => _AddTorrentScreenState();
}

class _AddTorrentScreenState extends State<AddTorrentScreen> {
  bool _isLinkMode = true; // true: 链接，false: 文件
  bool _isInputValid = false;
  bool _submitting = false;

  List<int>? _pickedBytes;
  String? _pickedName;

  final _linkController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      Toast.error(context, '无法读取文件内容');
      return;
    }
    if (!f.name.toLowerCase().endsWith('.torrent')) {
      Toast.error(context, '请选择 .torrent 文件');
      return;
    }
    setState(() {
      _pickedBytes = f.bytes;
      _pickedName = f.name;
    });
    _refreshValid();
  }

  Future<void> _handleAdd() async {
    if (!_isInputValid || _submitting) return;
    setState(() => _submitting = true);

    final category = _categoryController.text.trim();
    final tags = _tagsController.text.trim();
    final path = _pathController.text.trim();

    String? error;
    if (_isLinkMode) {
      error = await QBitApi().addMagnet(
        _linkController.text.trim(),
        category: category,
        tags: tags,
        savePath: path,
      );
    } else {
      error = await QBitApi().addTorrentBytes(
        _pickedBytes!,
        _pickedName!,
        category: category,
        tags: tags,
        savePath: path,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error == null) {
      Get.back(result: true);
      Toast.success(context, '任务已添加到下载队列');
    } else {
      Toast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final canAdd = _isInputValid && !_submitting;
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
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Get.back(),
          child: Text(
            '取消',
            style: AppTypography.body().copyWith(
              color: CupertinoColors.systemBlue,
            ),
          ),
        ),
        middle: Text('添加种子', style: AppTypography.navTitle()),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: canAdd ? _handleAdd : null,
          child: _submitting
              ? const CupertinoActivityIndicator(radius: 10)
              : Text(
                  '添加',
                  style: AppTypography.body().copyWith(
                    fontWeight: FontWeight.w600,
                    color: canAdd
                        ? CupertinoColors.systemBlue
                        : AppColors.of(AppColors.tertiaryLabel),
                  ),
                ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // —— 链接 / 文件 切换 ——
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _isLinkMode ? 0 : 1,
                  children: {
                    0: _segLabel('链接'),
                    1: _segLabel('文件'),
                  },
                  onValueChanged: (v) {
                    if (v == null) return;
                    setState(() => _isLinkMode = v == 0);
                    _refreshValid();
                  },
                ),
              ),
              if (_isLinkMode)
                _buildLinkSection()
              else
                _buildFileSection(),
              _buildOptionsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segLabel(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: AppTypography.body().copyWith(fontSize: 14)),
      );

  // —— 链接输入 section：单 tile 多行文本 ——
  Widget _buildLinkSection() {
    return CupertinoListSection.insetGrouped(
      header: Text('种子链接', style: AppTypography.sectionHeader()),
      footer: Text(
        '支持 magnet: 或 http(s) 链接，可多行批量添加',
        style: AppTypography.caption(
          color: AppColors.of(AppColors.tertiaryLabel),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: CupertinoTextField.borderless(
            controller: _linkController,
            maxLines: 5,
            autofocus: true,
            placeholder: '磁力链接或种子 URL',
            style: AppTypography.body(),
            placeholderStyle: AppTypography.body(
              color: AppColors.of(AppColors.placeholder),
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // —— 文件选择 section：单 tile，已选 / 未选两态 ——
  Widget _buildFileSection() {
    final picked = _pickedName != null;
    return CupertinoListSection.insetGrouped(
      header: Text('种子文件', style: AppTypography.sectionHeader()),
      footer: Text(
        '从「文件」App 选择 .torrent 文件',
        style: AppTypography.caption(
          color: AppColors.of(AppColors.tertiaryLabel),
        ),
      ),
      children: [
        CupertinoListTile.notched(
          onTap: _pickFile,
          leading: Icon(
            picked ? CupertinoIcons.doc_fill : CupertinoIcons.doc_text_search,
            color: picked
                ? CupertinoColors.systemBlue
                : AppColors.of(AppColors.secondaryLabel),
            size: 24,
          ),
          title: Text(
            picked ? _pickedName! : '点击选择 .torrent 文件',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body().copyWith(
              color: picked
                  ? AppColors.of(AppColors.label)
                  : AppColors.of(AppColors.placeholder),
            ),
          ),
          trailing: picked
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _pickedBytes = null;
                      _pickedName = null;
                    });
                    _refreshValid();
                  },
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    color: AppColors.of(AppColors.tertiaryLabel),
                    size: 20,
                  ),
                )
              : const CupertinoListTileChevron(),
        ),
      ],
    );
  }

  // —— 可选设置 section：key/value 行 ——
  Widget _buildOptionsSection() {
    return CupertinoFormSection.insetGrouped(
      header: Text('可选设置', style: AppTypography.sectionHeader()),
      children: [
        _kvRow('分类', '点击输入', _categoryController),
        _kvRow('标签', '多个标签用逗号分隔', _tagsController),
        _kvRow('保存路径', '留空 = 服务器默认', _pathController),
      ],
    );
  }

  Widget _kvRow(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return CupertinoFormRow(
      prefix: SizedBox(
        width: 84,
        child: Text(label, style: AppTypography.body()),
      ),
      child: CupertinoTextField.borderless(
        controller: controller,
        textAlign: TextAlign.right,
        placeholder: hint,
        style: AppTypography.body(),
        placeholderStyle: AppTypography.body(
          color: AppColors.of(AppColors.placeholder),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
