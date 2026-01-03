import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/services/user_role_service.dart';
import 'package:trueque/screens/chat_list_screen.dart';
import 'package:trueque/screens/search_user_screen.dart';
import 'package:trueque/screens/search_products_screen.dart';
import 'package:trueque/screens/intercambio/puntos_intercambio_screen.dart';
import 'package:trueque/screens/profile_screen.dart';
import 'package:trueque/screens/mapa_unificado_screen.dart';
import 'package:trueque/widgets/puntos_widget.dart';
import 'package:trueque/screens/mis_puntos_screen.dart';
import 'package:trueque/screens/geolocalizacion_screen.dart';
import 'package:trueque/screens/notificaciones_screen.dart';
import 'login_screen.dart';
import 'user_management_screen.dart';
import 'objects_screen.dart';
import 'approval_screen.dart';
import 'items_list_screen.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int count;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.count = 0,
  });
}

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDarkMode = false;
  late UserModel _currentUser;
  late String _originalRole;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Category> _categoryList = [];

  int _unreadNotificationCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _originalRole = widget.user.rol;
    _refreshUserData();
    _setupNotificationStream();
    _startRoleMonitoring();
    _loadCategories();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notificationSubscription?.cancel();
    UserRoleService.stopRoleMonitoring();
    super.dispose();
  }

  Future<void> _refreshUserData() async {
    try {
      final userData = await Supabase.instance.client
          .from('usuarios')
          .select()
          .eq('id', _currentUser.id)
          .single();
      
      if (mounted) {
        setState(() {
          _currentUser = UserModel.fromJson(userData);
        });
      }
    } catch (e) {
      // Consider logging this error to a service instead of printing
    }
  }

  Future<void> _loadCategories() async {
    const baseCategories = [
      {'id': 'Electrónicos', 'name': 'Electrónicos', 'icon': Icons.phone_android, 'color': Color(0xFFEF233C)},
      {'id': 'Comida', 'name': 'Comida', 'icon': Icons.restaurant, 'color': Color(0xFFD90429)},
      {'id': 'Ropa', 'name': 'Ropa', 'icon': Icons.checkroom, 'color': Color(0xFFC1121F)},
      {'id': 'Útiles Escolares', 'name': 'Útiles Escolares', 'icon': Icons.school, 'color': Color(0xFFB91C1C)},
      {'id': 'Deportes', 'name': 'Deportes', 'icon': Icons.sports_soccer, 'color': Color(0xFF991B1B)},
      {'id': 'Hogar', 'name': 'Hogar', 'icon': Icons.home, 'color': Color(0xFF8D0801)},
      {'id': 'Otros', 'name': 'Otros', 'icon': Icons.toys, 'color': Color(0xFFDC2626)},
    ];

    try {
      final response = await Supabase.instance.client
          .from('productos_unificados')
          .select('categoria')
          .eq('disponible', true)
          .neq('usuario_id', _currentUser.id);

      final categoryCounts = <String, int>{};
      for (final item in response as List) {
        final categoryName = item['categoria'] as String?;
        if (categoryName != null) {
          categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
        }
      }

      final updatedCategories = baseCategories.map((catData) {
        final categoryName = catData['name'] as String;
        return Category(
          id: catData['id'] as String,
          name: categoryName,
          icon: catData['icon'] as IconData,
          color: catData['color'] as Color,
          count: categoryCounts[categoryName] ?? 0,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _categoryList = updatedCategories;
        });
      }
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las categorías: $e')),
        );
      }
    }
  }

  void _startRoleMonitoring() {
    UserRoleService.startRoleMonitoring(
      userId: _currentUser.id,
      currentRole: _currentUser.rol,
      onRoleChanged: _onRoleChanged,
    );
  }

  void _onRoleChanged(UserModel updatedUser) {
    if (!mounted) return;

    setState(() {
      _currentUser = updatedUser;
    });

    _showRoleChangeNotification(updatedUser.rol);

    UserRoleService.startRoleMonitoring(
      userId: _currentUser.id,
      currentRole: _currentUser.rol,
      onRoleChanged: _onRoleChanged,
    );
  }

  void _showRoleChangeNotification(String newRole) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Tu rol ha sido actualizado a $newRole!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setupNotificationStream() {
    final supabase = Supabase.instance.client;
    final userId = _currentUser.id;

    _notificationSubscription = supabase
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (mounted) {
            final unreadCount = data.where((notification) {
              return notification['user_id'] == userId &&
                     notification['is_read'] == false && 
                     notification['is_hidden'] == false;
            }).length;

            setState(() {
              _unreadNotificationCount = unreadCount;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Poli-Trueque', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFEF233C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: PuntosWidget(
              userId: _currentUser.id,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MisPuntosScreen())),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchProductsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen())),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFEF233C), const Color(0xCCEF233C), Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¡Hola, ${_currentUser.nombreCompleto}!', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('¿Qué quieres intercambiar hoy?', style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70)),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Categorías', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFEF233C))),
                          const SizedBox(height: 16),
                          Expanded(child: _buildCategoriesGrid()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_categoryList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _categoryList.length,
      itemBuilder: (context, index) => _buildCategoryCard(_categoryList[index]),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemsListScreen(category: category, currentUser: _currentUser)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: category.color.withAlpha(25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Icon(category.icon, size: 40, color: category.color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.count} producto${category.count != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          children: [
            _buildUserHeader(),
            const Divider(height: 1),
            Expanded(child: _buildMenuItems()),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFEF233C), Color(0xFFD91F38)]), shape: BoxShape.circle),
            child: Center(child: Text(_currentUser.getInitials(), style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting(), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(_currentUser.nombreCompleto, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: _getRoleColor(_currentUser.rol), borderRadius: BorderRadius.circular(20)),
                      child: Text(_getRoleDisplayName(_currentUser.rol), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                      onPressed: _manualRoleCheck,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildMenuSectionTitle('MENÚ PRINCIPAL'),
        _buildMenuItem(Icons.home, 'Inicio', () {}),
        _buildMenuItem(Icons.search, 'Buscar Productos', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchProductsScreen()));
        }),
        _buildMenuItem(Icons.swap_horiz, 'Mis Objetos', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => ObjectsScreen(currentUser: _currentUser)));
        }),
        _buildMenuItem(Icons.person, 'Mi Perfil', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }),
        _buildMenuItem(Icons.repeat, 'Mis Intercambios', () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/intercambios');
        }),
        _buildMenuSectionTitle('HERRAMIENTAS'),
        _buildMenuItem(Icons.stars, 'Mis Puntos', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MisPuntosScreen()));
        }),
        _buildMenuItem(Icons.map, 'Mapa Interactivo', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaUnificadoScreen()));
        }),
        _buildMenuItem(Icons.location_on, 'Puntos de Encuentro', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PuntosIntercambioScreen()));
        }),
        _buildMenuSectionTitle('COMUNICACIÓN'),
        _buildMenuItem(Icons.chat_bubble, 'Mensajes', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
        }),
        _buildMenuItemWithBadge(
          Icons.notifications,
          'Notificaciones',
          _unreadNotificationCount,
          () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
          },
        ),
        if (_canChangeRole()) ...[
          _buildMenuSectionTitle('ADMINISTRACIÓN'),
          if (_currentUser.rol.toLowerCase() == 'admin' || _currentUser.rol.toLowerCase() == 'administrador')
            _buildMenuItem(Icons.people, 'Gestión de Usuarios', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
            }),
          _buildMenuItem(Icons.fact_check, 'Revisar Objetos', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => ApprovalScreen(currentUser: _currentUser)));
          }),
          _buildMenuItem(Icons.admin_panel_settings, 'Cambiar Rol', _showRoleChangeDialog),
        ],
        _buildMenuSectionTitle('CONFIGURACIÓN'),
        _buildSettingItem(Icons.dark_mode, 'Modo Oscuro', _isDarkMode, (value) => setState(() => _isDarkMode = value)),
      ],
    );
  }

  Widget _buildMenuSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.grey.shade700),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildMenuItemWithBadge(IconData icon, String title, int badgeCount, VoidCallback onTap) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          if (badgeCount > 0)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: badgeCount > 0 ? FontWeight.w600 : FontWeight.w500, color: Colors.grey.shade700)),
      trailing: badgeCount > 0 ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.blue.withAlpha(25), borderRadius: BorderRadius.circular(12)),
        child: Text('$badgeCount', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
      ) : null,
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, size: 20, color: Colors.grey.shade700),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: const Color(0xFFEF233C),
      dense: true,
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextButton.icon(
        onPressed: () async {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
          }
        },
        icon: const Icon(Icons.logout),
        label: Text('Cerrar Sesión', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF233C)),
      ),
    );
  }

  bool _canChangeRole() {
    final role = _originalRole.toLowerCase();
    return role == 'admin' || role == 'administrador' || role == 'moderador';
  }

  Color _getRoleColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin':
      case 'administrador': return const Color(0xFFEF233C);
      case 'moderador': return const Color(0xFFF59E0B);
      default: return Colors.blue;
    }
  }

  void _showRoleChangeDialog() {
    List<String> availableRoles = ['Usuario'];
    final role = _originalRole.toLowerCase();
    if (role == 'admin' || role == 'administrador') {
      availableRoles = ['Administrador', 'Moderador', 'Usuario'];
    } else if (role == 'moderador') {
      availableRoles = ['Moderador', 'Usuario'];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.admin_panel_settings, color: Color(0xFFEF233C)), SizedBox(width: 12), Text('Cambiar Rol', style: GoogleFonts.poppins())]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableRoles.map((role) => ListTile(
            title: Text(role, style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _changeRole(role);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _changeRole(String newRole) {
    setState(() {
      _currentUser = UserModel(
        id: _currentUser.id,
        nombreCompleto: _currentUser.nombreCompleto,
        correoElectronico: _currentUser.correoElectronico,
        rol: newRole,
        createdAt: _currentUser.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> _manualRoleCheck() async {
    try {
      final updatedUser = await UserRoleService.checkRoleNow(_currentUser.id);
      if (updatedUser != null && updatedUser.rol != _currentUser.rol) {
        _onRoleChanged(updatedUser);
      }
    } catch (e) {
      // Consider logging this error to a service
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '¡Buenos días!';
    if (hour < 19) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrador': return 'Administrador';
      case 'moderador': return 'Moderador';
      default: return 'Usuario';
    }
  }
}
