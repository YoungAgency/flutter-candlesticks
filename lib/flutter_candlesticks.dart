import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OHLCVGraph extends StatefulWidget {
  OHLCVGraph({
    Key key,
    @required this.data,
    this.lineWidth = 1.0,
    this.fallbackHeight = 100.0,
    this.fallbackWidth = 300.0,
    this.gridLineColor = Colors.grey,
    this.gridLineAmount = 5,
    this.gridLineWidth = 0.5,
    this.gridLineLabelColor = Colors.grey,
    this.labelPrefix = "\$",
    this.onSelect,
    @required this.enableGridLines,
    @required this.volumeProp,
    this.increaseColor = Colors.green,
    this.decreaseColor = Colors.red,
    this.cursorColor = Colors.black,
    this.selectedPriceTextColor = Colors.white,
    this.lines = const [],
    this.formatFn,
    this.fullscreenGridLine = false,
  }) : super(key: key) {
    assert(data != null);
    if (fullscreenGridLine) {
      assert(enableGridLines);
    }
  }

  /// OHLCV data to graph  /// List of Maps containing open, high, low, close and volumeto
  /// Example: [["open" : 40.0, "high" : 75.0, "low" : 25.0, "close" : 50.0, "volumeto" : 5000.0}, {...}]
  final List data;

  final Function(dynamic) onSelect;

  /// All lines in chart are drawn with this width
  final double lineWidth;

  /// Enable or disable grid lines
  final bool enableGridLines;

  /// Color of grid lines and label text
  final Color gridLineColor;
  final Color gridLineLabelColor;

  /// Number of grid lines
  final int gridLineAmount;

  /// Width of grid lines
  final double gridLineWidth;

  /// Proportion of paint to be given to volume bar graph
  final double volumeProp;

  /// If graph is given unbounded space,
  /// it will default to given fallback height and width
  final double fallbackHeight;
  final double fallbackWidth;

  /// Symbol prefix for grid line labels
  final String labelPrefix;

  /// Increase color
  final Color increaseColor;

  /// Decrease color
  final Color decreaseColor;

  // CursorColor
  final Color cursorColor;

  final Color selectedPriceTextColor;

  // draw lines on chart
  final List<LineValue> lines;

  /// formatFn is applyed to all values displyed on chart if provided
  final FormatFn formatFn;

  final bool fullscreenGridLine;

  @override
  _OHLCVGraphState createState() => _OHLCVGraphState();
}

class _OHLCVGraphState extends State<OHLCVGraph> {
  final List pointsMappingX = List();
  final List pointsMappingY = List();
  double _cursorX = -1;
  double _cursorY = -1;
  double _cursorYPrice = 0;

  double _min = double.infinity;
  double _max = -double.infinity;
  double _maxVolume = -double.infinity;

  @override
  void initState() {
    super.initState();
    // calculate min max and _maxVolume
    for (var i in widget.data) {
      if (i["high"] > _max) {
        _max = i["high"].toDouble();
      }
      if (i["low"] < _min) {
        _min = i["low"].toDouble();
      }
      if (i["volumeto"] > _maxVolume) {
        _maxVolume = i["volumeto"].toDouble();
      }
    }
  }

  void _onUnselect() {
    if (this.widget.onSelect != null) {
      this.widget.onSelect(null);
    }
    setState(() {
      this._cursorX = -1;
      this._cursorY = -1;
    });
  }

