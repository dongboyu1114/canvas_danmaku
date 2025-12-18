import 'package:canvas_danmaku/utils/utils.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models/danmaku_item.dart';
import 'models/danmaku_option.dart';

class ScrollDanmakuPainter extends CustomPainter {
  final double progress;
  final List<DanmakuItem> scrollDanmakuItems;
  final int danmakuDurationInSeconds;
  final double fontSize;
  final int fontWeight;
  final bool showStroke;
  final double danmakuHeight;
  final bool running;
  final int tick;
  final int batchThreshold;

  final DanmakuOption option;

  final double totalDuration;
  final Paint selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.green;

  ScrollDanmakuPainter(
    this.progress,
    this.scrollDanmakuItems,
    this.danmakuDurationInSeconds,
    this.fontSize,
    this.fontWeight,
    this.showStroke,
    this.danmakuHeight,
    this.running,
    this.tick, {
    this.batchThreshold = 10, // 默认值为10，可以自行调整
    DanmakuOption? option,
  })  : option = option ?? DanmakuOption(),
        totalDuration = danmakuDurationInSeconds * 1000;

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

  double _paragraphWidth(DanmakuItem item) {
    if (!option.enableItemBackground) return item.width;
    final w =
        item.width - (option.itemPaddingHorizontal * 2) - _avatarSpace(item) - _overlayTextInset(item);
    if (w <= 0) return item.width;
    return w;
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

  void _drawAvatar(Canvas canvas, DanmakuItem item, Offset itemOffset, Size size) {
    if (!option.enableAvatar) return;
    if (item.content.avatarUrl == null) return;
    final img = item.avatarImage;

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

    // 占位：避免头像网络图片加载完成瞬间出现导致闪烁
    if (img == null) {
      final bgPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.25);
      canvas.drawCircle(rect.center, avatarSize / 2, bgPaint);
      if (option.avatarBorderWidth > 0) {
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = option.avatarBorderColor
          ..strokeWidth = option.avatarBorderWidth;
        canvas.drawCircle(rect.center, avatarSize / 2, borderPaint);
      }
      return;
    }

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
    final startPosition = size.width;
    final double offscreenTolerance =
        option.avatarOverlayOnLeft ? (option.avatarSize / 2) : 0.0;

    if (scrollDanmakuItems.length > batchThreshold) {
      // 弹幕数量超过阈值时使用批量绘制
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas pictureCanvas = Canvas(pictureRecorder);

      for (var item in scrollDanmakuItems) {
        item.lastDrawTick ??= item.creationTime;
        final endPosition = -item.width;
        final distance = startPosition - endPosition;
        item.xPosition = item.xPosition +
            (((item.lastDrawTick! - tick) / totalDuration) * distance);

        if (item.xPosition < -item.width ||
            item.xPosition > size.width + offscreenTolerance) {
          continue;
        }

        _drawItemBackground(
          pictureCanvas,
          item,
          Offset(item.xPosition, item.yPosition),
        );

        _drawAvatar(
          pictureCanvas,
          item,
          Offset(item.xPosition, item.yPosition),
          size,
        );

        item.paragraph ??= Utils.generateParagraph(
            item.content, _paragraphWidth(item), fontSize, fontWeight);

        if (showStroke) {
          item.strokeParagraph ??= Utils.generateStrokeParagraph(
              item.content, _paragraphWidth(item), fontSize, fontWeight);
          pictureCanvas.drawParagraph(
            item.strokeParagraph!,
            _textOffset(
              item,
              Offset(item.xPosition, item.yPosition),
              item.strokeParagraph!,
            ),
          );
        }

        if (item.content.selfSend) {
          pictureCanvas.drawRect(
              Offset(item.xPosition, item.yPosition).translate(-2, 2) &
                  (Size(item.width, item.height) + const Offset(4, 0)),
              selfSendPaint);
        }

        pictureCanvas.drawParagraph(
          item.paragraph!,
          _textOffset(
            item,
            Offset(item.xPosition, item.yPosition),
            item.paragraph!,
          ),
        );
        item.lastDrawTick = tick;
      }

      final ui.Picture picture = pictureRecorder.endRecording();
      canvas.drawPicture(picture);
    } else {
      // 弹幕数量较少时直接绘制 (节约创建 canvas 的开销)
      for (var item in scrollDanmakuItems) {
        item.lastDrawTick ??= item.creationTime;
        final endPosition = -item.width;
        final distance = startPosition - endPosition;
        item.xPosition = item.xPosition +
            (((item.lastDrawTick! - tick) / totalDuration) * distance);

        if (item.xPosition < -item.width ||
            item.xPosition > size.width + offscreenTolerance) {
          continue;
        }

        _drawItemBackground(
          canvas,
          item,
          Offset(item.xPosition, item.yPosition),
        );

        _drawAvatar(
          canvas,
          item,
          Offset(item.xPosition, item.yPosition),
          size,
        );

        item.paragraph ??= Utils.generateParagraph(
            item.content, _paragraphWidth(item), fontSize, fontWeight);

        if (showStroke) {
          item.strokeParagraph ??= Utils.generateStrokeParagraph(
              item.content, _paragraphWidth(item), fontSize, fontWeight);
          canvas.drawParagraph(
            item.strokeParagraph!,
            _textOffset(
              item,
              Offset(item.xPosition, item.yPosition),
              item.strokeParagraph!,
            ),
          );
        }

        if (item.content.selfSend) {
          canvas.drawRect(
              Offset(item.xPosition, item.yPosition).translate(-2, 2) &
                  (Size(item.width, item.height) + const Offset(4, 0)),
              selfSendPaint);
        }

        canvas.drawParagraph(
          item.paragraph!,
          _textOffset(
            item,
            Offset(item.xPosition, item.yPosition),
            item.paragraph!,
          ),
        );
        item.lastDrawTick = tick;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
