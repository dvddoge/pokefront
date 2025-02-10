import 'package:flutter/material.dart';

class StatComparisonBar extends StatefulWidget {
  final String statName;
  final int value1;
  final int value2;
  final double maxValue;

  const StatComparisonBar({
    Key? key,
    required this.statName,
    required this.value1,
    required this.value2,
    this.maxValue = 255.0,
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
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.statName,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _buildBar(
                      value: widget.value1,
                      percentage: percentage1 * _animation.value,
                      color: better == 1 ? Colors.green : (better == 0 ? Colors.blue : Colors.red),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildBar(
                      value: widget.value2,
                      percentage: percentage2 * _animation.value,
                      color: better == 2 ? Colors.green : (better == 0 ? Colors.blue : Colors.red),
                    ),
                  ),
                ],
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
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          Container(
            height: 24,
            color: Colors.grey[200],
          ),
          Container(
            height: 24,
            width: MediaQuery.of(context).size.width * 0.4 * percentage,
            decoration: BoxDecoration(
              color: color,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}