import 'package:flutter/material.dart';
import 'package:trueque/theme/app_theme.dart';


class CircleBackground extends StatelessWidget {
  final Widget child;

  const CircleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // El fondo pintado con nuestro CustomPainter
        Positioned.fill(
          child: CustomPaint(
            painter: _CirclePainter(),
          ),
        ),
        // El contenido de la pantalla se coloca encima del fondo
        child,
      ],
    );
  }
}

class _CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);

    // Círculo grande y semitransparente en la esquina superior derecha
    paint.color = AppTheme.primaryLightColor.withOpacity(0.3);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      100,
      paint,
    );

    // Círculo mediano en la esquina inferior izquierda
    paint.color = AppTheme.primaryColor.withOpacity(0.2);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.8),
      80,
      paint,
    );

    // Círculo pequeño en el centro
    paint.color = AppTheme.primaryDarkColor.withOpacity(0.15);
    canvas.drawCircle(center, 60, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // No necesitamos repintar, el fondo es estático.
    return false;
  }
}