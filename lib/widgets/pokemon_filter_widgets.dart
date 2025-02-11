import 'package:flutter/material.dart';
import 'dart:async';

class TypeFilter extends StatelessWidget {
  final Map<String, bool> selectedTypes;
  final Function(Map<String, bool>) onTypesChanged;
  final Color Function(String) getTypeColor;

  const TypeFilter({
    Key? key,
    required this.selectedTypes,
    required this.onTypesChanged,
    required this.getTypeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'fire', 'water', 'grass', 'electric', 'psychic', 'ice',
            'dragon', 'dark', 'fairy', 'fighting', 'flying', 'poison',
            'ground', 'rock', 'bug', 'ghost', 'steel', 'normal'
          ].map((type) {
            bool isSelected = selectedTypes[type] ?? false;
            return FilterChip(
              selected: isSelected,
              label: Text(
                type.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              backgroundColor: Colors.grey[200],
              selectedColor: getTypeColor(type),
              onSelected: (bool selected) {
                final newTypes = Map<String, bool>.from(selectedTypes);
                newTypes[type] = selected;
                onTypesChanged(newTypes);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class GenerationFilter extends StatelessWidget {
  final int selectedGeneration;
  final Function(int) onGenerationChanged;

  const GenerationFilter({
    Key? key,
    required this.selectedGeneration,
    required this.onGenerationChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Geração',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(8, (index) {
            final generation = index + 1;
            return ChoiceChip(
              selected: selectedGeneration == generation,
              label: Text(
                'Gen $generation',
                style: TextStyle(
                  color: selectedGeneration == generation ? Colors.white : Colors.black87,
                ),
              ),
              selectedColor: Colors.red[700],
              onSelected: (bool selected) {
                onGenerationChanged(selected ? generation : 0);
              },
            );
          }),
        ),
      ],
    );
  }
}

class PowerRangeFilter extends StatefulWidget {
  final RangeValues powerRange;
  final Function(RangeValues) onPowerRangeChanged;

  const PowerRangeFilter({
    Key? key,
    required this.powerRange,
    required this.onPowerRangeChanged,
  }) : super(key: key);

  @override
  _PowerRangeFilterState createState() => _PowerRangeFilterState();
}

class _PowerRangeFilterState extends State<PowerRangeFilter> {
  Timer? _debounce;
  RangeValues _currentRange = const RangeValues(0, 1000);

  @override
  void initState() {
    super.initState();
    _currentRange = widget.powerRange;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onRangeChanged(RangeValues values) {
    setState(() => _currentRange = values);
    
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onPowerRangeChanged(values);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poder Total',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Text(_currentRange.start.toInt().toString()),
            Expanded(
              child: RangeSlider(
                values: _currentRange,
                min: 0,
                max: 1000,
                divisions: 100,
                activeColor: Colors.red[700],
                inactiveColor: Colors.red[100],
                labels: RangeLabels(
                  _currentRange.start.round().toString(),
                  _currentRange.end.round().toString(),
                ),
                onChanged: _onRangeChanged,
              ),
            ),
            Text(_currentRange.end.toInt().toString()),
          ],
        ),
      ],
    );
  }
} 