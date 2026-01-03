import 'package:flutter/material.dart';
import '../services/puntos_service.dart';
import '../services/supabase_service.dart';

class MisPuntosScreen extends StatefulWidget {
  const MisPuntosScreen({Key? key}) : super(key: key);

  @override
  State<MisPuntosScreen> createState() => _MisPuntosScreenState();
}

class _MisPuntosScreenState extends State<MisPuntosScreen> {
  int _puntosActuales = 0;
  List<dynamic> _historial = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    final userId = SupabaseService.getCurrentAuthUser()?.id;
    if (userId == null) return;

    // Cargar puntos actuales
    final puntosResult = await PuntosService.getPuntosUsuario(userId);
    if (puntosResult['success']) {
      _puntosActuales = puntosResult['puntos'];
    }

    // Cargar historial
    final historialResult = await PuntosService.getHistorialPuntos(userId);
    if (historialResult['success']) {
      _historial = historialResult['data'];
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Puntos'),
        backgroundColor: const Color(0xFFEF233C),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: Column(
                children: [
                  // Tarjeta de puntos actuales
                  _buildPuntosCard(),
                  const SizedBox(height: 16),
                  // Información sobre cómo ganar puntos
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  // Historial
                  Expanded(child: _buildHistorial()),
                ],
              ),
            ),
    );
  }

  Widget _buildPuntosCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF233C), Color(0xFFD90429)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF233C).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Puntos Disponibles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_puntosActuales',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'puntos',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF233C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF233C).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFEF233C)),
              const SizedBox(width: 8),
              Text(
                '¿Cómo ganar puntos?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('🎁', 'Registro: 3 puntos de bienvenida'),
          _buildInfoItem('📦', 'Publicar productos: 1-3 puntos'),
          _buildInfoItem('🔄', 'Intercambio exitoso: 3 puntos bonus'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorial() {
    if (_historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay historial de puntos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Historial de Transacciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _historial.length,
            itemBuilder: (context, index) {
              final item = _historial[index];
              return _buildHistorialItem(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistorialItem(Map<String, dynamic> item) {
    final tipo = item['tipo_transaccion'] as String;
    final puntos = item['puntos'] as int;
    final saldo = item['saldo_resultante'] as int;
    final descripcion = item['descripcion'] as String;
    final fecha = DateTime.parse(item['creado_en']);

    IconData icon;
    Color color;

    switch (tipo) {
      case 'registro_inicial':
        icon = Icons.card_giftcard;
        color = const Color(0xFFEF233C);
        break;
      case 'publicacion_producto':
        icon = Icons.add_box;
        color = const Color(0xFFD90429);
        break;
      case 'intercambio_exitoso':
        icon = Icons.swap_horiz;
        color = const Color(0xFFEF233C);
        break;
      case 'penalizacion':
        icon = Icons.remove_circle;
        color = const Color(0xFF8D0801);
        break;
      default:
        icon = Icons.circle;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          descripcion,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _formatFecha(fecha),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${puntos > 0 ? '+' : ''}$puntos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: puntos > 0 ? const Color(0xFFEF233C) : const Color(0xFF8D0801),
              ),
            ),
            Text(
              'Saldo: $saldo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Hace un momento';
        }
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}
