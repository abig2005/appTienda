import 'package:sqflite/sqflite.dart';

import '../models/notificacion.dart';
import 'database_helper.dart';

class NotificacionRepository {
  NotificacionRepository._();
  static final NotificacionRepository instance = NotificacionRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insertar(Notificacion n) async {
    final db = await _db;
    return db.insert('notificaciones', n.toMap());
  }

  /// Notificaciones del usuario más las generales (usuario_id NULL).
  Future<List<Notificacion>> deUsuario(int? usuarioId) async {
    final db = await _db;
    final f = await db.query(
      'notificaciones',
      where: 'usuario_id = ? OR usuario_id IS NULL',
      whereArgs: [usuarioId ?? -1],
      orderBy: 'id DESC',
      limit: 200,
    );
    return f.map(Notificacion.fromMap).toList();
  }

  Future<int> noLeidas(int? usuarioId) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM notificaciones WHERE leida = 0 AND (usuario_id = ? OR usuario_id IS NULL)',
          [usuarioId ?? -1],
        )) ??
        0;
  }

  Future<void> marcarLeidas(int? usuarioId) async {
    final db = await _db;
    await db.update('notificaciones', {'leida': 1},
        where: 'usuario_id = ? OR usuario_id IS NULL',
        whereArgs: [usuarioId ?? -1]);
  }

  Future<void> marcarLeida(int id) async {
    final db = await _db;
    await db.update('notificaciones', {'leida': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('notificaciones', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> borrarTodas(int? usuarioId) async {
    final db = await _db;
    await db.delete('notificaciones',
        where: 'usuario_id = ? OR usuario_id IS NULL',
        whereArgs: [usuarioId ?? -1]);
  }
}
