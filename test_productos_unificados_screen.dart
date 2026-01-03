import 'package:flutter/material.dart';
import '../services/productos_unificados_service.dart';
import '../modelo/producto_unificado_model.dart';

/// Pantalla de prueba para verificar que el sistema unificado funciona
class TestProductosUnificadosScreen extends StatefulWidget {
  const TestProductosUnificadosScreen({super.key});

  @override
  State<TestProductosUnificadosScreen> createState() => _TestProductosUnificadosScreenState();
}

class _TestProductosUnificadosScreenState extends State<TestProductosUnificadosScreen> {
  bool _isLoading = false;
  String _resultado = '';
  List<ProductoUnificado> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _isLoading = true;
      _resultado = 'Cargando productos...';
    });

    try {
      final result = await ProductosUnificadosService.getProductosDisponibles();
      
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _productos = result['data'] as List<ProductoUnificado>;
          _resultado = '✅ ${_productos.length} productos cargados correctamente';
        } else {
          _resultado = '❌ Error: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultado = '❌ Error: $e';
      });
    }
  }

  Future<void> _obtenerEstadisticas() async {
    setState(() {
      _isLoading = true;
      _resultado = 'Obteniendo estadísticas...';
    });

    try {
      final result = await ProductosUnificadosService.getEstadisticas();
      
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final stats = result['data'];
          _resultado = '''
✅ Estadísticas:
• Total: ${stats['total']}
• Aprobados: ${stats['aprobados']}
• Pendientes: ${stats['pendientes']}
• Disponibles: ${stats['disponibles']}
''';
        } else {
          _resultado = '❌ Error: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultado = '❌ Error: $e';
      });
    }
  }

  Future<void> _obtenerMisProductos() async {
    setState(() {
      _isLoading = true;
      _resultado = 'Obteniendo mis productos...';
    });

    try {
      final result = await ProductosUnificadosService.getMisProductos();
      
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final productos = result['data'] as List<ProductoUnificado>;
          _resultado = '✅ Tienes ${productos.length} productos';
        } else {
          _resultado = '❌ Error: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultado = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Sistema Unificado'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resultado
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultado:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resultado.isEmpty ? 'Presiona un botón para probar' : _resultado,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Botones de prueba
            const Text(
              'Pruebas:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _cargarProductos,
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Cargar Productos Disponibles'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _obtenerEstadisticas,
              icon: const Icon(Icons.bar_chart),
              label: const Text('Obtener Estadísticas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _obtenerMisProductos,
              icon: const Icon(Icons.person),
              label: const Text('Mis Productos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lista de productos
            if (_productos.isNotEmpty) ...[
              const Text(
                'Productos:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _productos.length,
                  itemBuilder: (context, index) {
                    final producto = _productos[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Text('${producto.puntosNecesarios}'),
                        ),
                        title: Text(producto.nombre),
                        subtitle: Text(
                          '${producto.categoria} • ${producto.getEstadoFisicoLabel()}',
                        ),
                        trailing: Chip(
                          label: Text(producto.getPuntosLabel()),
                          backgroundColor: Colors.teal.shade100,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
