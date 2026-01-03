import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final chatService = ChatService();
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  void loadRequests() async {
    final id = Supabase.instance.client.auth.currentUser!.id;
    final data = await chatService.getReceivedRequests(id);

    setState(() => requests = data);
  }

  void accept(reqId) async {
    await chatService.acceptRequest(reqId);
    loadRequests();
  }

  void reject(reqId) async {
    await chatService.rejectRequest(reqId);
    loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Solicitudes")),
      body: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (_, i) {
          final r = requests[i];

          return Card(
            child: ListTile(
              title: Text(r['usuarios']['name']),
              subtitle: const Text("Quiere agregarte"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => accept(r['id']),
                    icon: const Icon(Icons.check, color: Colors.green),
                  ),
                  IconButton(
                    onPressed: () => reject(r['id']),
                    icon: const Icon(Icons.close, color: Colors.red),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
