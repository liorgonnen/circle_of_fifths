import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math';

const _two_pi = 2 * pi;
const _segments = 12;
const _halfSegments = _segments / 2;
const _top = -pi / 2;
const _sliceAngle = 2 * pi / 12;
const _outerFontSizeScale = 0.8;
const _innerFontSizeScale = 0.5;
const _majorKeys = ["C", "G", "D", "A", "E", "B", "F#\nGb", "Db", "Ab", "Ab", "Eb", "Bb", "F"];
const _relativeMinors = ["Am", "Em", "Bm", "F#m", "C#m", "G#m", "D#m\nEbm", "Bbm", "Fm", "Cm", "Gm", "Dm"];
final _colors = [ 0x29617C, 0x289FAF, 0xD8DBB9, 0xEAB069, 0xF2594C].map((hex) => Color(0xff000000 | hex)).toList();

class Selection implements Comparable<Selection> {
  static final none = Selection(circleIndex: -1, segment: -1);

  final int circleIndex; // 0 = inner, 1 = outer
  final int segment;

  Selection({
    @required int circleIndex,
    @required int segment
  }) : this.circleIndex = circleIndex, this.segment = segment;

  @override
  int get hashCode => circleIndex * _segments + segment;

  @override
  bool operator ==(Object other) => other != null && other is Selection && other.segment == segment && other.circleIndex == circleIndex;

  @override
  int compareTo(Selection other) => hashCode - other.hashCode;
}

class CircleParams {
  final Size _size;

  const CircleParams(Size size) : _size = size;

  Offset get center => _size.center(Offset.zero);
  double get outerRadius => _size.shortestSide / 2.0;
  double get midRadius => outerRadius * 0.7;
  double get innerRadius => outerRadius * 0.4;
  double get spaceWidth => outerRadius * 0.02;
}

class CircleOfFifths extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => CircleOfFifthState();
}

class CircleOfFifthState extends State<CircleOfFifths> with TickerProviderStateMixin {

  var _position = Offset.zero;
  var _currentHover = Selection.none;
  var _circle = CircleParams(Size.zero);
  
  var _animationMap = HashMap<Selection, AnimationController>();

  void _beginTracking(Size size, Offset position) => setState(() {
    _position = position;
    _circle = CircleParams(size);
    _updateSelection();
  });

  void _updateTracking(Size size, Offset position) => setState(() {
    _position = position;
    _updateSelection();
  });

