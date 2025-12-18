import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:canvas_danmaku/utils/utils.dart';
import 'package:flutter/material.dart';
import 'models/danmaku_item.dart';
import 'scroll_danmaku_painter.dart';
import 'special_danmaku_painter.dart';
import 'static_danmaku_painter.dart';
import 'danmaku_controller.dart';
import 'dart:ui' as ui;
import 'models/danmaku_option.dart';
import 'dart:math';

class DanmakuScreen extends StatefulWidget {
  // 创建Screen后返回控制器
  final Function(DanmakuController) createdController;
  final DanmakuOption option;

  const DanmakuScreen({
    required this.createdController,
    required this.option,
    super.key,
  });

  @override
  State<DanmakuScreen> createState() => _DanmakuScreenState();
}

class _DanmakuScreenState extends State<DanmakuScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// 视图宽度
  double _viewWidth = 0;

  /// 弹幕控制器
  late DanmakuController _controller;

  /// 弹幕动画控制器
  late AnimationController _animationController;

  /// 静态弹幕动画控制器
  late AnimationController _staticAnimationController;

  /// 弹幕配置
  DanmakuOption _option = DanmakuOption();

  /// 滚动弹幕
  final List<DanmakuItem> _scrollDanmakuItems = [];

  /// 顶部弹幕
  final List<DanmakuItem> _topDanmakuItems = [];

  /// 底部弹幕
  final List<DanmakuItem> _bottomDanmakuItems = [];

  /// 高级弹幕
  final List<DanmakuItem> _specialDanmakuItems = [];

  /// 弹幕高度
  late double _danmakuHeight;

  /// 弹幕轨道数
  late int _trackCount;

  /// 弹幕轨道位置
  final List<double> _trackYPositions = [];

  late final _random = Random();

  final Map<String, ui.Image> _avatarCache = {};
  final Map<String, ImageStream> _avatarStreams = {};
  final Map<String, ImageStreamListener> _avatarListeners = {};

  /// 内部计时器
  int get _tick => _stopwatch.elapsedMilliseconds;

  final _stopwatch = Stopwatch();

  /// 运行状态
  bool _running = true;

  void _handleTapDown(TapDownDetails details, Size size) {
    if (!_option.enableTap) return;
    if (_option.onAvatarTap == null && _option.onHighlightTap == null) return;

    final local = details.localPosition;

    DanmakuItem? hit;
    Offset? hitOffset;

    for (int i = _scrollDanmakuItems.length - 1; i >= 0; i--) {
      final item = _scrollDanmakuItems[i];
      final offset = Offset(item.xPosition, item.yPosition);
      if ((offset & Size(item.width, item.height)).contains(local)) {
        hit = item;
        hitOffset = offset;
        break;
      }
    }

    if (hit == null) {
      for (int i = _topDanmakuItems.length - 1; i >= 0; i--) {
        final item = _topDanmakuItems[i];
        final offset = Offset(item.xPosition, item.yPosition);
        if ((offset & Size(item.width, item.height)).contains(local)) {
          hit = item;
          hitOffset = offset;
          break;
        }
      }
    }

    if (hit == null) {
      for (int i = _bottomDanmakuItems.length - 1; i >= 0; i--) {
        final item = _bottomDanmakuItems[i];
        final bottomY = size.height - item.yPosition - _danmakuHeight;
        final offset = Offset(item.xPosition, bottomY);
        if ((offset & Size(item.width, item.height)).contains(local)) {
          hit = item;
          hitOffset = offset;
          break;
        }
      }
    }

    if (hit == null || hitOffset == null) return;

    final avatarRect = _avatarRectForItem(hit, hitOffset);
    if (avatarRect != null && avatarRect.contains(local)) {
      _option.onAvatarTap?.call(hit.content);
      return;
    }

    final (span, index) = _hitTestHighlightSpan(hit, hitOffset, local);
    if (span != null && index != null) {
      _option.onHighlightTap?.call(hit.content, span, index);
    }
  }

  Rect? _avatarRectForItem(DanmakuItem item, Offset itemOffset) {
    if (!_option.enableAvatar) return null;
    if (item.content.avatarUrl == null) return null;
    final hasBg = _option.enableItemBackground;
    final contentTop = itemOffset.dy;
    final contentHeight = item.height;
    final avatarSize = _option.avatarSize;
    final avatarTop = contentTop + (contentHeight - avatarSize) / 2;
    final avatarLeft = _option.avatarOverlayOnLeft
        ? (itemOffset.dx - avatarSize / 2)
        : (itemOffset.dx + (hasBg ? _option.itemPaddingHorizontal : 0));
    return Rect.fromLTWH(avatarLeft, avatarTop, avatarSize, avatarSize);
  }

  double _avatarSpace(DanmakuItem item) {
    if (!_option.enableAvatar) return 0;
    if (item.content.avatarUrl == null) return 0;
    if (_option.avatarOverlayOnLeft) return 0;
    return _option.avatarSize + _option.avatarGap;
  }

  double _overlayTextInset(DanmakuItem item) {
    if (!_option.enableAvatar) return 0;
    if (!_option.avatarOverlayOnLeft) return 0;
    if (item.content.avatarUrl == null) return 0;
    final base = _option.avatarSize / 2 + _option.avatarGap;
    final pad = _option.enableItemBackground ? _option.itemPaddingHorizontal : 0;
    final inset = base - pad;
    return inset > 0 ? inset : 0;
  }

  double _paragraphWidthForHitTest(DanmakuItem item) {
    if (!_option.enableItemBackground) return item.width;
    final w = item.width -
        (_option.itemPaddingHorizontal * 2) -
        _avatarSpace(item) -
        _overlayTextInset(item);
    if (w <= 0) return item.width;
    return w;
  }

  double _cardHeightForHitTest(DanmakuItem item) {
    if (!_option.enableItemBackground) return item.height;
    if (_option.itemFixedHeight > 0) return _option.itemFixedHeight;
    return item.height;
  }

  double _cardTopForHitTest(DanmakuItem item, Offset itemOffset) {
    final h = _cardHeightForHitTest(item);
    return itemOffset.dy + (item.height - h) / 2;
  }

  Offset _textOffsetForHitTest(
      DanmakuItem item, Offset itemOffset, ui.Paragraph paragraph) {
    final hasBg = _option.enableItemBackground;
    final cardTop = _cardTopForHitTest(item, itemOffset);
    final cardHeight = _cardHeightForHitTest(item);
    final contentTop = cardTop + (hasBg ? _option.itemPaddingVertical : 0);
    final contentHeight =
        cardHeight - (hasBg ? (_option.itemPaddingVertical * 2) : 0);
    final textTop = contentTop + (contentHeight - paragraph.height) / 2;

    return Offset(
      itemOffset.dx +
          (hasBg ? _option.itemPaddingHorizontal : 0) +
          _avatarSpace(item) +
          _overlayTextInset(item),
      textTop,
    );
  }

  (DanmakuTextSpan?, int?) _hitTestHighlightSpan(
      DanmakuItem item, Offset itemOffset, Offset local) {
    final spans = item.content.spans;
    if (spans == null || spans.isEmpty) return (null, null);

    final paragraphWidth = _paragraphWidthForHitTest(item);
    item.paragraph ??= Utils.generateParagraph(
        item.content, paragraphWidth, _option.fontSize, _option.fontWeight);
    final paragraph = item.paragraph!;
    final textOffset = _textOffsetForHitTest(item, itemOffset, paragraph);
    final textRect = textOffset & Size(paragraphWidth, paragraph.height);
    if (!textRect.contains(local)) return (null, null);

    double dx = textOffset.dx;
    for (int i = 0; i < spans.length; i++) {
      final span = spans[i];
      final isHighlight = span.color != null && span.color != item.content.color;
      final painter = TextPainter(
        text: TextSpan(
          text: span.text,
          style: TextStyle(
            color: span.color ?? item.content.color,
            fontSize: _option.fontSize,
            fontWeight: FontWeight.values[_option.fontWeight],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      final rect = Rect.fromLTWH(dx, textOffset.dy, w, paragraph.height);
      if (rect.contains(local)) {
        if (isHighlight) {
          return (span, i);
        }
        return (null, null);
      }
      dx += w;
    }
    return (null, null);
  }

  @override
  void initState() {
    super.initState();
    // 计时器初始化
    _startTick();
    _option = widget.option;
    _controller = DanmakuController(
      onAddDanmaku: addDanmaku,
      onUpdateOption: updateOption,
      onPause: pause,
      onResume: resume,
      onClear: clearDanmakus,
    );
    _controller.option = _option;
    widget.createdController.call(
      _controller,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _option.duration),
    )..repeat();

    _staticAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _option.duration),
    );

    WidgetsBinding.instance.addObserver(this);
  }

  /// 处理 Android/iOS 应用后台或熄屏导致的动画问题
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      pause();
    }
  }

  @override
  void dispose() {
    _running = false;
    for (final entry in _avatarStreams.entries) {
      final listener = _avatarListeners[entry.key];
      if (listener != null) {
        entry.value.removeListener(listener);
      }
    }
    _avatarStreams.clear();
    _avatarListeners.clear();
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _staticAnimationController.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _ensureAvatarLoaded(DanmakuItem item) {
    if (!_option.enableAvatar) return;
    final url = item.content.avatarUrl;
    if (url == null || url.isEmpty) return;
    if (item.avatarImage != null) return;

    final cached = _avatarCache[url];
    if (cached != null) {
      item.avatarImage = cached;
      return;
    }

    if (_avatarStreams.containsKey(url)) return;

    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        _avatarCache[url] = info.image;

        for (final it in _scrollDanmakuItems) {
          if (it.content.avatarUrl == url && it.avatarImage == null) {
            it.avatarImage = info.image;
          }
        }
        for (final it in _topDanmakuItems) {
          if (it.content.avatarUrl == url && it.avatarImage == null) {
            it.avatarImage = info.image;
          }
        }
        for (final it in _bottomDanmakuItems) {
          if (it.content.avatarUrl == url && it.avatarImage == null) {
            it.avatarImage = info.image;
          }
        }

        stream.removeListener(listener);
        _avatarStreams.remove(url);
        _avatarListeners.remove(url);

        if (mounted) {
          setState(() {});
        }
      },
      onError: (Object _, StackTrace? __) {
        stream.removeListener(listener);
        _avatarStreams.remove(url);
        _avatarListeners.remove(url);
      },
    );

    _avatarStreams[url] = stream;
    _avatarListeners[url] = listener;
    stream.addListener(listener);
  }

  /// 添加弹幕
  void addDanmaku(DanmakuContentItem content) {
    if (!_running || !mounted) {
      return;
    }

    if (content.type == DanmakuItemType.special) {
      if (!_option.hideSpecial) {
        final special = content as SpecialDanmakuContentItem;
        final baseAlpha =
            special.alphaTween?.begin ?? (special.color.a / 255.0);
        special.painterCache = TextPainter(
          text: TextSpan(
            text: special.text,
            style: TextStyle(
              color: special.color,
              fontSize: special.fontSize,
              fontWeight: FontWeight.values[_option.fontWeight],
              shadows: special.hasStroke
                  ? [
                      Shadow(
                          color: Colors.black.withValues(alpha: baseAlpha),
                          blurRadius: 2)
                    ]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        _specialDanmakuItems.add(DanmakuItem(
          width: 0,
          height: 0,
          creationTime: _tick,
          content: content,
          paragraph: null,
          strokeParagraph: null,
        ));
      } else {
        return;
      }
    } else {
      // 在这里提前创建 Paragraph 缓存防止卡顿
      final textPainter = TextPainter(
        text: TextSpan(
            text: content.text,
            style: TextStyle(
                fontSize: _option.fontSize,
                fontWeight: FontWeight.values[_option.fontWeight])),
        textDirection: TextDirection.ltr,
      )..layout();
      final danmakuWidth = textPainter.width;
      final danmakuHeight = textPainter.height;

      final hasAvatar =
          _option.enableAvatar && (content.avatarUrl?.isNotEmpty ?? false);
      final double avatarDrawSize = _option.avatarSize;
      final double startX = _viewWidth +
          ((hasAvatar && _option.avatarOverlayOnLeft) ? (avatarDrawSize / 2) : 0.0);
      final avatarSpace = (hasAvatar && !_option.avatarOverlayOnLeft)
          ? (avatarDrawSize + _option.avatarGap)
          : 0.0;
      final overlayTextInset = (hasAvatar && _option.avatarOverlayOnLeft)
          ? max<double>(
              0.0,
              (avatarDrawSize / 2 + _option.avatarGap) -
                  (_option.enableItemBackground
                      ? _option.itemPaddingHorizontal
                      : 0),
            )
          : 0.0;
      final double cardHeight =
          _option.itemFixedHeight > 0 ? _option.itemFixedHeight : 0.0;
      final contentHeight = cardHeight > 0
          ? cardHeight
          : (hasAvatar
              ? max(danmakuHeight, _option.avatarSize).toDouble()
              : danmakuHeight);

      final double itemWidth = _option.enableItemBackground
          ? danmakuWidth +
              avatarSpace +
              overlayTextInset +
              (_option.itemPaddingHorizontal * 2)
          : danmakuWidth + avatarSpace + overlayTextInset;
      final double itemHeight = cardHeight > 0
          ? (hasAvatar ? max(cardHeight, _option.avatarSize).toDouble() : cardHeight)
          : (_option.enableItemBackground
              ? (contentHeight + (_option.itemPaddingVertical * 2)).toDouble()
              : contentHeight.toDouble());

      final ui.Paragraph paragraph = Utils.generateParagraph(
          content, danmakuWidth, _option.fontSize, _option.fontWeight);

      ui.Paragraph? strokeParagraph;
      if (_option.showStroke) {
        strokeParagraph = Utils.generateStrokeParagraph(
            content, danmakuWidth, _option.fontSize, _option.fontWeight);
      }

      int idx = 1;
      final trackPositions = _option.randomTrack
          ? (List<double>.from(_trackYPositions)..shuffle(_random))
          : _trackYPositions;
      for (double yPosition in trackPositions) {
        if (content.type == DanmakuItemType.scroll && !_option.hideScroll) {
          bool scrollCanAddToTrack = _scrollCanAddToTrack(yPosition, itemWidth);

          if (scrollCanAddToTrack) {
            final item = DanmakuItem(
                yPosition: yPosition,
                xPosition: startX,
                width: itemWidth,
                height: itemHeight,
                creationTime: _tick,
                content: content,
                paragraph: paragraph,
                strokeParagraph: strokeParagraph);
            _scrollDanmakuItems.add(item);
            _ensureAvatarLoaded(item);
            break;
          }

          /// 无法填充自己发送的弹幕时强制添加
          if (content.selfSend && idx == _trackCount) {
            final item = DanmakuItem(
                yPosition: _trackYPositions[0],
                xPosition: startX,
                width: itemWidth,
                height: itemHeight,
                creationTime: _tick,
                content: content,
                paragraph: paragraph,
                strokeParagraph: strokeParagraph);
            _scrollDanmakuItems.add(item);
            _ensureAvatarLoaded(item);
            break;
          }

          /// 海量弹幕启用时进行随机添加
          if (_option.massiveMode && idx == _trackCount) {
            var randomYPosition =
                _trackYPositions[_random.nextInt(_trackYPositions.length)];
            final item = DanmakuItem(
                yPosition: randomYPosition,
                xPosition: startX,
                width: itemWidth,
                height: itemHeight,
                creationTime: _tick,
                content: content,
                paragraph: paragraph,
                strokeParagraph: strokeParagraph);
            _scrollDanmakuItems.add(item);
            _ensureAvatarLoaded(item);
            break;
          }
        }

        if (content.type == DanmakuItemType.top && !_option.hideTop) {
          bool topCanAddToTrack = _topCanAddToTrack(yPosition);

          if (topCanAddToTrack) {
            final item = DanmakuItem(
                yPosition: yPosition,
                xPosition: startX,
                width: itemWidth,
                height: itemHeight,
                creationTime: _tick,
                content: content,
                paragraph: paragraph,
                strokeParagraph: strokeParagraph);
            _topDanmakuItems.add(item);
            _ensureAvatarLoaded(item);
            break;
          }
        }

        if (content.type == DanmakuItemType.bottom && !_option.hideBottom) {
          bool bottomCanAddToTrack = _bottomCanAddToTrack(yPosition);

          if (bottomCanAddToTrack) {
            final item = DanmakuItem(
                yPosition: yPosition,
                xPosition: startX,
                width: itemWidth,
                height: itemHeight,
                creationTime: _tick,
                content: content,
                paragraph: paragraph,
                strokeParagraph: strokeParagraph);
            _bottomDanmakuItems.add(item);
            _ensureAvatarLoaded(item);
            break;
          }
        }
        idx++;
      }
    }

    switch (content.type) {
      case DanmakuItemType.top:
      case DanmakuItemType.bottom:
        // 重绘静态弹幕
        setState(() {
          _staticAnimationController.value = 0;
        });
        break;
      case DanmakuItemType.scroll:
      case DanmakuItemType.special:
        if (!_animationController.isAnimating &&
            (_scrollDanmakuItems.isNotEmpty ||
                _specialDanmakuItems.isNotEmpty)) {
          _animationController.repeat();
        }
        break;
    }
  }

  /// 暂停
  void pause() {
    if (!mounted) return;
    if (_running) {
      setState(() {
        _running = false;
      });
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
      }
    }
  }

  /// 恢复
  void resume() {
    if (!mounted) return;
    if (!_running) {
      setState(() {
        _running = true;
      });
      if (!_animationController.isAnimating) {
        _animationController.repeat();
        // 重启计时器
        _startTick();
      }
    }
  }

  /// 更新弹幕设置
  void updateOption(DanmakuOption option) {
    bool needRestart = false;
    bool needClearParagraph = false;
    if (_animationController.isAnimating) {
      _animationController.stop();
      needRestart = true;
    }

    if (option.fontSize != _option.fontSize) {
      needClearParagraph = true;
    }

    /// 需要隐藏弹幕时清理已有弹幕
    if (option.hideScroll && !_option.hideScroll) {
      _scrollDanmakuItems.clear();
    }
    if (option.hideTop && !_option.hideTop) {
      _topDanmakuItems.clear();
    }
    if (option.hideBottom && !_option.hideBottom) {
      _bottomDanmakuItems.clear();
    }

    if (option.enableAvatar && !_option.enableAvatar) {
      for (final item in _scrollDanmakuItems) {
        _ensureAvatarLoaded(item);
      }
      for (final item in _topDanmakuItems) {
        _ensureAvatarLoaded(item);
      }
      for (final item in _bottomDanmakuItems) {
        _ensureAvatarLoaded(item);
      }
    }
    _option = option;
    _controller.option = _option;

    /// 清理已经存在的 Paragraph 缓存
    if (needClearParagraph) {
      for (DanmakuItem item in _scrollDanmakuItems) {
        if (item.paragraph != null) {
          item.paragraph = null;
        }
        if (item.strokeParagraph != null) {
          item.strokeParagraph = null;
        }
      }
      for (DanmakuItem item in _topDanmakuItems) {
        if (item.paragraph != null) {
          item.paragraph = null;
        }
        if (item.strokeParagraph != null) {
          item.strokeParagraph = null;
        }
      }
      for (DanmakuItem item in _bottomDanmakuItems) {
        if (item.paragraph != null) {
          item.paragraph = null;
        }
        if (item.strokeParagraph != null) {
          item.strokeParagraph = null;
        }
      }
    }
    if (needRestart) {
      _animationController.repeat();
    }
    setState(() {});
  }

  /// 清空弹幕
  void clearDanmakus() {
    if (!mounted) return;
    setState(() {
      _scrollDanmakuItems.clear();
      _topDanmakuItems.clear();
      _bottomDanmakuItems.clear();
      _specialDanmakuItems.clear();
    });
    _animationController.stop();
  }

  /// 确定滚动弹幕是否可以添加
  bool _scrollCanAddToTrack(double yPosition, double newDanmakuWidth) {
    for (var item in _scrollDanmakuItems) {
      if (item.yPosition == yPosition) {
        final existingEndPosition = item.xPosition + item.width;
        // 首先保证进入屏幕时不发生重叠，其次保证知道移出屏幕前不与速度慢的弹幕(弹幕宽度较小)发生重叠
        if (_viewWidth - existingEndPosition < 0) {
          return false;
        }
        if (item.width < newDanmakuWidth) {
          if ((1 -
                  ((_viewWidth - item.xPosition) / (item.width + _viewWidth))) >
              ((_viewWidth) / (_viewWidth + newDanmakuWidth))) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /// 确定顶部弹幕是否可以添加
  bool _topCanAddToTrack(double yPosition) {
    for (var item in _topDanmakuItems) {
      if (item.yPosition == yPosition) {
        return false;
      }
    }
    return true;
  }

  /// 确定底部弹幕是否可以添加
  bool _bottomCanAddToTrack(double yPosition) {
    for (var item in _bottomDanmakuItems) {
      if (item.yPosition == yPosition) {
        return false;
      }
    }
    return true;
  }

  // 基于Stopwatch的计时器同步
  void _startTick() async {
    // _stopwatch.reset();
    _stopwatch.start();

    final staticDuration = _option.duration * 1000;

    while (_running && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      // 移除屏幕外滚动弹幕
      _scrollDanmakuItems
          .removeWhere((item) => item.xPosition + item.width < 0);
      // 移除顶部弹幕
      _topDanmakuItems
          .removeWhere((item) => (_tick - item.creationTime) >= staticDuration);
      // 移除底部弹幕
      _bottomDanmakuItems
          .removeWhere((item) => (_tick - item.creationTime) >= staticDuration);
      // 移除高级弹幕
      _specialDanmakuItems.removeWhere((item) =>
          (_tick - item.creationTime) >=
          (item.content as SpecialDanmakuContentItem).duration);
      // 暂停动画
      if (_scrollDanmakuItems.isEmpty &&
          _specialDanmakuItems.isEmpty &&
          _animationController.isAnimating) {
        _animationController.stop();
      }

      /// 重绘静态弹幕
      if (mounted) {
        setState(() {
          _staticAnimationController.value = 0;
        });
      }
    }

    _stopwatch.stop();
  }

  @override
  Widget build(BuildContext context) {
    /// 计算弹幕轨道
    final textPainter = TextPainter(
      text: TextSpan(text: '弹幕', style: TextStyle(fontSize: _option.fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    if (_option.itemFixedHeight > 0) {
      final base = _option.itemFixedHeight;
      final avatarH = _option.enableAvatar ? _option.avatarSize : 0.0;
      _danmakuHeight = max(base, avatarH).toDouble();
    } else {
      final baseHeight = _option.enableAvatar
          ? max(textPainter.height, _option.avatarSize)
          : textPainter.height;
      _danmakuHeight = _option.enableItemBackground
          ? baseHeight + (_option.itemPaddingVertical * 2)
          : baseHeight;
    }
    return LayoutBuilder(builder: (context, constraints) {
      /// 计算视图宽度
      if (constraints.maxWidth != _viewWidth) {
        _viewWidth = constraints.maxWidth;
      }

      final double effectiveHeight = constraints.maxHeight * _option.area;
      _trackCount = (effectiveHeight / _danmakuHeight).floor();

      /// 为字幕留出余量
      if (_option.safeArea && _option.area == 1.0) {
        _trackCount = _trackCount - 1;
      }

      _trackYPositions.clear();
      if (_trackCount > 0) {
        if (_option.stretchTracks && _trackCount > 1) {
          final double leftover = effectiveHeight - (_trackCount * _danmakuHeight);
          final double gap = leftover > 0 ? (leftover / (_trackCount - 1)) : 0;
          for (int i = 0; i < _trackCount; i++) {
            _trackYPositions.add(i * (_danmakuHeight + gap));
          }
        } else {
          for (int i = 0; i < _trackCount; i++) {
            _trackYPositions.add(i * _danmakuHeight);
          }
        }
      }
      return ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (d) => _handleTapDown(d, Size(constraints.maxWidth, constraints.maxHeight)),
          child: IgnorePointer(
            ignoring: !_option.enableTap,
            child: Opacity(
              opacity: _option.opacity,
              child: Stack(children: [
              RepaintBoundary(
                  child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ScrollDanmakuPainter(
                        _animationController.value,
                        _scrollDanmakuItems,
                        _option.duration,
                        _option.fontSize,
                        _option.fontWeight,
                        _option.showStroke,
                        _danmakuHeight,
                        _running,
                        _tick,
                        option: _option),
                    child: Container(),
                  );
                },
              )),
              RepaintBoundary(
                  child: AnimatedBuilder(
                animation: _staticAnimationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: StaticDanmakuPainter(
                        _staticAnimationController.value,
                        _topDanmakuItems,
                        _bottomDanmakuItems,
                        _option.duration,
                        _option.fontSize,
                        _option.fontWeight,
                        _option.showStroke,
                        _danmakuHeight,
                        _running,
                        _tick,
                        option: _option),
                    child: Container(),
                  );
                },
              )),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animationController, // 与滚动弹幕共用控制器
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SpecialDanmakuPainter(
                          _animationController.value,
                          _specialDanmakuItems,
                          _option.fontSize,
                          _option.fontWeight,
                          _running,
                          _tick),
                      child: Container(),
                    );
                  },
                ),
              ),
            ]),
            ),
          ),
        ),
      );
    });
  }
}
