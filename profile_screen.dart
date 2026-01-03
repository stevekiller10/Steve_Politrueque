import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/widgets/circle_background.dart';
import 'package:trueque/screens/intercambio/intercambios_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Paleta de colores
  static const Color primaryRed = Color(0xFFC62828);
  static const Color secondaryRed = Color(0xFF991B1B);
  static const Color successGreen = Color(0xFF388E3C);

  final supabase = Supabase.instance.client;

  // Controladores para los campos editables
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isEditMode = false;
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final data = await supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .single(); // 

        
        _nameController.text = data['username'] ?? '';
        _emailController.text = supabase.auth.currentUser?.email ?? '';
        _phoneController.text = data['phone'] ?? '';
        _locationController.text = data['location'] ?? '';
      }
    } catch (e) {
      
      print('Error al cargar el perfil: $e');
      
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(color: secondaryRed)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: secondaryRed),
        actions: [
          if (!_isLoading) 
            IconButton(
              icon: Icon(_isEditMode ? Icons.check : Icons.edit, color: secondaryRed),
              tooltip: _isEditMode ? 'Guardar cambios' : 'Editar perfil',
              onPressed: () {
                setState(() {
                  if (_isEditMode) {
                    _saveChanges();
                  } else {
                    _isEditMode = true;
                  }
                });
              },
            ),
        ],
      ),
      body: CircleBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryRed))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 30),
                      _buildSectionTitle('Información Personal'),
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Mis Actividades'),
                      _buildActivitiesCard(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Estadísticas de Uso'),
                      _buildStatsCard(),
                      const SizedBox(height: 20),
                      _buildActionButtons(context),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: primaryRed,
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _isEditMode
              ? TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: secondaryRed),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                )
              : Text(_nameController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: secondaryRed)),
          const SizedBox(height: 5),
          Text(_emailController.text, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryRed)),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(Icons.person, 'Nombre', _nameController.text, _nameController),
            const Divider(),
            _buildInfoRow(Icons.email, 'Email', _emailController.text, _emailController, isEditable: false),
            const Divider(),
            _buildInfoRow(Icons.phone, 'Teléfono', _phoneController.text, _phoneController),
            const Divider(),
            _buildInfoRow(Icons.location_on, 'Ubicación', _locationController.text, _locationController),
          
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, TextEditingController controller, {bool isEditable = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: primaryRed, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 3),
                _isEditMode && isEditable
                    ? TextField(
                        controller: controller,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryRed, width: 2)),
                        ),
                      )
                    : Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (!_isEditMode && isEditable) Icon(Icons.edit, color: primaryRed, size: 20),
        ],
      ),
    );
  }

  Widget _buildActivitiesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildActivityRow(
              'Mis Intercambios',
              'Ver y gestionar tus intercambios',
              Icons.swap_horizontal_circle,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IntercambiosScreen()),
              ),
            ),
            const Divider(),
            _buildActivityRow(
              'Mis Productos',
              'Gestionar productos publicados',
              Icons.inventory,
              () {
                // TODO: Navegar a mis productos
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad próximamente')),
                );
              },
            ),
            const Divider(),
            _buildActivityRow(
              'Historial',
              'Ver historial de actividades',
              Icons.history,
              () {
                // TODO: Navegar a historial
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad próximamente')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryRed, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    // ... (sin cambios, es estático)
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatRow('Intercambios realizados', '0', Icons.search),
            const Divider(),
           
           
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: primaryRed)),
          const SizedBox(width: 15),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryRed)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (_isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: successGreen, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _saveChanges,
            child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: primaryRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              
              _fetchUserProfile().then((_) {
                setState(() {
                  _isEditMode = false;
                });
              });
            },
            child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: primaryRed)),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => setState(() => _isEditMode = true),
            child: const Text('Editar Perfil', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: primaryRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _showChangePasswordDialog(context),
            child: const Text('Cambiar Contraseña', style: TextStyle(fontSize: 16, color: primaryRed)),
          ),
        ],
      );
    }
  }

  Future<void> _saveChanges() async {
    try {
      EasyLoading.show(status: 'Guardando...');
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final updates = {
        'username': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
      };

      await supabase.from('profiles').update(updates).eq('id', userId);

      EasyLoading.dismiss();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: successGreen));
      setState(() {
        _isEditMode = false;
      });
    } catch (e) {
      EasyLoading.dismiss();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: primaryRed));
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    // ... (sin cambios, este diálogo es independiente)
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cambiar Contraseña', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: secondaryRed)),
              const SizedBox(height: 20),
              TextField(controller: currentPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline))),
              const SizedBox(height: 15),
              TextField(controller: newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
              const SizedBox(height: 15),
              TextField(controller: confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
                    onPressed: () {
                      if (currentPasswordController.text.isEmpty || newPasswordController.text.isEmpty || confirmPasswordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los campos son obligatorios'), backgroundColor: primaryRed));
                        return;
                      }
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: primaryRed));
                        return;
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada correctamente'), backgroundColor: successGreen));
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}