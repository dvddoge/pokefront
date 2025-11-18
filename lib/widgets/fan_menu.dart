import 'package:flutter/material.dart';
import 'dart:math' as math;

class FanMenuItem {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  FanMenuItem({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
}

class FanMenu extends StatefulWidget {
  final List<FanMenuItem> items;
  final IconData toggleIcon;
  final Color toggleColor;

  const FanMenu({
    Key? key,
    required this.items,
    this.toggleIcon = Icons.menu,
    this.toggleColor = Colors.blue,
  }) : super(key: key);

  @override
  _FanMenuState createState() => _FanMenuState();
}

class _FanMenuState extends State<FanMenu> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  bool _isExpanded = false;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.25, // 90 graus (0.25 de volta completa)
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() {
      _isExpanded = true;
      _hoveredIndex = null;
    });
    _animationController.forward();
    _pulseController.repeat();
  }

  void _collapse() {
    setState(() {
      _isExpanded = false;
      _hoveredIndex = null;
    });
    _animationController.reverse();
    _pulseController.stop();
    _pulseController.reset();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isExpanded) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final newHoveredIndex = _getHoveredIndex(localPosition);

    // Feedback háptico quando mudar de opção
    if (newHoveredIndex != _hoveredIndex && newHoveredIndex != null) {
      // Pode adicionar feedback háptico aqui se desejar
    }

    setState(() {
      _hoveredIndex = newHoveredIndex;
    });
  }

  int? _getHoveredIndex(Offset position) {
    if (!_isExpanded) return null;

    const double buttonRadius = 40.0;
    const double fanRadius = 120.0;
    final double scaleValue = _scaleAnimation.value;

    // Centro do widget (280x280)
    final center = const Offset(140, 140);

    for (int i = 0; i < widget.items.length; i++) {
      // Distribui os botões em 90 graus à esquerda, de 90° (topo) até 180° (esquerda)
      final angle = (math.pi / 2) +
          (math.pi / 2) * (i / math.max(1, widget.items.length - 1));
      final radius = fanRadius * scaleValue;
      final buttonX = center.dx + radius * math.cos(angle);
      final buttonY = center.dy - radius * math.sin(angle);

      final buttonCenter = Offset(buttonX, buttonY);
      final distance = (position - buttonCenter).distance;

      if (distance <= buttonRadius) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        _expand();
      },
      onLongPressMoveUpdate: (details) {
        // Usa onLongPressMoveUpdate em vez de onPanUpdate para melhor detecção
        _onPanUpdate(DragUpdateDetails(
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
          delta: details.offsetFromOrigin,
        ));
      },
      onLongPressEnd: (details) {
        // Executa a ação se houver uma opção selecionada
        if (_hoveredIndex != null && _hoveredIndex! < widget.items.length) {
          widget.items[_hoveredIndex!].onTap();
        }
        _collapse();
      },
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Botões do leque
            ...widget.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  // Distribui os botões em 90 graus à esquerda, de 90° (topo) até 180° (esquerda)
                  final angle = (math.pi / 2) +
                      (math.pi / 2) *
                          (index / math.max(1, widget.items.length - 1));
                  final radius =
                      120.0 * _scaleAnimation.value; // Raio aumentado
                  final x = radius * math.cos(angle);
                  final y = -radius * math.sin(angle);

                  final isHovered = _hoveredIndex == index;
                  final scale = isHovered ? 1.2 : 1.0;

                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Transform.scale(
                      scale: _scaleAnimation.value * scale,
                      child: Opacity(
                        opacity: _scaleAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isHovered
                                ? item.color.withValues(alpha: 0.9)
                                : item.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withValues(alpha: 0.3),
                                blurRadius: isHovered ? 16 : 8,
                                spreadRadius: isHovered ? 4 : 0,
                              ),
                              if (isHovered)
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            color: Colors.white,
                            size: isHovered ? 32 : 28,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),

            // Botão principal
            AnimatedBuilder(
              animation:
                  Listenable.merge([_rotationAnimation, _pulseController]),
              builder: (context, child) {
                final pulseScale = _isExpanded
                    ? 1.0 + 0.1 * math.sin(_pulseController.value * 2 * math.pi)
                    : 1.0;

                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * math.pi,
                  child: Transform.scale(
                    scale: pulseScale,
                    child: FloatingActionButton(
                      heroTag: 'fan_menu_toggle',
                      backgroundColor: _isExpanded
                          ? widget.toggleColor.withValues(alpha: 0.8)
                          : widget.toggleColor,
                      elevation: _isExpanded ? 12 : 6,
                      onPressed: null, // Controlado pelos gestures
                      child: Icon(
                        _isExpanded ? Icons.close : widget.toggleIcon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Indicador visual quando expandido
            if (_isExpanded)
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: (_scaleAnimation.value * 0.3).clamp(0.0, 1.0),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: widget.toggleColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
