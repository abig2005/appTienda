import 'dart:convert';

class LineaCompra {
  final int productoId;
  final String nombre;
  final double precio;
  final int cantidad;

  const LineaCompra({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
  });

  double get subtotal => precio * cantidad;

  factory LineaCompra.fromJson(Map<String, dynamic> j) => LineaCompra(
        productoId: (j['producto_id'] as num?)?.toInt() ?? 0,
        nombre: (j['nombre'] ?? '').toString(),
        precio: (j['precio'] as num?)?.toDouble() ?? 0,
        cantidad: (j['cantidad'] as num?)?.toInt() ?? 1,
      );
}

class Compra {
  final int? id;
  final int usuarioId;
  final List<LineaCompra> productos;
  final double total;
  final DateTime fecha;
  final String transactionId;
  final String metodoPago;
  final String detallePago;
  final String estadoPago; // aprobado | pendiente

  // Solo para la vista de admin (JOIN con usuarios)
  final String? nombreUsuario;
  final String? emailUsuario;

  const Compra({
    this.id,
    required this.usuarioId,
    required this.productos,
    required this.total,
    required this.fecha,
    required this.transactionId,
    this.metodoPago = '',
    this.detallePago = '',
    this.estadoPago = 'aprobado',
    this.nombreUsuario,
    this.emailUsuario,
  });

  bool get pendiente => estadoPago == 'pendiente';

  factory Compra.fromMap(Map<String, dynamic> m) {
    List<LineaCompra> lineas = [];
    try {
      final data = jsonDecode((m['productos_json'] ?? '[]') as String);
      if (data is List) {
        lineas = data
            .whereType<Map>()
            .map((e) => LineaCompra.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return Compra(
      id: m['id'] as int?,
      usuarioId: m['usuario_id'] as int,
      productos: lineas,
      total: (m['total'] as num).toDouble(),
      fecha: DateTime.tryParse((m['fecha'] ?? '') as String) ?? DateTime.now(),
      transactionId: (m['transaction_id'] ?? '') as String,
      metodoPago: (m['metodo_pago'] ?? '') as String,
      detallePago: (m['detalle_pago'] ?? '') as String,
      estadoPago: (m['estado_pago'] ?? 'aprobado') as String,
      nombreUsuario: m['u_nombre'] as String?,
      emailUsuario: m['u_email'] as String?,
    );
  }
}
