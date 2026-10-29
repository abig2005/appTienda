import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../models/nombre_persona.dart';
import '../services/security_service.dart';

/// SQLite `seguridad.db`, versión 5, con migraciones que no pierden datos.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String nombreArchivo = 'seguridad.db';
  static const int version = 5;
  static const String passwordDemo = 'password123';

  Database? _db;
  Future<Database>? _abriendo;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _abriendo ??= _abrir();
    _db = await _abriendo;
    return _db!;
  }

  Future<Database> _abrir() async {
    final ruta = join(await getDatabasesPath(), nombreArchivo);
    return openDatabase(
      ruta,
      version: version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Esquema
  // ---------------------------------------------------------------------------

  static const _sqlUsuarios = '''
    CREATE TABLE usuarios (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      nombres TEXT NOT NULL DEFAULT '',
      apellido_paterno TEXT NOT NULL DEFAULT '',
      apellido_materno TEXT NOT NULL DEFAULT '',
      email TEXT NOT NULL UNIQUE,
      username TEXT,
      password TEXT NOT NULL,
      rol TEXT NOT NULL DEFAULT 'lector' CHECK (rol IN ('admin','editor','lector')),
      telefono TEXT,
      proveedor TEXT NOT NULL DEFAULT 'local',
      intentos_fallidos INTEGER NOT NULL DEFAULT 0,
      bloqueado_hasta INTEGER
    )''';

  static const _sqlProductos = '''
    CREATE TABLE IF NOT EXISTS productos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      precio REAL NOT NULL,
      stock INTEGER NOT NULL DEFAULT 0,
      imagen TEXT,
      categoria TEXT,
      descripcion TEXT,
      api_id INTEGER UNIQUE
    )''';

  static const _sqlProductosEliminados = '''
    CREATE TABLE IF NOT EXISTS productos_eliminados (
      api_id INTEGER PRIMARY KEY
    )''';

  static const _sqlCarrito = '''
    CREATE TABLE IF NOT EXISTS carrito (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL,
      producto_id INTEGER NOT NULL,
      nombre TEXT NOT NULL,
      precio REAL NOT NULL,
      cantidad INTEGER NOT NULL DEFAULT 1,
      imagen TEXT,
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )''';

  static const _sqlHistorialV2 = '''
    CREATE TABLE IF NOT EXISTS historial_compras (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL,
      productos_json TEXT NOT NULL,
      total REAL NOT NULL,
      fecha TEXT NOT NULL,
      transaction_id TEXT,
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )''';

  static const _sqlNotificaciones = '''
    CREATE TABLE IF NOT EXISTS notificaciones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER,
      titulo TEXT NOT NULL,
      cuerpo TEXT NOT NULL,
      tipo TEXT NOT NULL DEFAULT 'sistema',
      leida INTEGER NOT NULL DEFAULT 0,
      fecha TEXT NOT NULL,
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )''';

  static const _sqlInteracciones = '''
    CREATE TABLE IF NOT EXISTS interacciones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL,
      producto_id INTEGER NOT NULL,
      tipo TEXT NOT NULL CHECK (tipo IN ('vista','carrito','compra')),
      fecha TEXT NOT NULL,
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )''';

  static const _sqlIndiceUsername =
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_username ON usuarios(username)';

  Future<void> _onCreate(Database db, int v) async {
    await db.execute(_sqlUsuarios);
    await db.execute(_sqlIndiceUsername);
    await db.execute(_sqlProductos);
    await db.execute(_sqlProductosEliminados);
    await db.execute(_sqlCarrito);
    await db.execute(_sqlHistorialV2);
    await _agregarColumnasPago(db);
    await db.execute(_sqlNotificaciones);
    await db.execute(_sqlInteracciones);
    await _insertarUsuariosDemo(db);
  }

  Future<void> _onUpgrade(Database db, int anterior, int nueva) async {
    debugPrint('Migrando BD de v$anterior a v$nueva');
    if (anterior < 2) {
      await db.execute(_sqlProductos);
      await db.execute(_sqlProductosEliminados);
      await db.execute(_sqlCarrito);
      await db.execute(_sqlHistorialV2);
    }
    if (anterior < 3) {
      await _agregarColumna(db, 'usuarios', 'username', 'TEXT');
      await _agregarColumna(db, 'usuarios', 'telefono', 'TEXT');
      await _agregarColumna(
          db, 'usuarios', 'proveedor', "TEXT NOT NULL DEFAULT 'local'");
      await _agregarColumna(
          db, 'usuarios', 'intentos_fallidos', 'INTEGER NOT NULL DEFAULT 0');
      await _agregarColumna(db, 'usuarios', 'bloqueado_hasta', 'INTEGER');
      await db.execute(_sqlNotificaciones);
      await db.execute(_sqlInteracciones);
      await _migrarUsuariosV3(db);
      await db.execute(_sqlIndiceUsername);
    }
    if (anterior < 4) {
      await _agregarColumnasPago(db);
    }
    if (anterior < 5) {
      await _migrarNombresV5(db);
    }
  }

  /// v5: nombre separado en nombres, apellido paterno y apellido materno.
  /// Las cuentas existentes se separan a partir del nombre completo.
  Future<void> _migrarNombresV5(Database db) async {
    await _agregarColumna(db, 'usuarios', 'nombres', "TEXT NOT NULL DEFAULT ''");
    await _agregarColumna(
        db, 'usuarios', 'apellido_paterno', "TEXT NOT NULL DEFAULT ''");
    await _agregarColumna(
        db, 'usuarios', 'apellido_materno', "TEXT NOT NULL DEFAULT ''");
    final filas = await db.query('usuarios', columns: ['id', 'nombre']);
    for (final f in filas) {
      final n = NombrePersona.desdeCompleto((f['nombre'] ?? '') as String);
      await db.update(
        'usuarios',
        {
          'nombres': n.nombres,
          'apellido_paterno': n.apellidoPaterno,
          'apellido_materno': n.apellidoMaterno,
        },
        where: 'id = ?',
        whereArgs: [f['id']],
      );
    }
  }

  Future<void> _agregarColumnasPago(Database db) async {
    await _agregarColumna(db, 'historial_compras', 'metodo_pago', 'TEXT');
    await _agregarColumna(db, 'historial_compras', 'detalle_pago', 'TEXT');
    await _agregarColumna(db, 'historial_compras', 'estado_pago',
        "TEXT NOT NULL DEFAULT 'aprobado'");
  }

  Future<void> _agregarColumna(
      Database db, String tabla, String columna, String tipo) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    final existe = info.any((c) => c['name'] == columna);
    if (!existe) {
      await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $tipo');
    }
  }

  /// v3: username único desde el correo y contraseñas en texto plano → hash.
  Future<void> _migrarUsuariosV3(Database db) async {
    final filas = await db.query('usuarios');
    final usados = <String>{};
    for (final f in filas) {
      final actual = (f['username'] as String?)?.trim();
      final username = (actual != null && actual.isNotEmpty)
          ? actual.toLowerCase()
          : _usernameUnico(f['email'] as String, usados);
      usados.add(username);
      final pass = f['password'] as String;
      final hash = SecurityService.esHash(pass)
          ? pass
          : await SecurityService.instance.hashPassword(pass);
      await db.update(
        'usuarios',
        {'username': username, 'password': hash},
        where: 'id = ?',
        whereArgs: [f['id']],
      );
    }
  }

  static String _usernameUnico(String email, Set<String> usados) {
    final base = usernameDesdeCorreo(email);
    var candidato = base;
    var n = 1;
    while (usados.contains(candidato)) {
      n++;
      candidato = '$base$n';
    }
    return candidato;
  }

  static String usernameDesdeCorreo(String email) {
    final local = email.split('@').first.split('+').first.toLowerCase();
    final limpio = local.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return limpio.isEmpty ? 'usuario' : limpio;
  }

  // ---------------------------------------------------------------------------
  // Usuarios de prueba
  // ---------------------------------------------------------------------------

  static List<Map<String, String>> get _demos => [
        {
          'username': 'juan',
          'nombres': 'Juan',
          'paterno': 'Pérez',
          'materno': 'Gómez',
          'rol': 'admin',
          'email': AppConfig.demoAdminEmail,
          'tel': AppConfig.demoAdminTelefono,
        },
        {
          'username': 'pedro',
          'nombres': 'Pedro',
          'paterno': 'López',
          'materno': 'Ramírez',
          'rol': 'editor',
          'email': AppConfig.demoEditorEmail,
          'tel': AppConfig.demoEditorTelefono,
        },
        {
          'username': 'ana',
          'nombres': 'Ana',
          'paterno': 'García',
          'materno': 'Torres',
          'rol': 'lector',
          'email': AppConfig.demoLectorEmail,
          'tel': AppConfig.demoLectorTelefono,
        },
      ];

  static String _correoDemo(Map<String, String> d) {
    final e = d['email']!.trim().toLowerCase();
    return e.isEmpty ? '${d['username']}@gmail.com' : e;
  }

  Future<void> _insertarUsuariosDemo(Database db) async {
    final sec = SecurityService.instance;
    for (final d in _demos) {
      final tel = d['tel']!.trim();
      await db.insert('usuarios', {
        'nombre': NombrePersona.unir(d['nombres']!, d['paterno']!, d['materno']!),
        'nombres': d['nombres'],
        'apellido_paterno': d['paterno'],
        'apellido_materno': d['materno'],
        'email': _correoDemo(d),
        'username': d['username'],
        'password': await sec.hashPassword(passwordDemo),
        'rol': d['rol'],
        'telefono': tel.isEmpty ? null : await sec.cifrar(tel),
        'proveedor': 'local',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Al iniciar: actualiza correo/teléfono de juan, pedro y ana según
  /// `config/env.json`, sin chocar con correos que ya use otra cuenta.
  Future<void> sincronizarUsuariosDemo() async {
    final db = await database;
    final sec = SecurityService.instance;
    for (final d in _demos) {
      final filas = await db.query('usuarios',
          where: 'username = ?', whereArgs: [d['username']], limit: 1);
      if (filas.isEmpty) continue; // el admin la eliminó: respetamos eso
      final fila = filas.first;
      final id = fila['id'] as int;
      final cambios = <String, Object?>{};

      final configurado = d['email']!.trim().toLowerCase();
      if (configurado.isNotEmpty && configurado != fila['email']) {
        final ocupado = await db.query('usuarios',
            where: 'email = ? AND id <> ?', whereArgs: [configurado, id]);
        if (ocupado.isEmpty) {
          cambios['email'] = configurado;
        } else {
          debugPrint('Correo demo $configurado ya está en uso; se omite.');
        }
      }

      final tel = d['tel']!.trim();
      if (tel.isNotEmpty) {
        final actual = await sec.descifrar(fila['telefono'] as String?);
        if (actual != tel) cambios['telefono'] = await sec.cifrar(tel);
      }

      if (cambios.isNotEmpty) {
        await db.update('usuarios', cambios,
            where: 'id = ?', whereArgs: [id]);
      }
    }
  }
}
