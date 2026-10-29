import 'nombre_persona.dart';

class Usuario {
  final int? id;

  /// Nombre completo (nombres + apellido paterno + apellido materno).
  final String nombre;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String email;
  final String username;

  /// Hash PBKDF2 (nunca texto plano).
  final String password;
  final String rol; // admin | editor | lector

  /// Teléfono ya descifrado (en la BD se guarda cifrado con AES-GCM).
  final String? telefono;
  final String proveedor; // local | google
  final int intentosFallidos;
  final DateTime? bloqueadoHasta;

  const Usuario({
    this.id,
    required this.nombre,
    this.nombres = '',
    this.apellidoPaterno = '',
    this.apellidoMaterno = '',
    required this.email,
    required this.username,
    required this.password,
    required this.rol,
    this.telefono,
    this.proveedor = 'local',
    this.intentosFallidos = 0,
    this.bloqueadoHasta,
  });

  /// Primer nombre, para saludos ("Hola, Juan").
  String get primerNombre {
    final base = nombres.trim().isNotEmpty ? nombres : nombre;
    final p = base.trim().split(RegExp(r'\s+'));
    return p.isEmpty ? '' : p.first;
  }

  /// Partes del nombre; si la cuenta es anterior a la separación, se deducen.
  NombrePersona get partesNombre => nombres.trim().isEmpty
      ? NombrePersona.desdeCompleto(nombre)
      : NombrePersona(
          nombres: nombres,
          apellidoPaterno: apellidoPaterno,
          apellidoMaterno: apellidoMaterno,
        );

  bool get esAdmin => rol == 'admin';
  bool get esEditor => rol == 'editor';
  bool get puedeGestionarProductos => rol == 'admin' || rol == 'editor';
  bool get tieneTelefono => (telefono ?? '').trim().isNotEmpty;

  bool get estaBloqueado =>
      bloqueadoHasta != null && bloqueadoHasta!.isAfter(DateTime.now());

  String get rolLegible => nombreRol(rol);

  static String nombreRol(String rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'editor':
        return 'Editor';
      default:
        return 'Comprador';
    }
  }

  String get tipoCuenta =>
      proveedor == 'google' ? 'Cuenta de Google' : 'Cuenta local';

  /// Construye desde la fila de SQLite. [telefonoPlano] llega ya descifrado.
  factory Usuario.fromMap(Map<String, dynamic> m, {String? telefonoPlano}) {
    final bloq = m['bloqueado_hasta'];
    final nombres = (m['nombres'] ?? '') as String;
    final paterno = (m['apellido_paterno'] ?? '') as String;
    final materno = (m['apellido_materno'] ?? '') as String;
    final completo = nombres.trim().isEmpty
        ? (m['nombre'] ?? '') as String
        : NombrePersona.unir(nombres, paterno, materno);
    return Usuario(
      id: m['id'] as int?,
      nombre: completo,
      nombres: nombres,
      apellidoPaterno: paterno,
      apellidoMaterno: materno,
      email: (m['email'] ?? '') as String,
      username: (m['username'] ?? '') as String,
      password: (m['password'] ?? '') as String,
      rol: (m['rol'] ?? 'lector') as String,
      telefono: telefonoPlano,
      proveedor: (m['proveedor'] ?? 'local') as String,
      intentosFallidos: (m['intentos_fallidos'] ?? 0) as int,
      bloqueadoHasta: bloq == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(bloq as int),
    );
  }

  Usuario copyWith({
    int? id,
    String? nombre,
    String? nombres,
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? email,
    String? username,
    String? password,
    String? rol,
    String? telefono,
    String? proveedor,
    int? intentosFallidos,
    DateTime? bloqueadoHasta,
    bool limpiarBloqueo = false,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nombres: nombres ?? this.nombres,
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      rol: rol ?? this.rol,
      telefono: telefono ?? this.telefono,
      proveedor: proveedor ?? this.proveedor,
      intentosFallidos: intentosFallidos ?? this.intentosFallidos,
      bloqueadoHasta:
          limpiarBloqueo ? null : (bloqueadoHasta ?? this.bloqueadoHasta),
    );
  }
}
