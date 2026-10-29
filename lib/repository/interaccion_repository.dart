import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class InteraccionRepository {
  InteraccionRepository._();
  static final InteraccionRepository instance = InteraccionRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> registrar(int usuarioId, int productoId, String tipo) async {
    final db = await _db;
    await db.insert('interacciones', {
      'usuario_id': usuarioId,
      'producto_id': productoId,
      'tipo': tipo,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  /// Puntaje por categoría: vista = 1, carrito = 3, compra = 5.
  Future<Map<String, int>> puntajePorCategoria(int usuarioId) async {
    final db = await _db;
    final f = await db.rawQuery('''
      SELECT p.categoria AS categoria,
             SUM(CASE i.tipo WHEN 'vista' THEN 1 WHEN 'carrito' THEN 3 WHEN 'compra' THEN 5 ELSE 0 END) AS puntos
      FROM interacciones i
      JOIN productos p ON p.id = i.producto_id
      WHERE i.usuario_id = ?
      GROUP BY p.categoria
    ''', [usuarioId]);
    return {
      for (final r in f)
        (r['categoria'] ?? 'General') as String: (r['puntos'] as num).toInt()
    };
  }

  Future<Set<int>> productosComprados(int usuarioId) async {
    final db = await _db;
    final f = await db.query('interacciones',
        columns: ['producto_id'],
        where: "usuario_id = ? AND tipo = 'compra'",
        whereArgs: [usuarioId]);
    return f.map((e) => e['producto_id'] as int).toSet();
  }

  /// Popularidad global por producto (para usuarios sin historial).
  Future<Map<int, int>> popularidad() async {
    final db = await _db;
    final f = await db.rawQuery('''
      SELECT producto_id,
             SUM(CASE tipo WHEN 'vista' THEN 1 WHEN 'carrito' THEN 3 WHEN 'compra' THEN 5 ELSE 0 END) AS puntos
      FROM interacciones GROUP BY producto_id
    ''');
    return {
      for (final r in f)
        r['producto_id'] as int: (r['puntos'] as num).toInt()
    };
  }
}
