import 'package:flutter/material.dart';

class AnimationUtils {
  static AnimationController createBattleController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 500),
    );
  }

  static AnimationController createShakeController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 300),
    );
  }

  static AnimationController createDamageController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 200),
    );
  }

  static AnimationController createAttackController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 600),
    );
  }

  static AnimationController createBackgroundController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 8000),
    )..repeat();
  }

  static AnimationController createFloatingController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 3000),
    )..repeat();
  }

  static AnimationController createFlashController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 150),
    );
  }

  static Animation<Offset> createAttackAnimation(AnimationController controller) {
    return TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: Offset(-0.2, -0.1),
        ),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(-0.2, -0.1),
          end: Offset(0.2, 0.1),
        ),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(0.2, 0.1),
          end: Offset.zero,
        ),
        weight: 25.0,
      ),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  static Animation<double> createBackgroundAnimation(AnimationController controller) {
    return CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
  }

  static Animation<double> createFloatingAnimation(AnimationController controller) {
    return CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
  }
} 