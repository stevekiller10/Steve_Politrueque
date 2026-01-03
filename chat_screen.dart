// ARCHIVO RESTAURADO PARA CORREGIR CORRUPCIÓN
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/services/chat_service.dart';
import 'package:trueque/services/puntos_service.dart';
import 'package:trueque/services/notificaciones_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? intercambioId; // ID del intercambio opcional

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.intercambioId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String myUserId;

  @override
  void initState() {
    super.initState();
    myUserId = Supabase.instance.client.auth.currentUser!.id;
  }

  bool _isBetween(Map msg) {
    return (msg['sender_id'] == myUserId &&
            msg['receiver_id'] == widget.otherUserId) ||
        (msg['sender_id'] == widget.otherUserId &&
            msg['receiver_id'] == myUserId);
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _chatService.sendMessage(
      senderId: myUserId,
      receiverId: widget.otherUserId,
      text: text,
    );

    _controller.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _gestionarIntercambio(String estado) async {
    if (widget.intercambioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se ha proporcionado un ID de intercambio.')),
      );
      return;
    }

    // TODO: Obtener IDs de productos del intercambio
    final validacion = await PuntosService.validarIntercambio(
        usuarioOfertanteId: widget.otherUserId, // El otro usuario es el que oferta
        usuarioReceptorId: myUserId, // Yo soy el que recibe
        productoOfertadoId: "", // TODO: Obtener IDs de productos del intercambio
        productoSolicitadoId: "");

    if (!validacion['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validacion['message'] ?? 'Error de validación desconocido.')),
      );
      return;
    }

    final resultado = estado == 'aceptado'
        ? await PuntosService.aceptarIntercambio(widget.intercambioId!)
        : await PuntosService.rechazarIntercambio(widget.intercambioId!);

    if (resultado['success']) {
      await NotificacionesService.crearNotificacion(
        userId: widget.otherUserId,
        type: 'intercambio',
        title: 'Intercambio ${estado == 'aceptado' ? 'aceptado' : 'rechazado'}',
        body: 'Tu propuesta de intercambio ha sido ${estado == 'aceptado' ? 'aceptada' : 'rechazada'}.',
        relatedId: widget.intercambioId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intercambio ${estado == 'aceptado' ? 'aceptado' : 'rechazado'} con éxito.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado['message'] ?? 'Error al gestionar el intercambio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: const Color(0xFFEF233C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.listenMessages(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.where((m) => _isBetween(m)).toList();

                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMine = msg['sender_id'] == myUserId;

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMine ? const Color(0xFFEF233C) : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
                            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          msg['message'],
                          style: TextStyle(fontSize: 16, color: isMine ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.intercambioId != null)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.green,
                iconSize: 28,
                tooltip: 'Aceptar Intercambio',
                onPressed: () => _gestionarIntercambio('aceptado'),
              ),
            if (widget.intercambioId != null)
              IconButton(
                icon: const Icon(Icons.cancel_outlined),
                color: Colors.red,
                iconSize: 28,
                tooltip: 'Rechazar Intercambio',
                onPressed: () => _gestionarIntercambio('rechazado'),
              ),
            Material(
              color: const Color(0xFFEF233C),
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _send,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.send, color: Colors.white, size: 24),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
