import 'package:flutter/material.dart';
import 'package:trueque/screens/chat_screen.dart';
import 'package:trueque/services/chat_service.dart';
import 'package:trueque/screens/requests_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService service = ChatService();

  Map<String, dynamic>? userFound;

  bool _isSearching = false;
  String? _errorMessage;

  void search() async {
    final email = _controller.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa un email';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      userFound = null;
    });

    try {
      final user = await service.findUser(email);
      setState(() {
        userFound = user;
        _isSearching = false;
        if (user == null) {
          _errorMessage = 'Usuario no encontrado';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Error al buscar usuario: $e';
        userFound = null;
      });
      print('Error en búsqueda: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar usuario")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                label: Text("Correo del usuario"),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSearching ? null : search,
              child: _isSearching 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Buscar"),
            ),
            const SizedBox(height: 20),

            // Mostrar mensaje de error si existe
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            if (userFound != null)
              Card(
                child: ListTile(
                  title: Text(userFound!['name']),
                  subtitle: Text(userFound!['email']),
                  trailing: ElevatedButton(
                    child: const Text("Chatear"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: userFound!['id'],
                            otherUserName: userFound!['name'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