  void _onPositionUpdate(Offset position) {
    // find candle index by coords
    var i = pointsMappingX.indexWhere(
        (el) => position.dx >= el["from"] && position.dx <= el["to"]);
    if (i == -1) {
      // candle is out of range or we are in candle padding
      i = pointsMappingX.indexWhere((el) => position.dx <= el["to"]);
      var i2 = pointsMappingX.indexWhere((el) => el["from"] >= position.dx);
      if (i == -1) {
        // out of range max, select the last candle
        i = pointsMappingX.length - 1;
      } else if (i2 <= 0) {
        // out of range min, select the first candle
        i = 0;
      } else {
        // trova la candela più vicina
        i2 -= 1; // il grande x minore di from
        // TODO se scatta troppo invertire pointsMappingX[i]["from"] con pointsMappingX[i]["to"] ecc
        var delta1 = (position.dx - pointsMappingX[i]["from"]).abs();
        var delta2 = (position.dx - pointsMappingX[i2]["to"]).abs();
        if (delta2 < delta1) {
          i = i2;
        }
      }
    }
    // update x cursor
    var el = pointsMappingX.elementAt(i);
    var widgetHeight = context.size.height;
    var myYPosition =
        (position.dy - widgetHeight + (widgetHeight * widget.volumeProp)) * -1;

    // calc chartHeight without volume part
    final double chartHeight = context.size.height * (1 - widget.volumeProp);
    var positionPrice = (((_max - _min) * myYPosition) / chartHeight) + _min;

    setState(() {
      // set cursox at the middle of the candle
      this._cursorX = (el["from"] + el["to"]) / 2;
      if (position.dy >= 0 && position.dy <= chartHeight) {
        this._cursorY = position.dy;
        widget.data[i]["selected_price"] = positionPrice;
      }
      if (position.dy < 0) {
        this._cursorY = 0;
        widget.data[i]["selected_price"] = _max;
      }
      if (position.dy > chartHeight) {
        this._cursorY = chartHeight;
        widget.data[i]["selected_price"] = _min;
      }
      _cursorYPrice = widget.data[i]["selected_price"];
    });

    // invoke onSelect with new values
    if (widget.onSelect != null) {
      var val = Map.from(widget.data[i]);
      this.widget.onSelect(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new LimitedBox(
      maxHeight: widget.fallbackHeight,
      maxWidth: widget.fallbackWidth,
      child: GestureDetector(
        onTapUp: (detail) {
          _onUnselect();
        },
        onTapDown: (detail) {
          _onPositionUpdate(detail.localPosition);
        },
        onHorizontalDragEnd: (detail) {
          _onUnselect();
        },
        onHorizontalDragStart: (detail) {
          _onPositionUpdate(detail.localPosition);
        },
        onHorizontalDragUpdate: (detail) {
          _onPositionUpdate(detail.localPosition);
        },
        onVerticalDragStart: (detail) {
          _onPositionUpdate(detail.localPosition);
        },
        onVerticalDragUpdate: (detail) {
          _onPositionUpdate(detail.localPosition);
        },
        onVerticalDragEnd: (detail) {
          _onUnselect();
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: new _OHLCVPainter(
            widget.data,
            lineWidth: widget.lineWidth,
            gridLineColor: widget.gridLineColor,
            gridLineAmount: widget.gridLineAmount,
            gridLineWidth: widget.gridLineWidth,
            gridLineLabelColor: widget.gridLineLabelColor,
            enableGridLines: widget.enableGridLines,
            volumeProp: widget.volumeProp,
            labelPrefix: widget.labelPrefix,
            increaseColor: widget.increaseColor,
            decreaseColor: widget.decreaseColor,
            cursorColor: widget.cursorColor,
            selectedPriceTextColor: widget.selectedPriceTextColor,
            pointsMappingX: pointsMappingX,
            pointsMappingY: pointsMappingY,
            lines: widget.lines,
            formatFn: widget.formatFn,
            cursorX: _cursorX,
            cursorY: _cursorY,
            cursorYPrice: _cursorYPrice,
            fullscreenGridLine: widget.fullscreenGridLine,
          ),
        ),
      ),
    );
  }
}

typedef FormatFn = String Function(double val);

class _OHLCVPainter extends CustomPainter {
  _OHLCVPainter(
    this.data, {
    @required this.lineWidth,
    @required this.enableGridLines,
    @required this.gridLineColor,
    @required this.gridLineAmount,
    @required this.gridLineWidth,
    @required this.gridLineLabelColor,
    @required this.volumeProp,
    @required this.labelPrefix,
    @required this.increaseColor,
    @required this.decreaseColor,
    @required this.cursorColor,
    @required this.selectedPriceTextColor,
    @required this.pointsMappingX,
    @required this.pointsMappingY,
    @required this.lines,
    this.formatFn,
    this.cursorX = -1,
    this.cursorY = -1,
    this.cursorYPrice = 0,
    this.fullscreenGridLine = false,
  });

  final List data;
  final double lineWidth;
  final bool enableGridLines;
  final Color gridLineColor;
  final int gridLineAmount;
  final double gridLineWidth;
  final Color gridLineLabelColor;
  final String labelPrefix;
  final double volumeProp;
  final Color increaseColor;
  final Color decreaseColor;

  final Color cursorColor;
  final Color selectedPriceTextColor;
  final List pointsMappingX;
  final List pointsMappingY;
  final List<LineValue> lines;
  final double cursorX;
  final double cursorY;
  final double cursorYPrice;

  final double valueLabelWidth = 60.0;
  final double valueLabelFontSize = 10.0;
  final double valueLabelHeight = 20.0; // this must be valueLabelFontSize*2

  final FormatFn formatFn;

  final bool fullscreenGridLine;

  double _min;
  double _max;
  double _maxVolume;

  TextPainter maxVolumePainter;

  numCommaParse(double n) {
    if (this.formatFn != null) {
      return this.formatFn(n);
    }
    var decimals = 2;
    if (n < 1) {
      decimals = 4;
    }
    return n.toStringAsFixed(decimals);
  }

  update() {
    _min = double.infinity;
    _max = -double.infinity;
    _maxVolume = -double.infinity;
    for (var i in data) {
      if (i["high"] > _max) {
        _max = i["high"].toDouble();
      }
      if (i["low"] < _min) {
        _min = i["low"].toDouble();
      }
      if (i["volumeto"] > _maxVolume) {
        _maxVolume = i["volumeto"].toDouble();
      }
    }

    if (enableGridLines) {
      // Label volume line
      maxVolumePainter = new TextPainter(
          text: new TextSpan(
              text: labelPrefix + numCommaParse(_maxVolume),
              style: new TextStyle(
                  color: gridLineLabelColor,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
      maxVolumePainter.layout();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_min == null || _max == null || _maxVolume == null) {
      update();
    }
    final double volumeHeight = size.height * volumeProp;
    final double volumeNormalizer = volumeHeight / _maxVolume;

    double width = size.width;
    final double height = size.height * (1 - volumeProp);

    if (enableGridLines) {
      if (!fullscreenGridLine) {
        width = size.width - valueLabelWidth;
      }
      double gridLineDist = height / (gridLineAmount - 1);
      double gridLineY;

      double gridLineValue;
      // Draw grid lines
      for (int i = 0; i < gridLineAmount; i++) {
        if (fullscreenGridLine) {
          // draw lines, text will be painted afterwards in order to put it over candles
          var gridLineY = (gridLineDist * i).round().toDouble();
          canvas.drawLine(
            Offset(0, gridLineY),
            Offset(size.width, gridLineY),
            Paint()..color = gridLineColor,
          );
        } else {
          gridLineValue = _max - (((_max - _min) / (gridLineAmount - 1)) * i);
          _drawValueLabel(
            canvas: canvas,
            size: size,
            value: gridLineValue,
            lineColor: gridLineColor,
            boxColor: Colors.transparent,
            textColor: gridLineLabelColor,
            dashed: false,
          );
        }
      }
      // Label volume line
      if (volumeProp > 0) {
        maxVolumePainter.paint(canvas, new Offset(8, gridLineY + 2.0));
      }
    }

    final double heightNormalizer = height / (_max - _min);
    final double rectWidth = width / data.length;

    double rectLeft;
    double rectTop;
    double rectRight;
    double rectBottom;

    Paint rectPaint;
    Paint candleVerticalLinePaint = new Paint()..strokeWidth = 1;
    pointsMappingX.clear();
    pointsMappingY.clear();
    // Loop through all data
    for (int i = 0; i < data.length; i++) {
      rectLeft = (i * rectWidth) + lineWidth / 2;
      rectRight = ((i + 1) * rectWidth) - lineWidth / 2;
      double volumeBarTop = (height + volumeHeight) -
          (data[i]["volumeto"] * volumeNormalizer - lineWidth / 2);
      double volumeBarBottom = height + volumeHeight + lineWidth / 2;

      if (data[i]["open"] > data[i]["close"]) {
        // Draw candlestick if decrease
        rectTop = height - (data[i]["open"] - _min) * heightNormalizer;
        rectBottom = height - (data[i]["close"] - _min) * heightNormalizer;
        rectPaint = new Paint()
          ..color = decreaseColor
          ..strokeWidth = lineWidth;

        Rect ocRect =
            new Rect.fromLTRB(rectLeft, rectTop, rectRight, rectBottom);
        canvas.drawRect(ocRect, rectPaint);

        // Draw volume bars
        Rect volumeRect = new Rect.fromLTRB(
            rectLeft, volumeBarTop, rectRight, volumeBarBottom);
        canvas.drawRect(volumeRect, rectPaint);

        candleVerticalLinePaint..color = decreaseColor;
      } else {
        // Draw candlestick if increase
        rectTop = (height - (data[i]["close"] - _min) * heightNormalizer) +
            lineWidth / 2;
        rectBottom = (height - (data[i]["open"] - _min) * heightNormalizer) -
            lineWidth / 2;
        rectPaint = new Paint()
          ..color = increaseColor
          ..strokeWidth = lineWidth;

        Rect ocRect =
            new Rect.fromLTRB(rectLeft, rectTop, rectRight, rectBottom);
        canvas.drawRect(ocRect, rectPaint);

        // Draw volume bars
        Rect volumeRect = new Rect.fromLTRB(
            rectLeft, volumeBarTop, rectRight, volumeBarBottom);
        canvas.drawRect(volumeRect, rectPaint);

        candleVerticalLinePaint..color = increaseColor;
        /*canvas.drawLine(new Offset(rectLeft, rectBottom - lineWidth / 2),
            new Offset(rectRight, rectBottom - lineWidth / 2), rectPaint);
        canvas.drawLine(new Offset(rectLeft, rectTop + lineWidth / 2),
            new Offset(rectRight, rectTop + lineWidth / 2), rectPaint);
        canvas.drawLine(new Offset(rectLeft + lineWidth / 2, rectBottom),
            new Offset(rectLeft + lineWidth / 2, rectTop), rectPaint);
        canvas.drawLine(new Offset(rectRight - lineWidth / 2, rectBottom),
            new Offset(rectRight - lineWidth / 2, rectTop), rectPaint);

        // Draw volume bars
        canvas.drawLine(new Offset(rectLeft, volumeBarBottom - lineWidth / 2),
            new Offset(rectRight, volumeBarBottom - lineWidth / 2), rectPaint);
        canvas.drawLine(new Offset(rectLeft, volumeBarTop + lineWidth / 2),
            new Offset(rectRight, volumeBarTop + lineWidth / 2), rectPaint);
        canvas.drawLine(new Offset(rectLeft + lineWidth / 2, volumeBarBottom),
            new Offset(rectLeft + lineWidth / 2, volumeBarTop), rectPaint);
        canvas.drawLine(new Offset(rectRight - lineWidth / 2, volumeBarBottom),
            new Offset(rectRight - lineWidth / 2, volumeBarTop), rectPaint);*/
      }

      // Draw low/high candlestick wicks
      double low = height - (data[i]["low"] - _min) * heightNormalizer;
      double high = height - (data[i]["high"] - _min) * heightNormalizer;
      canvas.drawLine(
          new Offset(rectLeft + rectWidth / 2 - lineWidth / 2, rectBottom),
          new Offset(rectLeft + rectWidth / 2 - lineWidth / 2, low),
          candleVerticalLinePaint);
      canvas.drawLine(
          new Offset(rectLeft + rectWidth / 2 - lineWidth / 2, rectTop),
          new Offset(rectLeft + rectWidth / 2 - lineWidth / 2, high),
          candleVerticalLinePaint);
      // add to pointsMapping
      pointsMappingX.add({"from": rectLeft, "to": rectRight});
      pointsMappingY.add({"from": low, "to": height});
    }

    if (enableGridLines && fullscreenGridLine) {
      for (int i = 0; i < gridLineAmount; i++) {
        double gridLineDist = height / (gridLineAmount - 1);
        var gridLineY = (gridLineDist * i).round().toDouble();
        var gridLineValue = _max - (((_max - _min) / (gridLineAmount - 1)) * i);
        // draw value paragraphs
        final Paragraph paragraph =
            _getParagraphBuilder(gridLineValue, gridLineLabelColor).build()
              ..layout(
                ParagraphConstraints(
                  width: valueLabelWidth,
                ),
              );
        canvas.drawParagraph(
          paragraph,
          Offset(
            size.width - valueLabelWidth,
            gridLineY - valueLabelFontSize - 4,
          ),
        );
      }
    }

    // draw custom lines
    for (var line in this.lines) {
      _drawValueLabel(
        canvas: canvas,
        size: size,
        value: line.value,
        lineColor: line.lineColor,
        boxColor: line.lineColor,
        textColor: line.textColor,
        dashed: line.dashed,
      );
    }

    var cursorPaint = Paint()
      ..color = this.cursorColor
      ..strokeWidth = 0.5;

    // draw cursor circle
    if (this.cursorX != -1 && this.cursorY != -1) {
      canvas.drawCircle(
        Offset(this.cursorX, this.cursorY),
        3,
        cursorPaint,
      );
    }

    // draw cursor vertical line
    if (this.cursorX != -1) {
      final max = size.height; // size gets to width
      double dashWidth = 5;
      var dashSpace = 5;
      double startY = 0;
      final space = (dashSpace + dashWidth);
      while (startY < max) {
        canvas.drawLine(Offset(cursorX, startY),
            Offset(cursorX, startY + dashWidth), cursorPaint);
        startY += space;
      }
    }

    // draw cursor horizontal line
    if (this.cursorY != -1) {
      _drawValueLabel(
        canvas: canvas,
        size: size,
        value: this.cursorYPrice,
        lineColor: this.cursorColor,
        boxColor: this.cursorColor,
        textColor: this.selectedPriceTextColor,
        dashed: true,
      );
    }
  }

  // draws line and value box over x-axis
  void _drawValueLabel({
    @required Canvas canvas,
    @required Size size,
    @required double value,
    Color lineColor = Colors.black,
    Color boxColor = Colors.black,
    Color textColor = Colors.white,
    bool dashed = false,
  }) {
    final double chartHeight = size.height * (1 - volumeProp);
    var y = (chartHeight * (value - _min)) / (_max - _min);
    y = (y - chartHeight) * -1; // invert y value

    // draw label line
    if (dashed) {
      var max = size.width;
      if (!fullscreenGridLine) {
        max -= valueLabelWidth;
      }
      double dashWidth = 5;
      var dashSpace = 5;
      double startX = 0;
      final space = (dashSpace + dashWidth);
      while (startX < max) {
        var endX = startX + dashWidth;
        endX = endX > max ? max : endX;
        canvas.drawLine(
            Offset(startX, y), Offset(endX, y), Paint()..color = lineColor);
        startX += space;
      }
    } else {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width - valueLabelWidth, y),
        Paint()..color = lineColor,
      );
    }

    // draw rounded rect
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width - valueLabelWidth,
          y - valueLabelHeight / 2,
          valueLabelWidth,
          valueLabelHeight,
        ),
        Radius.circular(valueLabelHeight / 2),
      ),
      Paint()..color = boxColor,
    );

    // draw value text into rounded rect
    final Paragraph paragraph = _getParagraphBuilder(value, textColor).build()
      ..layout(ParagraphConstraints(
        width: valueLabelWidth,
      ));
    canvas.drawParagraph(paragraph,
        Offset(size.width - valueLabelWidth, y - valueLabelFontSize / 2));
  }

  ParagraphBuilder _getParagraphBuilder(double value, Color textColor) {
    return ParagraphBuilder(
      ParagraphStyle(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      ),
    )
      ..pushStyle(TextStyle(
        color: textColor,
        fontSize: valueLabelFontSize,
        fontWeight: FontWeight.bold,
      ).getTextStyle())
      ..addText(
        labelPrefix + numCommaParse(value),
      );
  }

  @override
  bool shouldRepaint(_OHLCVPainter old) {
    return data != old.data ||
        lineWidth != old.lineWidth ||
        enableGridLines != old.enableGridLines ||
        gridLineColor != old.gridLineColor ||
        gridLineAmount != old.gridLineAmount ||
        gridLineWidth != old.gridLineWidth ||
        volumeProp != old.volumeProp ||
        gridLineLabelColor != old.gridLineLabelColor ||
        cursorColor != old.cursorColor ||
        selectedPriceTextColor != old.selectedPriceTextColor ||
        lines.hashCode != old.lines.hashCode ||
        cursorX != old.cursorX ||
        cursorY != old.cursorY ||
        cursorYPrice != old.cursorYPrice;
  }
}

class LineValue {
  double value;
  Color textColor;
  Color lineColor;
  bool dashed;
}
