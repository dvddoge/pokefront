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
        Row(
          children: [
            const Text(
              'Selecione os tipos:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (selectedTypes.values.any((v) => v))
              TextButton(
                onPressed: () {
                  final newTypes = <String, bool>{};
                  for (final type in selectedTypes.keys) {
                    newTypes[type] = false;
                  }
                  onTypesChanged(newTypes);
                },
                child: Text(
                  'Limpar',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'fire',
                'water',
                'grass',
                'electric',
                'psychic',
                'ice',
                'dragon',
                'dark',
                'fairy',
                'fighting',
                'flying',
                'poison',
                'ground',
                'rock',
                'bug',
                'ghost',
                'steel',
                'normal'
              ].map((type) {
                bool isSelected = selectedTypes[type] ?? false;
                return FilterChip(
                  selected: isSelected,
                  label: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: Colors.grey[200],
                  selectedColor: getTypeColor(type),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (bool selected) {
                    final newTypes = Map<String, bool>.from(selectedTypes);
                    newTypes[type] = selected;
                    onTypesChanged(newTypes);
                  },
                );
              }).toList(),
            ),
          ),
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
        Row(
          children: [
            const Text(
              'Escolha a geração:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (selectedGeneration > 0)
              TextButton(
                onPressed: () => onGenerationChanged(0),
                child: Text(
                  'Limpar',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: List.generate(8, (index) {
              final generation = index + 1;
              return ChoiceChip(
                selected: selectedGeneration == generation,
                label: Text(
                  'Gen $generation',
                  style: TextStyle(
                    color: selectedGeneration == generation
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 11,
                    fontWeight: selectedGeneration == generation
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selectedColor: Colors.red[700],
                backgroundColor: Colors.grey[200],
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (bool selected) {
                  onGenerationChanged(selected ? generation : 0);
                },
              );
            }),
          ),
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

class HeightRangeFilter extends StatefulWidget {
  final RangeValues heightRange;
  final Function(RangeValues) onHeightRangeChanged;

  const HeightRangeFilter({
    Key? key,
    required this.heightRange,
    required this.onHeightRangeChanged,
  }) : super(key: key);

  @override
  State<HeightRangeFilter> createState() => _HeightRangeFilterState();
}

class _HeightRangeFilterState extends State<HeightRangeFilter> {
  Timer? _debounce;
  RangeValues _currentRange = const RangeValues(0, 20);

  @override
  void initState() {
    super.initState();
    _currentRange = widget.heightRange;
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
      widget.onHeightRangeChanged(values);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Altura (m):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            if (_currentRange != const RangeValues(0, 20))
              TextButton(
                onPressed: () {
                  setState(() => _currentRange = const RangeValues(0, 20));
                  widget.onHeightRangeChanged(const RangeValues(0, 20));
                },
                child: Text('Limpar',
                    style: TextStyle(color: Colors.red[700], fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniBadge(
                        'Min: ${_currentRange.start.toStringAsFixed(1)}'),
                    _buildMiniBadge(
                        'Max: ${_currentRange.end.toStringAsFixed(1)}'),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.red[700],
                    inactiveTrackColor: Colors.red[100],
                    thumbColor: Colors.red[700],
                    overlayColor: Colors.red[700]?.withValues(alpha: 0.2),
                  ),
                  child: RangeSlider(
                    values: _currentRange,
                    min: 0,
                    max: 20,
                    divisions: 200, // 0.1m steps
                    labels: RangeLabels(
                      _currentRange.start.toStringAsFixed(1),
                      _currentRange.end.toStringAsFixed(1),
                    ),
                    onChanged: _onRangeChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                    Text('20',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.red[700],
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class WeightRangeFilter extends StatefulWidget {
  final RangeValues weightRange;
  final Function(RangeValues) onWeightRangeChanged;

  const WeightRangeFilter({
    Key? key,
    required this.weightRange,
    required this.onWeightRangeChanged,
  }) : super(key: key);

  @override
  State<WeightRangeFilter> createState() => _WeightRangeFilterState();
}

class _WeightRangeFilterState extends State<WeightRangeFilter> {
  Timer? _debounce;
  RangeValues _currentRange = const RangeValues(0, 1000);

  @override
  void initState() {
    super.initState();
    _currentRange = widget.weightRange;
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
      widget.onWeightRangeChanged(values);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Peso (kg):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            if (_currentRange != const RangeValues(0, 1000))
              TextButton(
                onPressed: () {
                  setState(() => _currentRange = const RangeValues(0, 1000));
                  widget.onWeightRangeChanged(const RangeValues(0, 1000));
                },
                child: Text('Limpar',
                    style: TextStyle(color: Colors.red[700], fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniBadge('Min: ${_currentRange.start.toInt()}'),
                    _buildMiniBadge('Max: ${_currentRange.end.toInt()}'),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.red[700],
                    inactiveTrackColor: Colors.red[100],
                    thumbColor: Colors.red[700],
                    overlayColor: Colors.red[700]?.withValues(alpha: 0.2),
                  ),
                  child: RangeSlider(
                    values: _currentRange,
                    min: 0,
                    max: 1000,
                    divisions: 100,
                    labels: RangeLabels(
                      _currentRange.start.round().toString(),
                      _currentRange.end.round().toString(),
                    ),
                    onChanged: _onRangeChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                    Text('1000',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.red[700],
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Faixa de poder total:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (_currentRange != const RangeValues(0, 1000))
              TextButton(
                onPressed: () {
                  setState(() => _currentRange = const RangeValues(0, 1000));
                  widget.onPowerRangeChanged(const RangeValues(0, 1000));
                },
                child: Text(
                  'Limpar',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Min: ${_currentRange.start.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Max: ${_currentRange.end.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.red[700],
                    inactiveTrackColor: Colors.red[100],
                    thumbColor: Colors.red[700],
                    overlayColor: Colors.red[700]?.withValues(alpha: 0.2),
                  ),
                  child: RangeSlider(
                    values: _currentRange,
                    min: 0,
                    max: 1000,
                    divisions: 100,
                    labels: RangeLabels(
                      _currentRange.start.round().toString(),
                      _currentRange.end.round().toString(),
                    ),
                    onChanged: _onRangeChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '1000',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
