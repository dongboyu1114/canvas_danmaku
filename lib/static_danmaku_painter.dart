import 'package:canvas_danmaku/utils/utils.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models/danmaku_item.dart';
import 'models/danmaku_option.dart';

class StaticDanmakuPainter extends CustomPainter {
  final double progress;
  final List<DanmakuItem> topDanmakuItems;
  final List<DanmakuItem> buttomDanmakuItems;
  final int danmakuDurationInSeconds;
  final double fontSize;
  final int fontWeight;
  final bool showStroke;
  final double danmakuHeight;
  final bool running;
  final int tick;
  final DanmakuOption option;
  final Paint selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.green;

  StaticDanmakuPainter(
      this.progress,
      this.topDanmakuItems,
      this.buttomDanmakuItems,
      this.danmakuDurationInSeconds,
      this.fontSize,
      this.fontWeight,
      this.showStroke,
      this.danmakuHeight,
      this.running,
      this.tick,
      {DanmakuOption? option})
      : option = option ?? DanmakuOption();

  double _avatarSpace(DanmakuItem item) {
    if (!option.enableAvatar) return 0;
    if (item.content.avatarUrl == null) return 0;
    if (option.avatarOverlayOnLeft) return 0;
    return option.avatarSize + option.avatarGap;
  }

  double _cardHeight(DanmakuItem item) {
    if (!option.enableItemBackground) return item.height;
    if (option.itemFixedHeight > 0) return option.itemFixedHeight;
    return item.height;
  }

  double _cardTop(DanmakuItem item, Offset itemOffset) {
    final h = _cardHeight(item);
    return itemOffset.dy + (item.height - h) / 2;
  }

  double _overlayTextInset(DanmakuItem item) {
    if (!option.enableAvatar) return 0;
    if (!option.avatarOverlayOnLeft) return 0;
    if (item.content.avatarUrl == null) return 0;
    final base = option.avatarSize / 2 + option.avatarGap;
    final pad = option.enableItemBackground ? option.itemPaddingHorizontal : 0;
    final inset = base - pad;
    return inset > 0 ? inset : 0;
  }

