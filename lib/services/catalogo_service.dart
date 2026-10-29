import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/producto.dart';
import '../repository/producto_repository.dart';
import 'preferencias_service.dart';

class ResultadoCatalogo {
  final List<Producto> productos;
  final bool offline;
  final DateTime? actualizado;
  const ResultadoCatalogo(this.productos, this.offline, this.actualizado);
}

/// Catálogo con copia local en SQLite (funciona sin internet).
class CatalogoService {
  CatalogoService._();
  static final CatalogoService instance = CatalogoService._();

  final _repo = ProductoRepository.instance;

  /// Se incrementa cuando se agrega o elimina un producto, para refrescar la tienda.
  final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  Future<ResultadoCatalogo>? _enCurso;

  /// Si ya hay una carga en curso, se reutiliza para no duplicar.
  Future<ResultadoCatalogo> cargar() {
    return _enCurso ??= _cargar().whenComplete(() => _enCurso = null);
  }

  Future<ResultadoCatalogo> _cargar() async {
    final prefs = PreferenciasService.instance;
    var offline = false;
    try {
      final r = await http
          .get(Uri.parse(AppConfig.productosApiUrl))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}');
      }
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! List) throw const FormatException('Respuesta inesperada');
      final productos = data
          .whereType<Map>()
          .map((e) => Producto.fromApi(Map<String, dynamic>.from(e)))
          .toList();
      await _repo.upsertDesdeApi(productos);
      await prefs.setCatalogoActualizado(DateTime.now());
    } catch (e) {
      debugPrint('[Catálogo] Sin conexión, usando copia local: $e');
      offline = true;
    }
    final locales = await _repo.todos();
    return ResultadoCatalogo(locales, offline, prefs.catalogoActualizado);
  }
}
