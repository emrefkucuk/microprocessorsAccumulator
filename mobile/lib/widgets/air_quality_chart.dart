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

    // Calculate values for y-axis scaling and detect chart type
    final bool isMonthlyChart = timeFormat == 'dd/MM';
    final maxAqi = _getMaxValue();
    final avgAqi = _calculateAverage();
    final hasOutliers = _hasSignificantOutliers();

    // For monthly charts with outliers, use a different scaling strategy
    final yAxisMax = (isMonthlyChart && hasOutliers) ? avgAqi * 1.5 : maxAqi;

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
                // Calculate y-axis label values based on max value and chart type
                final value = (yAxisMax * (4 - index) / 4).round();
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
                child: GestureDetector(
                  onTapDown: (details) =>
                      _showTooltip(context, details.localPosition),
                  child: CustomPaint(
                    painter: ChartPainter(
                      data: data,
                      color: Theme.of(context).primaryColor,
                      maxY: yAxisMax,
                    ),
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

  // Show tooltip with data point information
  void _showTooltip(BuildContext context, Offset position) {
    if (data.isEmpty) return;

    // Calculate which data point is closest to the tap position
    final chartWidth = MediaQuery.of(context).size.width -
        60; // Account for y-axis width and padding
    final pointIndex = ((position.dx / chartWidth) * (data.length - 1))
        .round()
        .clamp(0, data.length - 1);

    final point = data[pointIndex];

    // Format date based on chart type (daily or monthly)
    final dateFormat = timeFormat == 'HH:mm' ? 'HH:mm' : 'dd/MM/yyyy';
    final dateString = DateFormat(dateFormat).format(point.timestamp);

    // Show tooltip as a popup
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Air Quality Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text('Time:'),
                Spacer(),
                Text(dateString),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text('AQI:'),
                Spacer(),
                Text('${point.aqi}'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text('Temperature:'),
                Spacer(),
                Text('${point.temperature.toStringAsFixed(1)}°C'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text('Humidity:'),
                Spacer(),
                Text('${point.humidity.toStringAsFixed(1)}%'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text('Status:'),
                Spacer(),
                Text(
                  point.statusText,
                  style: TextStyle(
                    color: point.statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Calculate average AQI
  double _calculateAverage() {
    if (data.isEmpty) return 50;

    double sum = 0;
    for (final point in data) {
      sum += point.aqi.toDouble();
    }
    return sum / data.length;
  }

  // Check if there are significant outliers that would make the chart less readable
  bool _hasSignificantOutliers() {
    if (data.length < 3) return false;

    final avg = _calculateAverage();
    double maxDiff = 0;

    for (final point in data) {
      final diff = (point.aqi - avg).abs();
      if (diff > maxDiff) {
        maxDiff = diff;
      }
    }

    // If the max difference from average is more than 150% of average, consider it an outlier
    return maxDiff > avg * 1.5;
  }

  Widget _buildTimeLabels() {
    if (data.isEmpty) return const SizedBox();

    // For monthly chart, dynamically determine the number of labels based on data range
    if (timeFormat == 'dd/MM') {
      // Calculate the date range of the data
      final firstDay = data.first.timestamp;
      final lastDay = data.last.timestamp;
      final totalDays = lastDay.difference(firstDay).inDays + 1;

      // Dynamically adjust the number of labels based on the date range
      // For a full month (~30 days), show ~5-6 labels
      int labelCount = totalDays <= 7 ? totalDays : (totalDays ~/ 5);
      labelCount = labelCount.clamp(2, 6); // At least 2, at most 6 labels

      // Calculate step size based on data distribution
      final step = (data.length / labelCount).round().clamp(1, data.length);

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
    } else {
      // For daily chart, use existing approach (fixed number of labels)
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
  final double maxY;

  ChartPainter({
    required this.data,
    required this.color,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw grid lines
    _drawGridLines(canvas, size);

    // Create path for the line
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y = size.height - (data[i].aqi / maxY * size.height);

      // Clamp very high values that exceed our scale to the top of the chart
      final clampedY = y.clamp(0.0, size.height);

      if (i == 0) {
        path.moveTo(x, clampedY);
        fillPath.moveTo(x, clampedY);
      } else {
        path.lineTo(x, clampedY);
        fillPath.lineTo(x, clampedY);
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

  void _drawGridLines(Canvas canvas, Size size) {
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

    // Vertical grid lines - for daily charts, show more lines
    int verticalLines;

    if (data.length <= 7) {
      // For few data points, show one for each point
      verticalLines = data.length - 1;
    } else if (data.length <= 14) {
      // For 7-14 data points (like a week), show ~5 lines
      verticalLines = 5;
    } else if (data.length <= 31) {
      // For monthly data (up to 31 points), show fewer lines to avoid overcrowding
      verticalLines = 6;
    } else {
      // For large datasets, limit the number of lines
      verticalLines = 7;
    }

    // Ensure at least 2 vertical lines
    verticalLines = verticalLines.clamp(2, 10);

    for (int i = 0; i <= verticalLines; i++) {
      final x = i * size.width / verticalLines;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.maxY != maxY;
  }
}
