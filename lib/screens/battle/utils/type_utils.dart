import 'package:flutter/material.dart';

class TypeUtils {
  static Color getTypeColor(String type) {
    final colors = {
      'fire': Color(0xFFEE8130),
      'water': Color(0xFF6390F0),
      'grass': Color(0xFF7AC74C),
      'electric': Color(0xFFF7D02C),
      'psychic': Color(0xFFF95587),
      'ice': Color(0xFF96D9D6),
      'dragon': Color(0xFF6F35FC),
      'dark': Color(0xFF705746),
      'fairy': Color(0xFFD685AD),
      'fighting': Color(0xFFC22E28),
      'flying': Color(0xFFA98FF3),
      'poison': Color(0xFFA33EA1),
      'ground': Color(0xFFE2BF65),
      'rock': Color(0xFFB6A136),
      'bug': Color(0xFFA6B91A),
      'ghost': Color(0xFF735797),
      'steel': Color(0xFFB7B7CE),
      'normal': Color(0xFFA8A77A),
    };
    return colors[type.toLowerCase()] ?? Colors.grey;
  }

  static IconData getTypeIcon(String type) {
    final icons = {
      'fire': Icons.local_fire_department,
      'water': Icons.water_drop,
      'grass': Icons.grass,
      'electric': Icons.bolt,
      'psychic': Icons.psychology,
      'ice': Icons.ac_unit,
      'dragon': Icons.auto_awesome,
      'dark': Icons.nights_stay,
      'fairy': Icons.star,
      'fighting': Icons.sports_kabaddi,
      'flying': Icons.air,
      'poison': Icons.science,
      'ground': Icons.landscape,
      'rock': Icons.terrain,
      'bug': Icons.bug_report,
      'ghost': Icons.blur_on,
      'steel': Icons.shield,
      'normal': Icons.circle_outlined,
    };
    return icons[type.toLowerCase()] ?? Icons.help_outline;
  }
} 