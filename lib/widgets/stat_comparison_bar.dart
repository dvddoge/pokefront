import 'package:flutter/material.dart';

class StatComparisonBar extends StatefulWidget {
  final String statName;
  final int value1;
  final int value2;
  final double maxValue;
  final Color? color1;
  final Color? color2;

  const StatComparisonBar({
    Key? key,
    required this.statName,
    required this.value1,
    required this.value2,
    this.maxValue = 255.0,
    this.color1,
    this.color2,
  }) : super(key: key);

  @override
  State<StatComparisonBar> createState() => _StatComparisonBarState();
}

class _StatComparisonBarState extends State<StatComparisonBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final difference = widget.value1 - widget.value2;
    final better = difference > 0 ? 1 : (difference < 0 ? 2 : 0);
    final percentage1 = widget.value1 / widget.maxValue;
    final percentage2 = widget.value2 / widget.maxValue;

    final color1 = widget.color1 ?? (better == 1 ? Colors.green : (better == 0 ? Colors.grey[600]! : Colors.red[700]!));
    final color2 = widget.color2 ?? (better == 2 ? Colors.green : (better == 0 ? Colors.grey[600]! : Colors.red[700]!));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.statName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          widget.value1.toString(),
                          style: TextStyle(
                            color: color1,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          ' vs ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.value2.toString(),
                          style: TextStyle(
                            color: color2,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: (percentage1 * 100).toInt(),
                      child: _buildBar(
                        value: widget.value1,
                        percentage: percentage1 * _animation.value,
                        color: color1,
                        isLeft: true,
                      ),
                    ),
                    Container(
                      width: 2,
                      color: Colors.white,
                    ),
                    Expanded(
                      flex: (percentage2 * 100).toInt(),
                      child: _buildBar(
                        value: widget.value2,
                        percentage: percentage2 * _animation.value,
                        color: color2,
                        isLeft: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar({
    required int value,
    required double percentage,
    required Color color,
    required bool isLeft,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(isLeft ? 12 : 0),
        right: Radius.circular(isLeft ? 0 : 12),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.7),
                  color,
                ],
                begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              ),
            ),
          ),
          if (percentage > 0.7)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SparklesPainter(
                    color: Colors.white,
                    progress: _animation.value,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  final Color color;
  final double progress;

  _SparklesPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final sparkleSize = size.height * 0.4;
    final numberOfSparkles = (size.width / (sparkleSize * 2)).ceil();

    for (var i = 0; i < numberOfSparkles; i++) {
      final x = i * sparkleSize * 2 + (progress * size.width);
      final y = size.height / 2;
      
      final path = Path()
        ..moveTo(x, y - sparkleSize / 2)
        ..lineTo(x + sparkleSize / 2, y)
        ..lineTo(x, y + sparkleSize / 2)
        ..lineTo(x - sparkleSize / 2, y)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
