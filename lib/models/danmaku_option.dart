import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';

class DanmakuOption {
  /// 默认的字体大小
  final double fontSize;

  /// 字体粗细
  final int fontWeight;

  /// 显示区域，0.1-1.0
  final double area;

  /// 滚动弹幕运行时间，秒
  final int duration;

  /// 不透明度，0.1-1.0
  final double opacity;

  /// 隐藏顶部弹幕
  final bool hideTop;

  /// 隐藏底部弹幕
  final bool hideBottom;

  /// 隐藏滚动弹幕
  final bool hideScroll;

  final bool hideSpecial;

  /// 弹幕描边
  final bool showStroke;

  /// 海量弹幕模式 (弹幕轨道占满时进行叠加)
  final bool massiveMode;

  /// 为字幕预留空间
  final bool safeArea;

  final bool enableItemBackground;
  final double itemPaddingHorizontal;
  final double itemPaddingVertical;
  final Color itemBackgroundColor;
  final Color itemBorderColor;
  final double itemBorderWidth;
  final double itemBorderRadius;
  final Color itemShadowColor;
  final double itemShadowBlurRadius;
  final Offset itemShadowOffset;

  final bool enableAvatar;
  final double avatarSize;
  final double avatarGap;
  final Color avatarBorderColor;
  final double avatarBorderWidth;

  final double itemFixedHeight;
  final bool avatarOverlayOnLeft;

  final bool randomTrack;

  final bool stretchTracks;

  final bool enableTap;
  final void Function(DanmakuContentItem item)? onAvatarTap;
  final void Function(DanmakuContentItem item, DanmakuTextSpan span, int index)?
      onHighlightTap;

  DanmakuOption({
    this.fontSize = 16,
    this.fontWeight = 4,
    this.area = 1.0,
    this.duration = 10,
    this.opacity = 1.0,
    this.hideBottom = false,
    this.hideScroll = false,
    this.hideTop = false,
    this.hideSpecial = false,
    this.showStroke = true,
    this.massiveMode = false,
    this.safeArea = true,
    this.enableItemBackground = false,
    this.itemPaddingHorizontal = 0,
    this.itemPaddingVertical = 0,
    this.itemBackgroundColor = const Color(0x80FFFFFF),
    this.itemBorderColor = const Color(0xFFFFFFFF),
    this.itemBorderWidth = 0,
    this.itemBorderRadius = 0,
    this.itemShadowColor = const Color(0x00000000),
    this.itemShadowBlurRadius = 0,
    this.itemShadowOffset = Offset.zero,
    this.enableAvatar = false,
    this.avatarSize = 36,
    this.avatarGap = 6,
    this.avatarBorderColor = const Color(0xFFFFFFFF),
    this.avatarBorderWidth = 1,
    this.itemFixedHeight = 0,
    this.avatarOverlayOnLeft = false,

    this.randomTrack = false,

    this.stretchTracks = false,

    this.enableTap = false,
    this.onAvatarTap,
    this.onHighlightTap,
  });

  DanmakuOption copyWith({
    double? fontSize,
    int? fontWeight,
    double? area,
    int? duration,
    double? opacity,
    bool? hideTop,
    bool? hideBottom,
    bool? hideScroll,
    bool? showStroke,
    bool? massiveMode,
    bool? safeArea,
    bool? enableItemBackground,
    double? itemPaddingHorizontal,
    double? itemPaddingVertical,
    Color? itemBackgroundColor,
    Color? itemBorderColor,
    double? itemBorderWidth,
    double? itemBorderRadius,
    Color? itemShadowColor,
    double? itemShadowBlurRadius,
    Offset? itemShadowOffset,

    bool? enableAvatar,
    double? avatarSize,
    double? avatarGap,
    Color? avatarBorderColor,
    double? avatarBorderWidth,

    double? itemFixedHeight,
    bool? avatarOverlayOnLeft,

    bool? randomTrack,

    bool? stretchTracks,

    bool? enableTap,
    void Function(DanmakuContentItem item)? onAvatarTap,
    void Function(DanmakuContentItem item, DanmakuTextSpan span, int index)?
        onHighlightTap,
  }) {
    return DanmakuOption(
      area: area ?? this.area,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      duration: duration ?? this.duration,
      opacity: opacity ?? this.opacity,
      hideTop: hideTop ?? this.hideTop,
      hideBottom: hideBottom ?? this.hideBottom,
      hideScroll: hideScroll ?? this.hideScroll,
      showStroke: showStroke ?? this.showStroke,
      massiveMode: massiveMode ?? this.massiveMode,
      safeArea: safeArea ?? this.safeArea,
      enableItemBackground: enableItemBackground ?? this.enableItemBackground,
      itemPaddingHorizontal: itemPaddingHorizontal ?? this.itemPaddingHorizontal,
      itemPaddingVertical: itemPaddingVertical ?? this.itemPaddingVertical,
      itemBackgroundColor: itemBackgroundColor ?? this.itemBackgroundColor,
      itemBorderColor: itemBorderColor ?? this.itemBorderColor,
      itemBorderWidth: itemBorderWidth ?? this.itemBorderWidth,
      itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
      itemShadowColor: itemShadowColor ?? this.itemShadowColor,
      itemShadowBlurRadius: itemShadowBlurRadius ?? this.itemShadowBlurRadius,
      itemShadowOffset: itemShadowOffset ?? this.itemShadowOffset,

      enableAvatar: enableAvatar ?? this.enableAvatar,
      avatarSize: avatarSize ?? this.avatarSize,
      avatarGap: avatarGap ?? this.avatarGap,
      avatarBorderColor: avatarBorderColor ?? this.avatarBorderColor,
      avatarBorderWidth: avatarBorderWidth ?? this.avatarBorderWidth,

      itemFixedHeight: itemFixedHeight ?? this.itemFixedHeight,
      avatarOverlayOnLeft: avatarOverlayOnLeft ?? this.avatarOverlayOnLeft,

      randomTrack: randomTrack ?? this.randomTrack,

      stretchTracks: stretchTracks ?? this.stretchTracks,

      enableTap: enableTap ?? this.enableTap,
      onAvatarTap: onAvatarTap ?? this.onAvatarTap,
      onHighlightTap: onHighlightTap ?? this.onHighlightTap,
    );
  }
}
