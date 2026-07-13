import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WidgetHighlighter {
  final WidgetTester tester;
  final Color defaultHighlightColor;

  WidgetHighlighter(this.tester, {required this.defaultHighlightColor});

  Future<void> highlightWidget(
    Finder finder, {
    Color? colorOverride,
    double padding = 0.0,
  }) async {
    await _insertHighlight(
      tester.getRect(finder).inflate(padding),
      tester.element(finder),
      colorOverride,
    );
  }

  Future<void> highlightWidgets(
    List<Finder> finders, {
    Color? colorOverride,
    double padding = 0.0,
  }) async {
    final rect = finders
        .map((finder) => tester.getRect(finder))
        .reduce((a, b) => a.expandToInclude(b))
        .inflate(padding);

    await _insertHighlight(rect, tester.element(finders.first), colorOverride);
  }

  Future<void> _insertHighlight(
    Rect rect,
    BuildContext context,
    Color? colorOverride,
  ) async {
    Overlay.of(context).insert(
      OverlayEntry(
        builder: (context) => Positioned.fromRect(
          rect: rect,
          child: CustomPaint(
            painter: _HighlightBorderPainter(
              colorOverride ?? defaultHighlightColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightBorderPainter extends CustomPainter {
  static const _borderWidth = 3.0;
  static const _borderRadius = Radius.circular(8);

  final Color color;

  _HighlightBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      _borderRadius,
    ).deflate(_borderWidth / 2);

    canvas.drawRRect(
      rrect.shift(Offset(_borderWidth / 2, _borderWidth)),
      Paint()
        ..color = Colors.black.withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlightBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
