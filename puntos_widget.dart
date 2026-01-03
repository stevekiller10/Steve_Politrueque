import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PuntosWidget extends StatefulWidget {
  final String userId;
  final VoidCallback? onTap;
  final bool showIcon;
  final Color? textColor;
  final double? fontSize;

  const PuntosWidget({
    Key? key,
    required this.userId,
    this.onTap,
    this.showIcon = true,
    this.textColor,
    this.fontSize,
  }) : super(key: key);

  @override
  State<PuntosWidget> createState() => _PuntosWidgetState();
}

class _PuntosWidgetState extends State<PuntosWidget> {
  int _puntos = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPuntos();
  }

  Future<void> _cargarPuntos() async {
    try {
      print('🔍 PuntosWidget: Cargando puntos para usuario: ${widget.userId}');
      final response = await Supabase.instance.client
          .from('usuarios')
          .select('puntos')
          .eq('id', widget.userId)
          .single();

      print('🔍 PuntosWidget: Respuesta recibida: $response');
      
      if (mounted) {
        setState(() {
          _puntos = response['puntos'] ?? 0;
          _isLoading = false;
        });
        print('🔍 PuntosWidget: Puntos cargados: $_puntos');
      }
    } catch (e) {
      print('❌ Error al cargar puntos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = widget.textColor ?? Colors.white;
    final effectiveFontSize = widget.fontSize ?? 16.0;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.textColor == null 
              ? const Color(0xFFEF233C).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
          ),
        ),
      );
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIcon) ...[
          Icon(
            Icons.stars,
            color: effectiveTextColor,
            size: effectiveFontSize + 4,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          '$_puntos',
          style: TextStyle(
            color: effectiveTextColor,
            fontWeight: FontWeight.bold,
            fontSize: effectiveFontSize,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'pts',
          style: TextStyle(
            color: effectiveTextColor.withOpacity(0.8),
            fontSize: effectiveFontSize - 4,
          ),
        ),
      ],
    );

    // Si no tiene decoración propia (cuando se usa dentro de otro contenedor)
    if (widget.textColor != null) {
      return widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, child: content)
          : content;
    }

    // Decoración por defecto
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              const Icon(
                Icons.stars,
                color: Color(0xFFFF9800),
                size: 22,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '$_puntos',
              style: const TextStyle(
                color: Color(0xFFEF233C),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'pts',
              style: TextStyle(
                color: Color(0xFFEF233C),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
