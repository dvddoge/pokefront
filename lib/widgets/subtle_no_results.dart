import 'package:flutter/material.dart';
import 'pokeball_painter.dart';

class SubtleNoResults extends StatelessWidget {
  final String searchQuery;

  const SubtleNoResults({
    Key? key,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isFilterMessage = searchQuery.contains('\n');

    return Container(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pokebola de fundo
          Positioned.fill(
            child: CustomPaint(
              painter: PokeballPainter(
                color: Colors.grey[200]!,
              ),
            ),
          ),
          // Conteúdo
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFilterMessage ? Icons.filter_alt_off : Icons.search_off_outlined,
                size: 32,
                color: Colors.grey[400],
              ),
              SizedBox(height: 12),
              if (isFilterMessage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    searchQuery,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      'Nenhum resultado para "$searchQuery"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tente buscar usando menos caracteres',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
} 