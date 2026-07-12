import 'package:flutter/material.dart';

/// Bouton « dalle 3D » façon jeux mobiles casual (Caveboy Escape) :
/// contour sombre épais, corps en dégradé, reflet supérieur, tranche
/// inférieure plus foncée, et enfoncement au tap.
class ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  final double height;
  final double fontSize;

  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = const Color(0xFFE8C170), // sable doré par défaut
    this.textColor,
    this.icon,
    this.height = 62,
    this.fontSize = 22,
  });

  /// Variante rouge « action principale ».
  const ChunkyButton.red({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 62,
    this.fontSize = 22,
  })  : color = const Color(0xFFC94F3D),
        textColor = const Color(0xFFFFF3DC);

  /// Variante verte « valider / go ».
  const ChunkyButton.green({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 62,
    this.fontSize = 22,
  })  : color = const Color(0xFF8FA83B),
        textColor = const Color(0xFF2E3308);

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  HSLColor get _hsl => HSLColor.fromColor(widget.color);
  Color get _light => _hsl.withLightness((_hsl.lightness + 0.13).clamp(0.0, 1.0)).toColor();
  Color get _darkEdge => _hsl.withLightness((_hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
  Color get _outline => const Color(0xFF3A2417);

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final textColor = widget.textColor ?? const Color(0xFF4A2E15);
    const edgeDepth = 5.0;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        height: widget.height,
        transform: Matrix4.translationValues(0, _pressed ? edgeDepth - 1 : 0, 0),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: _darkEdge, // la « tranche » 3D dépasse en bas
              borderRadius: BorderRadius.circular(widget.height * 0.32),
              border: Border.all(color: _outline, width: 2.5),
              boxShadow: _pressed
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: _pressed ? 1 : edgeDepth),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_light, widget.color],
                ),
                borderRadius: BorderRadius.circular(widget.height * 0.30),
              ),
              child: Stack(
                children: [
                  // Reflet supérieur.
                  Positioned(
                    top: 3,
                    left: widget.height * 0.28,
                    right: widget.height * 0.28,
                    child: Container(
                      height: widget.height * 0.16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: textColor, size: widget.fontSize + 4),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: textColor,
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.4),
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panneau « planche de bois clair » pour poser du contenu par-dessus
/// une illustration de fond (façon panneaux Caveboy).
class ChunkyPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ChunkyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4E3BC), Color(0xFFE4CB96)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A2417), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
