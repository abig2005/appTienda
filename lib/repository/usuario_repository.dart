import 'package:sqflite/sqflite.dart';

import '../models/nombre_persona.dart';
import '../models/usuario.dart';
import '../services/security_service.dart';
import 'database_helper.dart';

class UsuarioRepository {
  UsuarioRepository._();
  static final UsuarioRepository instance = UsuarioRepository._();

  final _sec = SecurityService.instance;
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<Usuario> _mapear(Map<String, dynamic> fila) async {
    final tel = await _sec.descifrar(fila['telefono'] as String?);
    return Usuario.fromMap(fila, telefonoPlano: tel.isEmpty ? null : tel);
  }

  Future<List<Usuario>> todos() async {
    final db = await _db;
    final filas = await db.query('usuarios', orderBy: 'rol, apellido_paterno, apellido_materno, nombres');
    return Future.wait(filas.map(_mapear));
  }

  Future<Usuario?> porId(int id) async {
    final db = await _db;
    final f = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    return f.isEmpty ? null : _mapear(f.first);
  }

  Future<Usuario?> porEmail(String email) async {
    final db = await _db;
    final f = await db.query('usuarios',
        where: 'LOWER(email) = ?', whereArgs: [email.trim().toLowerCase()]);
    return f.isEmpty ? null : _mapear(f.first);
  }

  Future<Usuario?> porUsername(String username) async {
    final db = await _db;
    final u = username.trim().toLowerCase().replaceFirst('@', '');
    final f = await db.query('usuarios',
        where: 'LOWER(username) = ?', whereArgs: [u]);
    return f.isEmpty ? null : _mapear(f.first);
  }

  /// Busca por correo o por nombre de usuario.
  Future<Usuario?> porIdentificador(String identificador) async {
    final t = identificador.trim();
    if (t.isEmpty) return null;
    if (t.contains('@') && !t.startsWith('@')) return porEmail(t);
    return porUsername(t);
  }

  /// Busca cuentas cuyo teléfono (descifrado) coincida en sus últimos 10 dígitos.
  Future<List<Usuario>> porTelefono(String telefono) async {
    final buscado = _ultimos10(telefono);
    if (buscado.length < 10) return [];
    final lista = await todos();
    return lista.where((u) => _ultimos10(u.telefono ?? '') == buscado).toList();
  }

  static String _ultimos10(String t) {
    final d = t.replaceAll(RegExp(r'\D'), '');
    return d.length <= 10 ? d : d.substring(d.length - 10);
  }

  Future<bool> emailEnUso(String email, {int? excepto}) async {
    final db = await _db;
    final f = await db.query('usuarios',
        where: 'LOWER(email) = ? AND id <> ?',
        whereArgs: [email.trim().toLowerCase(), excepto ?? -1]);
    return f.isNotEmpty;
  }

  Future<bool> usernameEnUso(String username, {int? excepto}) async {
    final db = await _db;
    final f = await db.query('usuarios',
        where: 'LOWER(username) = ? AND id <> ?',
        whereArgs: [username.trim().toLowerCase(), excepto ?? -1]);
    return f.isNotEmpty;
  }

  /// Sugiere un username libre a partir del correo.
  Future<String> sugerirUsername(String email) async {
    final base = DatabaseHelper.usernameDesdeCorreo(email);
    var candidato = base;
    var n = 1;
    while (await usernameEnUso(candidato)) {
      n++;
      candidato = '$base$n';
    }
    return candidato;
  }

  /// Inserta. [passwordHash] ya debe venir hasheado.
  Future<int> insertar({
    required NombrePersona nombre,
    required String email,
    required String username,
    required String passwordHash,
    required String rol,
    String? telefono,
    String proveedor = 'local',
  }) async {
    final db = await _db;
    final tel = (telefono ?? '').trim();
    return db.insert('usuarios', {
      ..._columnasNombre(nombre),
      'email': email.trim().toLowerCase(),
      'username': username.trim().toLowerCase(),
      'password': passwordHash,
      'rol': rol,
      'telefono': tel.isEmpty ? null : await _sec.cifrar(tel),
      'proveedor': proveedor,
    });
  }

  Future<void> actualizarDatos(
    int id, {
    NombrePersona? nombre,
    String? email,
    String? username,
    String? telefono,
    String? rol,
  }) async {
    final db = await _db;
    final cambios = <String, Object?>{};
    if (nombre != null) cambios.addAll(_columnasNombre(nombre));
    if (email != null) cambios['email'] = email.trim().toLowerCase();
    if (username != null) cambios['username'] = username.trim().toLowerCase();
    if (rol != null) cambios['rol'] = rol;
    if (telefono != null) {
      final t = telefono.trim();
      cambios['telefono'] = t.isEmpty ? null : await _sec.cifrar(t);
    }
    if (cambios.isEmpty) return;
    await db.update('usuarios', cambios, where: 'id = ?', whereArgs: [id]);
  }

  /// Columnas de nombre: las tres partes (capitalizadas) y el nombre completo.
  static Map<String, Object?> _columnasNombre(NombrePersona n) {
    final nombres = NombrePersona.capitalizar(n.nombres);
    final paterno = NombrePersona.capitalizar(n.apellidoPaterno);
    final materno = NombrePersona.capitalizar(n.apellidoMaterno);
    return {
      'nombre': NombrePersona.unir(nombres, paterno, materno),
      'nombres': nombres,
      'apellido_paterno': paterno,
      'apellido_materno': materno,
    };
  }

  Future<void> actualizarPassword(int id, String hash) async {
    final db = await _db;
    await db.update(
        'usuarios',
        {
          'password': hash,
          'intentos_fallidos': 0,
          'bloqueado_hasta': null,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> registrarIntentoFallido(int id, int intentos,
      {DateTime? bloquearHasta}) async {
    final db = await _db;
    await db.update(
        'usuarios',
        {
          'intentos_fallidos': intentos,
          'bloqueado_hasta': bloquearHasta?.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> desbloquear(int id) async {
    final db = await _db;
    await db.update('usuarios',
        {'intentos_fallidos': 0, 'bloqueado_hasta': null},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }
}
