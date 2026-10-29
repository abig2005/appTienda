class TipoNotificacion {
  static const seguridad = 'seguridad';
  static const compras = 'compras';
  static const promociones = 'promociones';
  static const sistema = 'sistema';

  static const todos = [seguridad, compras, promociones, sistema];

  static String nombre(String tipo) {
    switch (tipo) {
      case seguridad:
        return 'Seguridad';
      case compras:
        return 'Compras';
      case promociones:
        return 'Promociones';
      default:
        return 'Sistema';
    }
  }
}

class Notificacion {
  final int? id;
  final int? usuarioId;
  final String titulo;
  final String cuerpo;
  final String tipo;
  final bool leida;
  final DateTime fecha;

  const Notificacion({
    this.id,
    this.usuarioId,
    required this.titulo,
    required this.cuerpo,
    required this.tipo,
    this.leida = false,
    required this.fecha,
  });

  factory Notificacion.fromMap(Map<String, dynamic> m) => Notificacion(
        id: m['id'] as int?,
        usuarioId: m['usuario_id'] as int?,
        titulo: (m['titulo'] ?? '') as String,
        cuerpo: (m['cuerpo'] ?? '') as String,
        tipo: (m['tipo'] ?? 'sistema') as String,
        leida: (m['leida'] ?? 0) == 1,
        fecha: DateTime.tryParse((m['fecha'] ?? '') as String) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'usuario_id': usuarioId,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'tipo': tipo,
        'leida': leida ? 1 : 0,
        'fecha': fecha.toIso8601String(),
      };
}
