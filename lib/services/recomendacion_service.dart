import 'package:intl/intl.dart';

import '../models/notificacion.dart';
import '../models/producto.dart';
import '../repository/interaccion_repository.dart';
import 'notification_service.dart';
import 'preferencias_service.dart';

class Recomendaciones {
  /// true = basadas en el historial del usuario; false = populares.
  final bool personalizadas;
  final List<Producto> productos;
  const Recomendaciones(this.personalizadas, this.productos);
}

/// Recomendaciones por categoría: vista = 1, carrito = 3, compra = 5.
class RecomendacionService {
  RecomendacionService._();
  static final RecomendacionService instance = RecomendacionService._();

  final _repo = InteraccionRepository.instance;

  Future<void> registrar(int usuarioId, int productoId, String tipo) =>
      _repo.registrar(usuarioId, productoId, tipo);

  Future<Recomendaciones> obtener(int usuarioId, List<Producto> catalogo,
      {int limite = 6}) async {
    if (catalogo.isEmpty) return const Recomendaciones(false, []);
    final puntajes = await _repo.puntajePorCategoria(usuarioId);
    final comprados = await _repo.productosComprados(usuarioId);

    if (puntajes.isNotEmpty) {
      final candidatos = catalogo
          .where((p) => !comprados.contains(p.id) && puntajes.containsKey(p.categoria))
          .toList()
        ..sort((a, b) {
          final c = (puntajes[b.categoria] ?? 0).compareTo(puntajes[a.categoria] ?? 0);
          return c != 0 ? c : a.precio.compareTo(b.precio);
        });
      if (candidatos.isNotEmpty) {
        return Recomendaciones(true, candidatos.take(limite).toList());
      }
    }

    // Sin historial: populares (por interacciones globales, luego por stock).
    final pop = await _repo.popularidad();
    final lista = catalogo.where((p) => !comprados.contains(p.id)).toList()
      ..sort((a, b) {
        final c = (pop[b.id] ?? 0).compareTo(pop[a.id] ?? 0);
        return c != 0 ? c : b.stock.compareTo(a.stock);
      });
    return Recomendaciones(false, lista.take(limite).toList());
  }

  /// "Promoción del día": una vez al día, basada en las recomendaciones.
  Future<void> promocionDelDia(int usuarioId, List<Producto> catalogo) async {
    final prefs = PreferenciasService.instance;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.ultimaPromo(usuarioId) == hoy) return;
    final rec = await obtener(usuarioId, catalogo, limite: 1);
    if (rec.productos.isEmpty) return;
    final p = rec.productos.first;
    await prefs.setUltimaPromo(usuarioId, hoy);
    await NotificationService.instance.notificar(
      titulo: '🎁 Promoción del día',
      cuerpo: rec.personalizadas
          ? 'Te puede gustar "${p.nombre}" de ${p.categoria}. ¡Échale un ojo hoy!'
          : 'Lo más popular hoy: "${p.nombre}". ¡No te lo pierdas!',
      tipo: TipoNotificacion.promociones,
      usuarioId: usuarioId,
    );
  }
}
