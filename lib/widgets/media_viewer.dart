import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 全屏媒体浏览器（对标 iOS 相册 & Telegram）
///
/// 功能：
///   1. Hero 过渡打开/关闭
///   2. PageView 左右滑动切换
///   3. InteractiveViewer 捏合缩放 + 双击缩放
///   4. 手势冲突解决：缩放中→平移；1x 时→左/右翻页 / 上/下退出
///   5. 下拉退出：图片跟随手指，背景渐变透明，松手决定 pop 或回弹
class MediaViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String Function(int index) heroTagBuilder;
  final Widget Function(int index)? overlayBuilder;

  const MediaViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTagBuilder,
    this.overlayBuilder,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageCtrl;

  // ── 退出拖拽 ──
  double _dismissProgress = 0;
  Offset _dragOrigin = Offset.zero;
  Offset _dismissOffset = Offset.zero;
  bool _isDragging = false;

  // ── Overlay 显示/隐藏 ──
  bool _overlayVisible = true;

  // ── 退出动画 ──
  late AnimationController _dismissCtrl;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
    _dismissCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _dismissCtrl.addListener(() {
      setState(() {
        _dismissProgress = _dismissCtrl.value;
      });
    });
    _dismissCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _dismissCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageCtrl.animateToPage(_currentIndex + 1,
          duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      setState(() => _currentIndex++);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _pageCtrl.animateToPage(_currentIndex - 1,
          duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      setState(() => _currentIndex--);
    }
  }

  void _startDismiss(DragStartDetails d) {
    _isDragging = true;
    _dragOrigin = d.globalPosition;
    _dismissCtrl.reset();
  }

  void _updateDismiss(DragUpdateDetails d) {
    if (!_isDragging) return;
    final offset = d.globalPosition - _dragOrigin;
    setState(() {
      _dismissOffset = offset;
      _dismissProgress = (offset.distance / 300).clamp(0.0, 1.0);
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
  }

  void _endDismiss(DragEndDetails d) {
    if (!_isDragging) return;
    _isDragging = false;
    if (d.primaryVelocity != null && d.primaryVelocity!.abs() > 800 ||
        _dismissProgress > 0.4) {
      _dismissCtrl.forward();
    } else {
      _dismissCtrl.reverse();
      setState(() {
        _dismissOffset = Offset.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dismissProgress = _dismissCtrl.isAnimating
        ? _dismissCtrl.value
        : _dismissProgress;
    final scale = 1 - dismissProgress * 0.25;

    return Listener(
      onPointerDown: (e) {
        _dragOrigin = e.position;
      },
      child: GestureDetector(
        onVerticalDragStart: _startDismiss,
        onVerticalDragUpdate: _updateDismiss,
        onVerticalDragEnd: _endDismiss,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black.withValues(alpha: (1 - dismissProgress * 0.6).clamp(0.0, 1.0)),
              child: Opacity(
                opacity: (1 - dismissProgress * 1.2).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: _dismissCtrl.isAnimating
                      ? Offset(0, _dismissCtrl.value * (_dismissOffset.dy.sign * 300))
                      : _dismissOffset,
                  child: Transform.scale(
                    scale: scale,
                    child: PageView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _pageCtrl,
                      itemCount: widget.imageUrls.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (ctx, i) => _ImagePage(
                        url: widget.imageUrls[i],
                        heroTag: widget.heroTagBuilder(i),
                        isCurrentPage: i == _currentIndex,
                        onZoomChanged: (_) {},
                        onSwipeLeft: _goNext,
                        onSwipeRight: _goPrev,
                        onToggleOverlay: _toggleOverlay,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.overlayBuilder != null && _overlayVisible)
              widget.overlayBuilder!(_currentIndex),
          ],
        ),
      ),
    );
  }
}

/// 单张图片页：InteractiveViewer + 手势处理
class _ImagePage extends StatefulWidget {
  final String url;
  final String heroTag;
  final bool isCurrentPage;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback? onToggleOverlay;

  const _ImagePage({
    required this.url,
    required this.heroTag,
    required this.isCurrentPage,
    required this.onZoomChanged,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.onToggleOverlay,
  });

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  final TransformationController _ctrl = TransformationController();
  double _currentScale = 1;
  bool _hasTriggeredSwipe = false;

  // 双击缩放用
  bool _doubleTapZoomed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTransformChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _ctrl.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (isZoomed != (_currentScale > 1.05)) {
      widget.onZoomChanged(isZoomed);
    }
    _currentScale = scale;
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final translation = _ctrl.value.getTranslation();
    final scale = _ctrl.value.getMaxScaleOnAxis();

    // 只有在 1x 附近时才触发翻页
    if (scale < 1.1) {
      final dx = translation.x;

      // 垂直方向超过 80 → 交给父级 GestureDetector 处理，不在这里处理
      // 水平翻页
      if (dx > 80 && !_hasTriggeredSwipe) {
        _hasTriggeredSwipe = true;
        widget.onSwipeRight();
        _reset();
        return;
      } else if (dx < -80 && !_hasTriggeredSwipe) {
        _hasTriggeredSwipe = true;
        widget.onSwipeLeft();
        _reset();
        return;
      }
    }

    // 如果缩放中且图片被拖到边缘，继续拖触发放大后的翻页
    if (scale > 1.1) {
      final maxX = (MediaQuery.of(context).size.width * (scale - 1)) / 2;
      if (_ctrl.value.getTranslation().x > maxX + 20) {
        // 已拖到右边缘，继续 → 上一张
        if (!_hasTriggeredSwipe) {
          _hasTriggeredSwipe = true;
          widget.onSwipeRight();
          _afterZoomSwipe();
          return;
        }
      } else if (_ctrl.value.getTranslation().x < -maxX - 20) {
        if (!_hasTriggeredSwipe) {
          _hasTriggeredSwipe = true;
          widget.onSwipeLeft();
          _afterZoomSwipe();
          return;
        }
      }
    }

    // 未触发翻页 → 回弹
    if (_currentScale <= 1) {
      _reset();
    }
  }

  void _afterZoomSwipe() {
    // 切页后延迟重置，让新页面接管
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _hasTriggeredSwipe = false;
        _reset();
      }
    });
  }

  void _reset() {
    _ctrl.value = Matrix4.identity();
    _currentScale = 1;
    _doubleTapZoomed = false;
  }

  void _onDoubleTap() {
    if (_doubleTapZoomed) {
      _reset();
    } else {
      _doubleTapZoomed = true;
      final size = MediaQuery.of(context).size;
      _ctrl.value = Matrix4.identity()
        ..translate(size.width / 2, size.height / 2)
        ..scale(2.5)
        ..translate(-size.width / 2, -size.height / 2);
    }
    widget.onZoomChanged(_doubleTapZoomed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      onTap: () => widget.onToggleOverlay?.call(),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: InteractiveViewer(
          transformationController: _ctrl,
          maxScale: 5,
          minScale: 1,
          // 边界留空让拖拽操作能检测到偏移
          boundaryMargin: const EdgeInsets.all(200),
          onInteractionEnd: _onInteractionEnd,
          clipBehavior: Clip.none,
          child: Hero(
            tag: widget.heroTag,
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                CupertinoIcons.photo,
                color: Colors.white54,
                size: 64,
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(child: CupertinoActivityIndicator());
              },
            ),
          ),
        ),
      ),
    );
  }
}
