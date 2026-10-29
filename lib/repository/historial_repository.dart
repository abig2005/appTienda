import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/compra.dart';
import '../models/item_carrito.dart';
import 'database_helper.dart';

class HistorialRepository {
  HistorialRepository._();
  static final HistorialRepository instance = HistorialRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> registrar({
    required int usuarioId,
    required List<ItemCarrito> items,
    required double total,
    required String transactionId,
    required String metodoPago,
    required String detallePago,
    required String estadoPago,
  }) async {
    final db = await _db;
    return db.insert('historial_compras', {
      'usuario_id': usuarioId,
      'productos_json': jsonEncode(items.map((e) => e.toJsonCompra()).toList()),
      'total': total,
      'fecha': DateTime.now().toIso8601String(),
      'transaction_id': transactionId,
      'metodo_pago': metodoPago,
      'detalle_pago': detallePago,
      'estado_pago': estadoPago,
    });
  }

  Future<List<Compra>> deUsuario(int usuarioId) async {
    final db = await _db;
    final f = await db.query('historial_compras',
        where: 'usuario_id = ?', whereArgs: [usuarioId], orderBy: 'id DESC');
    return f.map(Compra.fromMap).toList();
  }

  /// Para el admin: todas las compras con nombre y correo del comprador.
  Future<List<Compra>> todas() async {
    final db = await _db;
    final f = await db.rawQuery('''
      SELECT h.*, u.nombre AS u_nombre, u.email AS u_email
      FROM historial_compras h
      LEFT JOIN usuarios u ON u.id = h.usuario_id
      ORDER BY h.id DESC
    ''');
    return f.map(Compra.fromMap).toList();
  }
}
