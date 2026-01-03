import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trueque/modelo/intercambio.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/screens/chat_screen.dart';
import 'package:trueque/screens/intercambio/detalle_intercambio_screen.dart';
import 'package:trueque/screens/objects_screen.dart';
import 'package:trueque/services/notificaciones_service.dart';
import 'package:trueque/services/intercambio_service.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final Stream<List<Map<String, dynamic>>> _notificationsStream;
  final _intercambioService = IntercambioService();

  @override
  void initState() {
    super.initState();
    _notificationsStream = NotificacionesService.streamNotificaciones();
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final id = notification['id'] as int;
    if (notification['is_read'] == false) {
      await NotificacionesService.marcarComoLeida(id);
    }

    final type = notification['type']?.toString();
    final relatedId = notification['related_id']?.toString();

    if (!mounted) return;

    switch (type) {
      case 'sistema':
        final currentUser = await _getCurrentUserModel();
        if (currentUser != null && mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ObjectsScreen(currentUser: currentUser)));
        }
        break;

      case 'intercambio':
        if (relatedId != null) {
          _abrirDetalleIntercambio(relatedId);
        }
        break;

      case 'mensaje':
        if (relatedId != null) {
          final userName = await _getUserName(relatedId) ?? 'Usuario';
          if (!mounted) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(otherUserId: relatedId, otherUserName: userName)));
        }
        break;
    }
  }

  Future<void> _abrirDetalleIntercambio(String intercambioId) async {
    // Mostrar un indicador de carga circular mientras obtenemos los datos
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final id = int.parse(intercambioId);
      // Buscamos el intercambio completo en Supabase
      final response = await Supabase.instance.client
          .from('intercambio')
          .select('*, usuario_ofertante:id_usuario_ofrece(*), usuario_receptor:id_usuario_recibido(*), producto_solicitado:id_producto_solicitado(*), producto_ofertado:id_producto_ofertado(*)')
          .eq('id_intercambio', id)
          .single();

      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        final intercambio = Intercambio.fromJson(response);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => DetalleIntercambioScreen(intercambio: intercambio))
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar el detalle del intercambio.')));
      }
    }
  }

  Future<UserModel?> _getCurrentUserModel() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final data = await supabase.from('usuarios').select().eq('id', userId).single();
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getUserName(String userId) async {
    try {
      final response = await Supabase.instance.client.from('usuarios').select('name').eq('id', userId).single();
      return response['name'];
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => NotificacionesService.marcarTodasComoLeidas(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => NotificacionesService.eliminarTodas(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(child: Text('No hay notificaciones nuevas', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              final isRead = n['is_read'] as bool? ?? false;
              final type = n['type']?.toString();
              final createdAt = DateTime.parse(n['created_at'].toString());
              
              IconData icon = Icons.notifications_outlined;
              if (type == 'mensaje') icon = Icons.chat_outlined;
              if (type == 'intercambio') icon = Icons.swap_horiz_outlined;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: isRead ? Colors.white : const Color(0xFFFFF5F5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey[200] : const Color(0xFFFDE4E4),
                    child: Icon(icon, color: isRead ? Colors.grey : const Color(0xFFB71C1C)),
                  ),
                  title: Text(n['title'] ?? 'Notificación', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['body'] ?? ''),
                      Text(timeago.format(createdAt, locale: 'es'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  onTap: () => _handleNotificationTap(n),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRead) IconButton(icon: const Icon(Icons.mark_email_unread_outlined, size: 20, color: Colors.blue), onPressed: () => NotificacionesService.marcarComoNoLeida(n['id'])),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => NotificacionesService.eliminarNotificacion(n['id'])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
