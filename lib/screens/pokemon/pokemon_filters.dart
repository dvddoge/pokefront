import 'package:flutter/material.dart';
import '../../widgets/pokemon_filter_widgets.dart';

class PokemonFilters extends StatefulWidget {
  final Map<String, bool> selectedTypes;
  final int selectedGeneration;
  final RangeValues powerRange;
  final RangeValues heightRange;
  final RangeValues weightRange;
  final Function(Map<String, bool>) onTypesChanged;
  final Function(int) onGenerationChanged;
  final Function(RangeValues) onPowerRangeChanged;
  final Function(RangeValues) onHeightRangeChanged;
  final Function(RangeValues) onWeightRangeChanged;
  final Color Function(String) getTypeColor;
  final bool showAdvancedSearch;
  final Function(bool) onAdvancedSearchToggle;

  const PokemonFilters({
    Key? key,
    required this.selectedTypes,
    required this.selectedGeneration,
    required this.powerRange,
  required this.heightRange,
  required this.weightRange,
    required this.onTypesChanged,
    required this.onGenerationChanged,
    required this.onPowerRangeChanged,
  required this.onHeightRangeChanged,
  required this.onWeightRangeChanged,
    required this.getTypeColor,
    required this.showAdvancedSearch,
    required this.onAdvancedSearchToggle,
  }) : super(key: key);

  @override
  _PokemonFiltersState createState() => _PokemonFiltersState();
}

class _PokemonFiltersState extends State<PokemonFilters> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.red[700],
              unselectedLabelColor: Colors.grey[600],
              indicator: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.red[700]!,
                    width: 3,
                  ),
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
              ),
              tabs: const [
                Tab(
                  height: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, size: 16),
                      SizedBox(height: 2),
                      Text('Tipos'),
                    ],
                  ),
                ),
                Tab(
                  height: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline, size: 16),
                      SizedBox(height: 2),
                      Text('Geração'),
                    ],
                  ),
                ),
                Tab(
                  height: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 16),
                      SizedBox(height: 2),
                      Text('Poder'),
                    ],
                  ),
                ),
                Tab(
                  height: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.height, size: 16),
                      SizedBox(height: 2),
                      Text('Altura'),
                    ],
                  ),
                ),
                Tab(
                  height: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monitor_weight, size: 16),
                      SizedBox(height: 2),
                      Text('Peso'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TypeFilter(
                    selectedTypes: widget.selectedTypes,
                    onTypesChanged: widget.onTypesChanged,
                    getTypeColor: widget.getTypeColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: GenerationFilter(
                    selectedGeneration: widget.selectedGeneration,
                    onGenerationChanged: widget.onGenerationChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: PowerRangeFilter(
                    powerRange: widget.powerRange,
                    onPowerRangeChanged: widget.onPowerRangeChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: HeightRangeFilter(
                    heightRange: widget.heightRange,
                    onHeightRangeChanged: widget.onHeightRangeChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: WeightRangeFilter(
                    weightRange: widget.weightRange,
                    onWeightRangeChanged: widget.onWeightRangeChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 