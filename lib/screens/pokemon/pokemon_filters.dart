import 'package:flutter/material.dart';
import '../../widgets/pokemon_filter_widgets.dart';

class PokemonFilters extends StatelessWidget {
  final Map<String, bool> selectedTypes;
  final int selectedGeneration;
  final RangeValues powerRange;
  final Function(Map<String, bool>) onTypesChanged;
  final Function(int) onGenerationChanged;
  final Function(RangeValues) onPowerRangeChanged;
  final Color Function(String) getTypeColor;
  final bool showAdvancedSearch;
  final Function(bool) onAdvancedSearchToggle;

  const PokemonFilters({
    Key? key,
    required this.selectedTypes,
    required this.selectedGeneration,
    required this.powerRange,
    required this.onTypesChanged,
    required this.onGenerationChanged,
    required this.onPowerRangeChanged,
    required this.getTypeColor,
    required this.showAdvancedSearch,
    required this.onAdvancedSearchToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: showAdvancedSearch ? null : 0,
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TypeFilter(
                selectedTypes: selectedTypes,
                onTypesChanged: onTypesChanged,
                getTypeColor: getTypeColor,
              ),
              SizedBox(height: 16),
              GenerationFilter(
                selectedGeneration: selectedGeneration,
                onGenerationChanged: onGenerationChanged,
              ),
              SizedBox(height: 16),
              PowerRangeFilter(
                powerRange: powerRange,
                onPowerRangeChanged: onPowerRangeChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 