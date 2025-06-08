import 'package:flutter/material.dart';

class TypeUtils {
  static Color getTypeColor(String type) {
    final colors = {
      'fire': const Color(0xFFEE8130),
      'water': const Color(0xFF6390F0),
      'grass': const Color(0xFF7AC74C),
      'electric': const Color(0xFFF7D02C),
      'psychic': const Color(0xFFF95587),
      'ice': const Color(0xFF96D9D6),
      'dragon': const Color(0xFF6F35FC),
      'dark': const Color(0xFF705746),
      'fairy': const Color(0xFFD685AD),
      'fighting': const Color(0xFFC22E28),
      'flying': const Color(0xFFA98FF3),
      'poison': const Color(0xFFA33EA1),
      'ground': const Color(0xFFE2BF65),
      'rock': const Color(0xFFB6A136),
      'bug': const Color(0xFFA6B91A),
      'ghost': const Color(0xFF735797),
      'steel': const Color(0xFFB7B7CE),
      'normal': const Color(0xFFA8A77A),
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