  /// Workaround for [https://github.com/flutter/flutter/issues/33675]
  /// MouseRegion pointer localPosition doesn't transform to widget's local coordinate system
  Offset _transform(BuildContext context, Offset globalPosition) {
    var position = context.findRenderObject().getTransformTo(null).getTranslation().xy;
    return globalPosition - Offset(position.x, position.y);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (pointer) => _beginTracking(context.size, _transform(context, pointer.position)),
      onHover: (pointer) => _updateTracking(context.size, _transform(context, pointer.position)),
      child: CustomPaint(
        painter: CircleOfFifthsPainter(),
        child: Stack(
          children: _animationMap.entries.map((entry) =>
              AnimatedBuilder(
                animation: entry.value,
                builder: (BuildContext context, Widget child) {
                  return CustomPaint(
                    painter: CirceOfFifthsStatePainter(entry.key, entry.value.value),
                    child: Container(
                      width: 500,
                      height: 500,
                    )
                  );
                },
              )).toList()
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationMap.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _updateSelection() {
    final positionVector = _position - _circle.center;
    final radius = positionVector.distance;
    final angle = (positionVector.direction - _top + _two_pi) % _two_pi;
    final segmentIndex = (angle / _sliceAngle).round() % _segments;
    var currentSelection = Selection.none;

    if (radius >= _circle.innerRadius && radius <= _circle.midRadius) {
      currentSelection = Selection(circleIndex: 0, segment: segmentIndex);
    }
    else if (radius >= _circle.midRadius + _circle.spaceWidth && radius <= _circle.outerRadius) {
      currentSelection = Selection(circleIndex: 1, segment: segmentIndex);
    }

    if (currentSelection != Selection.none) {
      if (currentSelection == _currentHover) {
        return;
      }

      var currentHover = _currentHover;
      var previousHoverController = _animationMap[currentHover];
      previousHoverController?.reverse()?.then<void>((_) {
        _animationMap.remove(currentHover).dispose();
        setState(() { });
      });

      _currentHover = currentSelection;

      if (_animationMap[currentSelection] == null) {
        var controller = AnimationController(
            vsync: this,
            duration: Duration(milliseconds: 100),
            lowerBound: 1.0,
            upperBound: 1.1,
        );
        _animationMap[currentSelection] = controller;

        controller.forward();
      }
    }
  }
}

abstract class BaseCirclePainter extends CustomPainter {

  @override
  @nonVirtual
  void paint(Canvas canvas, Size size) => _onPaint(canvas, CircleParams(size));

  void _onPaint(Canvas canvas, CircleParams circleParams);

  void _drawText(Canvas canvas, Offset center, double angle, double radius, String text, double textSize) {
    final offset = center + Offset(cos(angle) * radius, sin(angle) * radius);
    final span = TextSpan(style: TextStyle(fontSize: textSize, color: Colors.white), text: text);
    final textPainter = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, offset - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  Paint createArcPaint(Color color, double strokeWidth) => Paint()
    ..color = color
    ..strokeCap = StrokeCap.butt
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  Color sliceColor(int index, {bool isHover = false, bool isSelected = false}) {
    final numColors = _colors.length;
    final baseIndex = (index / _segments) * numColors;
    final color1Index = baseIndex.toInt();
    final color2Index = (color1Index + 1) % numColors;
    final fraction = baseIndex - color1Index;

    return Color.lerp(_colors[color1Index], _colors[color2Index], fraction);
  }
}

class CirceOfFifthsStatePainter extends BaseCirclePainter {
  final Selection _selection;
  final double _scale;

  CirceOfFifthsStatePainter(Selection selection, double scale) : _selection = selection, _scale = scale;

  @override
  void _onPaint(Canvas canvas, CircleParams c) {
    assert(_selection != Selection.none);

    final index = _selection.segment;
    final baseColor = HSVColor.fromColor(sliceColor(index));
    final color = baseColor.withValue(min(1.0, baseColor.value * _scale)).toColor();
    if (_selection.circleIndex == 0) {
      drawKey(canvas, c.center, c.innerRadius, c.midRadius, _innerFontSizeScale, _relativeMinors[index], index, color, _scale);
    }
    else {
      drawKey(canvas, c.center, c.midRadius + c.spaceWidth, c.outerRadius, _outerFontSizeScale, _majorKeys[index], index, color, _scale);
    }
  }

  void drawKey(Canvas canvas, Offset center, double innerRadius, double outerRadius, double fontSizeScale, String key, int index, Color color, double scale) {
    final strokeWidth = outerRadius - innerRadius;
    final rect = Rect.fromCircle(center: center, radius: (outerRadius - strokeWidth / 2) / scale);
    final startAngle = _top - _sliceAngle / 2 + _sliceAngle * index - _sliceAngle * (scale - 1);
    final endAngle = _sliceAngle + _sliceAngle * (scale - 1) * 2;
    final radius = (innerRadius + outerRadius) / 2 / scale;
    final textSize = (outerRadius - innerRadius) / 2 * fontSizeScale * scale;
    final shadowPaint = createArcPaint(Color(0xaa333333), strokeWidth)..maskFilter = MaskFilter.blur(BlurStyle.outer, outerRadius / 50.0);

    canvas.translate((1 - scale) * center.dx, (1 - scale) * center.dy);
    canvas.scale(scale);
    canvas.drawArc(rect, startAngle, endAngle, false, shadowPaint);
    canvas.drawArc(rect, startAngle, endAngle, false, createArcPaint(color, strokeWidth));
    _drawText(canvas, center, _top + index * _sliceAngle, radius, key, textSize);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class CircleOfFifthsPainter extends BaseCirclePainter {

  @override
  void _onPaint(Canvas canvas, CircleParams c) {
    // Workaround for https://github.com/flutter/flutter/issues/44572
    if (!kIsWeb) {
      canvas.clipPath(buildClipPath(c));
    }

    drawCircle(canvas, c.center, c.midRadius + c.spaceWidth, c.outerRadius, _outerFontSizeScale, _majorKeys);
    drawCircle(canvas, c.center, c.innerRadius, c.midRadius, _innerFontSizeScale, _relativeMinors);
  }

  Path buildClipPath(CircleParams c) {
    var clipPath = Path();
    var clipTransform = Matrix4.identity();
    clipTransform.translate(c.center.dx, c.center.dy);
    clipTransform.rotateZ(-_sliceAngle / 2);

    for (var n = 0; n < _halfSegments; n++) {
      clipTransform.rotateZ(_sliceAngle);
      var rect = Path()..addRect(Rect.fromCenter(center: Offset.zero, width: c.spaceWidth, height: c.outerRadius * 2));
      clipPath.addPath(rect, Offset.zero, matrix4: clipTransform.storage);
    }

    var fullClip = Path()..addOval(Rect.fromCircle(center: c.center, radius: c.outerRadius));
    return Path.combine(PathOperation.difference, fullClip, clipPath);
  }

  void drawCircle(Canvas canvas, Offset center, double innerRadius, double outerRadius, double fontSizeScale, List<String> keys) {

    final strokeWidth = outerRadius - innerRadius;
    final rect = Rect.fromCircle(center: center, radius: outerRadius - strokeWidth / 2);

    for (var n = 0; n < _segments; n++) {
      final linePaint = createArcPaint(sliceColor(n), strokeWidth);
      final startAngle = _top - _sliceAngle / 2 + _sliceAngle * n;
      canvas.drawArc(rect, startAngle, _sliceAngle, false, linePaint);
      _drawText(canvas, center, _top + n * _sliceAngle, (innerRadius + outerRadius) / 2, keys[n], (outerRadius - innerRadius) / 2 * fontSizeScale);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
