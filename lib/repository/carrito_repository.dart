import 'package:sqflite/sqflite.dart';

import '../models/item_carrito.dart';
import '../models/producto.dart';
import 'database_helper.dart';

class CarritoRepository {
  CarritoRepository._();
  static final CarritoRepository instance = CarritoRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<ItemCarrito>> deUsuario(int usuarioId) async {
    final db = await _db;
    final f = await db.query('carrito',
        where: 'usuario_id = ?', whereArgs: [usuarioId], orderBy: 'id');
    return f.map(ItemCarrito.fromMap).toList();
  }

  Future<void> agregar(int usuarioId, Producto p, int cantidad) async {
    final db = await _db;
    final existe = await db.query('carrito',
        where: 'usuario_id = ? AND producto_id = ?',
        whereArgs: [usuarioId, p.id]);
    if (existe.isEmpty) {
      await db.insert(
        'carrito',
        ItemCarrito(
          usuarioId: usuarioId,
          productoId: p.id!,
          nombre: p.nombre,
          precio: p.precio,
          cantidad: cantidad,
          imagen: p.imagen,
        ).toMap(),
      );
    } else {
      await db.rawUpdate(
        'UPDATE carrito SET cantidad = cantidad + ? WHERE id = ?',
        [cantidad, existe.first['id']],
      );
    }
  }

  Future<void> cambiarCantidad(int itemId, int cantidad) async {
    final db = await _db;
    if (cantidad <= 0) {
      await db.delete('carrito', where: 'id = ?', whereArgs: [itemId]);
    } else {
      await db.update('carrito', {'cantidad': cantidad},
          where: 'id = ?', whereArgs: [itemId]);
    }
  }

  Future<void> quitar(int itemId) async {
    final db = await _db;
    await db.delete('carrito', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> vaciar(int usuarioId) async {
    final db = await _db;
    await db.delete('carrito', where: 'usuario_id = ?', whereArgs: [usuarioId]);
  }
}
