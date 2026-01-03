import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final currentUser = supabase.auth.currentUser!.id;

    // Obtener todos los mensajes donde yo participo
    final messages = await supabase
        .from('messages')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.$currentUser,receiver_id.eq.$currentUser');

    // Obtener IDs del otro usuario en cada conversación
    final ids = <String>{};
    for (final m in messages) {
      if (m['sender_id'] != currentUser) ids.add(m['sender_id']);
      if (m['receiver_id'] != currentUser) ids.add(m['receiver_id']);
    }

    if (ids.isEmpty) {
      setState(() => users = []);
      return;
    }

    // 🚀 CORRECCIÓN DEFINITIVA: usar FILTER con operador IN
    final data = await supabase
        .from('usuarios')
        .select('id, name, email')
        .filter('id', 'in', ids.toList());

    setState(() {
      users = List<Map<String, dynamic>>.from(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mis Chats',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFEF233C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes conversaciones',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Busca usuarios para comenzar a chatear',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEF233C),
                      child: Text(
                        u['name'][0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      u['name'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      u['email'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFEF233C),
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat-intercambio',
                        arguments: {
                          'otherUserId': u['id'],
                          'otherUserName': u['name'],
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