  void _drawItemBackground(Canvas canvas, DanmakuItem item, Offset offset) {
    if (!option.enableItemBackground) return;

    final cardHeight = _cardHeight(item);
    final cardTop = _cardTop(item, offset);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, cardTop, item.width, cardHeight),
      Radius.circular(option.itemBorderRadius),
    );

    if (option.itemShadowBlurRadius > 0) {
      final shadowPaint = Paint()
        ..color = option.itemShadowColor
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          option.itemShadowBlurRadius,
        );

      canvas.drawRRect(
        rrect.shift(option.itemShadowOffset),
        shadowPaint,
      );
    }

    final bgPaint = Paint()..color = option.itemBackgroundColor;
    canvas.drawRRect(rrect, bgPaint);

    if (option.itemBorderWidth > 0) {
      final borderPaint = Paint()
        ..color = option.itemBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = option.itemBorderWidth;
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  double _paragraphWidth(DanmakuItem item) {
    if (!option.enableItemBackground) return item.width;
    final w =
        item.width - (option.itemPaddingHorizontal * 2) - _avatarSpace(item) - _overlayTextInset(item);
    if (w <= 0) return item.width;
    return w;
  }

  void _drawAvatar(Canvas canvas, DanmakuItem item, Offset itemOffset) {
    if (!option.enableAvatar) return;
    if (item.content.avatarUrl == null) return;
    final img = item.avatarImage;
    if (img == null) return;

    final hasBg = option.enableItemBackground;
    final contentTop = itemOffset.dy;
    final contentHeight = item.height;
    final avatarSize = option.avatarSize;
    final avatarTop = contentTop + (contentHeight - avatarSize) / 2;
    final avatarLeft = option.avatarOverlayOnLeft
        ? (itemOffset.dx - avatarSize / 2)
        : (itemOffset.dx + (hasBg ? option.itemPaddingHorizontal : 0));

    final rect = Rect.fromLTWH(
      avatarLeft,
      avatarTop,
      avatarSize,
      avatarSize,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    paintImage(
      canvas: canvas,
      rect: rect,
      image: img,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();

    if (option.avatarBorderWidth > 0) {
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = option.avatarBorderColor
        ..strokeWidth = option.avatarBorderWidth;
      canvas.drawCircle(rect.center, avatarSize / 2, borderPaint);
    }
  }

  Offset _textOffset(DanmakuItem item, Offset itemOffset, ui.Paragraph paragraph) {
    final hasBg = option.enableItemBackground;
    final cardTop = _cardTop(item, itemOffset);
    final cardHeight = _cardHeight(item);
    final contentTop = cardTop + (hasBg ? option.itemPaddingVertical : 0);
    final contentHeight =
        cardHeight - (hasBg ? (option.itemPaddingVertical * 2) : 0);
    final textTop = contentTop + (contentHeight - paragraph.height) / 2;

    return Offset(
      itemOffset.dx +
          (hasBg ? option.itemPaddingHorizontal : 0) +
          _avatarSpace(item) +
          _overlayTextInset(item),
      textTop,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制顶部弹幕
    for (var item in topDanmakuItems) {
      item.xPosition = (size.width - item.width) / 2;
      // 如果 Paragraph 没有缓存，则创建并缓存它
      item.paragraph ??= Utils.generateParagraph(
          item.content, _paragraphWidth(item), fontSize, fontWeight);

      _drawItemBackground(canvas, item, Offset(item.xPosition, item.yPosition));

      _drawAvatar(canvas, item, Offset(item.xPosition, item.yPosition));

      // 黑色部分
      if (showStroke) {
        item.strokeParagraph ??= Utils.generateStrokeParagraph(
            item.content, _paragraphWidth(item), fontSize, fontWeight);

        canvas.drawParagraph(
            item.strokeParagraph!,
            _textOffset(
              item,
              Offset(item.xPosition, item.yPosition),
              item.strokeParagraph!,
            ));
      }

      if (item.content.selfSend) {
        canvas.drawRect(
            Offset(item.xPosition, item.yPosition).translate(-2, 2) &
                (Size(item.width, item.height) + const Offset(4, 0)),
            selfSendPaint);
      }
      // 白色部分
      canvas.drawParagraph(
          item.paragraph!,
          _textOffset(
            item,
            Offset(item.xPosition, item.yPosition),
            item.paragraph!,
          ));
    }
    // 绘制底部弹幕 (翻转绘制)
    for (var item in buttomDanmakuItems) {
      item.xPosition = (size.width - item.width) / 2;
      // 如果 Paragraph 没有缓存，则创建并缓存它
      item.paragraph ??= Utils.generateParagraph(
          item.content, _paragraphWidth(item), fontSize, fontWeight);

      final bottomY = size.height - item.yPosition - danmakuHeight;

      _drawItemBackground(canvas, item, Offset(item.xPosition, bottomY));

      _drawAvatar(canvas, item, Offset(item.xPosition, bottomY));

      // 黑色部分
      if (showStroke) {
        item.strokeParagraph ??= Utils.generateStrokeParagraph(
            item.content, _paragraphWidth(item), fontSize, fontWeight);

        canvas.drawParagraph(
            item.strokeParagraph!,
            _textOffset(
              item,
              Offset(item.xPosition, bottomY),
              item.strokeParagraph!,
            ));
      }

      if (item.content.selfSend) {
        canvas.drawRect(
            Offset(item.xPosition,
                        (size.height - item.yPosition - danmakuHeight))
                    .translate(-2, 2) &
                (Size(item.width, item.height) + const Offset(4, 0)),
            selfSendPaint);
      }

      // 白色部分
      canvas.drawParagraph(
          item.paragraph!,
          _textOffset(
            item,
            Offset(item.xPosition, bottomY),
            item.paragraph!,
          ));
    }
  }

  @override
  bool shouldRepaint(covariant StaticDanmakuPainter oldDelegate) {
    return true;
  }
}
