class ItemCarrito {
  final int? id;
  final int usuarioId;
  final int productoId;
  final String nombre;
  final double precio;
  final int cantidad;
  final String imagen;

  const ItemCarrito({
    this.id,
    required this.usuarioId,
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    this.imagen = '',
  });

  double get subtotal => precio * cantidad;

  factory ItemCarrito.fromMap(Map<String, dynamic> m) => ItemCarrito(
        id: m['id'] as int?,
        usuarioId: m['usuario_id'] as int,
        productoId: m['producto_id'] as int,
        nombre: (m['nombre'] ?? '') as String,
        precio: (m['precio'] as num).toDouble(),
        cantidad: m['cantidad'] as int,
        imagen: (m['imagen'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'usuario_id': usuarioId,
        'producto_id': productoId,
        'nombre': nombre,
        'precio': precio,
        'cantidad': cantidad,
        'imagen': imagen,
      };

  Map<String, dynamic> toJsonCompra() => {
        'producto_id': productoId,
        'nombre': nombre,
        'precio': precio,
        'cantidad': cantidad,
      };
}
