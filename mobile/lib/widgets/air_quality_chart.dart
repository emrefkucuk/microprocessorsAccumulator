import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/air_quality_data.dart';

class AirQualityChart extends StatelessWidget {
  final List<AirQualityData> data;
  final String timeFormat;

  const AirQualityChart({
    Key? key,
    required this.data,
    required this.timeFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    // Calculate max value for y-axis scaling
    final maxAqi = _getMaxValue();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y-axis labels
        SizedBox(
          width: 35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ...List.generate(5, (index) {
                final value = (maxAqi * (4 - index) / 4).round();
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 25), // Space for x-axis labels
            ],
          ),
        ),

        // Main chart area
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: CustomPaint(
                  painter: ChartPainter(
                    data: data,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 20,
                child: _buildTimeLabels(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeLabels() {
    // Only show a subset of labels to avoid overcrowding
    final labelCount = data.length > 10 ? 5 : data.length;
    final step = data.length ~/ labelCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < data.length; i += step)
          if (i < data.length)
            Expanded(
              child: Text(
                DateFormat(timeFormat).format(data[i].timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
                textAlign: i == 0
                    ? TextAlign.left
                    : i == data.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
    );
  }

  double _getMaxValue() {
    if (data.isEmpty) return 100;

    double max = 0;
    for (final point in data) {
      if (point.aqi > max) {
        max = point.aqi.toDouble();
      }
    }
    return max < 50 ? 50 : max; // Ensure we have at least a scale to 50
  }
}

class ChartPainter extends CustomPainter {
  final List<AirQualityData> data;
  final Color color;

  ChartPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = _getMaxValue() * 1.2; // Add 20% padding
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw grid lines
    _drawGridLines(canvas, size, maxY);

    // Create path for the line
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y = size.height - (data[i].aqi / maxY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete the fill path
    if (data.isNotEmpty) {
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
    }

    // Draw the fill first, then the line on top
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  void _drawGridLines(Canvas canvas, Size size, double maxY) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // Horizontal grid lines
    final horizontalLines = 4;
    for (int i = 0; i <= horizontalLines; i++) {
      final y = i * size.height / horizontalLines;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    final verticalLines = data.length > 10 ? 5 : data.length;
    for (int i = 0; i <= verticalLines; i++) {
      final x = i * size.width / verticalLines;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }

  double _getMaxValue() {
    if (data.isEmpty) return 100;

    double max = 0;
    for (final point in data) {
      if (point.aqi > max) {
        max = point.aqi.toDouble();
      }
    }
    return max < 50 ? 50 : max; // Ensure we have at least a scale to 50
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
