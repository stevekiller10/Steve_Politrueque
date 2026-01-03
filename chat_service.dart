import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final supabase = Supabase.instance.client;

  /// ENVIAR MENSAJE
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    await supabase.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': text,
    });
  }

  /// STREAM SIN FILTROS (Supabase 2.10)
  Stream<List<Map<String, dynamic>>> listenMessages() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id']);
  }

  /// BUSCAR USUARIO POR EMAIL
  Future<Map<String, dynamic>?> findUser(String email) async {
    final res = await supabase
        .from('usuarios')
        .select()
        .eq('email', email)
        .maybeSingle();

    return res;
  }

  Future<void> acceptRequest(reqId) async {}

  Future<void> rejectRequest(reqId) async {}

  Future getReceivedRequests(String id) async {}
}
