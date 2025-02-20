import 'package:flutter/material.dart';

class BattleLog extends StatelessWidget {
  final String message;

  const BattleLog({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.white,
      width: double.infinity,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
} 