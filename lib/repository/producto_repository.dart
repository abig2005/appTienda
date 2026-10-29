import 'package:sqflite/sqflite.dart';

import '../models/producto.dart';
import 'database_helper.dart';

class ProductoRepository {
  ProductoRepository._();
  static final ProductoRepository instance = ProductoRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Producto>> todos() async {
    final db = await _db;
    final filas = await db.query('productos', orderBy: 'id DESC');
    return filas.map(Producto.fromMap).toList();
  }

  Future<Producto?> porId(int id) async {
    final db = await _db;
    final f = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    return f.isEmpty ? null : Producto.fromMap(f.first);
  }

  Future<int> contar() async {
    final db = await _db;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM productos')) ??
        0;
  }

  /// Inserta o actualiza los productos que vienen de la API (por api_id),
  /// saltando los que el admin/editor eliminó.
  Future<void> upsertDesdeApi(List<Producto> productos) async {
    final db = await _db;
    final eliminados = (await db.query('productos_eliminados'))
        .map((e) => e['api_id'] as int)
        .toSet();
    await db.transaction((txn) async {
      for (final p in productos) {
        if (p.apiId == null || eliminados.contains(p.apiId)) continue;
        final existe = await txn.query('productos',
            columns: ['id', 'stock'],
            where: 'api_id = ?',
            whereArgs: [p.apiId]);
        if (existe.isEmpty) {
          await txn.insert('productos', p.toMap());
        } else {
          // Conservamos el stock local; actualizamos el resto.
          await txn.update(
            'productos',
            {
              'nombre': p.nombre,
              'precio': p.precio,
              'imagen': p.imagen,
              'categoria': p.categoria,
              'descripcion': p.descripcion,
            },
            where: 'api_id = ?',
            whereArgs: [p.apiId],
          );
        }
      }
    });
  }

  Future<int> insertar(Producto p) async {
    final db = await _db;
    return db.insert('productos', p.toMap());
  }

  Future<void> eliminar(Producto p) async {
    final db = await _db;
    await db.transaction((txn) async {
      if (p.apiId != null) {
        await txn.insert('productos_eliminados', {'api_id': p.apiId},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.delete('productos', where: 'id = ?', whereArgs: [p.id]);
      await txn.delete('carrito', where: 'producto_id = ?', whereArgs: [p.id]);
    });
  }

  Future<void> descontarStock(int productoId, int cantidad) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE productos SET stock = MAX(stock - ?, 0) WHERE id = ?',
      [cantidad, productoId],
    );
  }
}
