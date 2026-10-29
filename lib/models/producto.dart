import 'package:xml/xml.dart';

class Producto {
  final int? id;

  final String nombre;
  final double precio;
  final int stock;
  final String imagen;
  final String categoria;
  final String descripcion;

  /// ID del producto en la API.
  /// NULL = producto creado localmente.
  final int? apiId;

  const Producto({
    this.id,
    required this.nombre,
    required this.precio,
    this.stock = 10,
    this.imagen = '',
    this.categoria = 'General',
    this.descripcion = '',
    this.apiId,
  });

  /// Indica si el producto fue creado localmente.
  bool get esLocal => apiId == null;

  /// Convierte un registro de SQLite en un objeto Producto.
  factory Producto.fromMap(Map<String, dynamic> m) {
    return Producto(
      id: m['id'] as int?,
      nombre: (m['nombre'] ?? '') as String,
      precio: (m['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (m['stock'] as int?) ?? 0,
      imagen: (m['imagen'] ?? '') as String,
      categoria: (m['categoria'] ?? 'General') as String,
      descripcion: (m['descripcion'] ?? '') as String,
      apiId: m['api_id'] as int?,
    );
  }

  /// Convierte un producto de Fake Store API (JSON) en Producto.
  factory Producto.fromApi(Map<String, dynamic> j) {
    final cat = (j['category'] ?? 'general').toString();

    return Producto(
      apiId: (j['id'] as num).toInt(),
      nombre: (j['title'] ?? '').toString(),
      precio: (j['price'] as num?)?.toDouble() ?? 0.0,
      stock: 20,
      imagen: (j['image'] ?? '').toString(),
      categoria: traducirCategoria(cat),
      descripcion: (j['description'] ?? '').toString(),
    );
  }

  /// Convierte un producto del XML de Gesto Pago en Producto.
  factory Producto.fromXml(XmlElement element) {
    final servicio = element.getAttribute('servicio') ?? '';
    final nombreProducto = element.getAttribute('producto') ?? '';

    final idProducto = int.tryParse(element.getAttribute('idProducto') ?? '');

    final precio = double.tryParse(element.getAttribute('precio') ?? '') ?? 0.0;

    final legend = element.getElement('legend')?.innerText.trim() ?? '';

    return Producto(
      nombre: nombreProducto,
      precio: precio,
      stock: 0,
      imagen: '',
      categoria: servicio.isEmpty ? 'General' : servicio,
      descripcion: legend,
      apiId: idProducto,
    );
  }

  /// Traduce las categorías de Fake Store API al español.
  static String traducirCategoria(String c) {
    switch (c.toLowerCase()) {
      case "men's clothing":
        return 'Ropa de hombre';

      case "women's clothing":
        return 'Ropa de mujer';

      case 'jewelery':
      case 'jewelry':
        return 'Joyería';

      case 'electronics':
        return 'Electrónica';

      default:
        if (c.isEmpty) return 'General';

        return c[0].toUpperCase() + c.substring(1);
    }
  }

  /// Convierte el objeto Producto en un Map para SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'imagen': imagen,
      'categoria': categoria,
      'descripcion': descripcion,
      'api_id': apiId,
    };
  }
}
