import 'package:flutter/foundation.dart';

import '../models/item_carrito.dart';
import '../models/notificacion.dart';
import '../models/producto.dart';
import '../models/resultado_pago.dart';
import '../models/usuario.dart';
import '../repository/carrito_repository.dart';
import '../repository/historial_repository.dart';
import '../repository/producto_repository.dart';
import '../services/mail_helper.dart';
import '../services/notification_service.dart';
import '../services/recomendacion_service.dart';

class ResultadoCompra {
  final String folio;
  final double total;
  final bool correoEnviado;
  final ResultadoPago pago;
  const ResultadoCompra(this.folio, this.total, this.correoEnviado, this.pago);
}

class CarritoController extends ChangeNotifier {
  final _repo = CarritoRepository.instance;
  int? _usuarioId;
  List<ItemCarrito> _items = [];

  List<ItemCarrito> get items => List.unmodifiable(_items);
  int get cantidadTotal => _items.fold(0, (s, i) => s + i.cantidad);
  double get total => _items.fold(0.0, (s, i) => s + i.subtotal);
  bool get vacio => _items.isEmpty;

  Future<void> cargar(int? usuarioId) async {
    _usuarioId = usuarioId;
    _items = usuarioId == null ? [] : await _repo.deUsuario(usuarioId);
    notifyListeners();
  }

  Future<void> agregar(Producto p, int cantidad) async {
    if (_usuarioId == null || p.id == null) return;
    await _repo.agregar(_usuarioId!, p, cantidad);
    await RecomendacionService.instance.registrar(_usuarioId!, p.id!, 'carrito');
    await cargar(_usuarioId);
  }

  Future<void> cambiarCantidad(ItemCarrito i, int cantidad) async {
    await _repo.cambiarCantidad(i.id!, cantidad);
    await cargar(_usuarioId);
  }

  Future<void> quitar(ItemCarrito i) async {
    await _repo.quitar(i.id!);
    await cargar(_usuarioId);
  }

  void limpiarSesion() {
    _usuarioId = null;
    _items = [];
    notifyListeners();
  }

  /// Guarda la compra, envía la nota de remisión y la notificación, y vacía el carrito.
  Future<ResultadoCompra> finalizarCompra(
      Usuario u, ResultadoPago pago) async {
    final items = List<ItemCarrito>.from(_items);
    final total = this.total;
    final folio = 'REM-${DateTime.now().millisecondsSinceEpoch}';

    await HistorialRepository.instance.registrar(
      usuarioId: u.id!,
      items: items,
      total: total,
      transactionId: folio,
      metodoPago: pago.nombreMetodo,
      detallePago: '${pago.descripcion} · Ref. ${pago.referencia}',
      estadoPago: pago.estado,
    );
    for (final i in items) {
      await RecomendacionService.instance.registrar(u.id!, i.productoId, 'compra');
      await ProductoRepository.instance.descontarStock(i.productoId, i.cantidad);
    }

    final correoOk = await MailHelper.enviarNotaRemision(
      para: u.email,
      nombre: u.nombre,
      folio: folio,
      items: items,
      total: total,
      metodoPago: '${pago.nombreMetodo} · ${pago.descripcion}',
      estadoPago: pago.estado,
      referencia: pago.referencia,
    );

    await NotificationService.instance.notificar(
      titulo: pago.pendiente
          ? 'Pedido registrado (pago pendiente)'
          : '¡Pedido confirmado!',
      cuerpo: pago.pendiente
          ? 'Folio $folio. Completa tu pago con ${pago.nombreMetodo} para enviarlo.'
          : 'Folio $folio por \$${total.toStringAsFixed(2)} pagado con ${pago.nombreMetodo}.',
      tipo: TipoNotificacion.compras,
      usuarioId: u.id,
    );

    await _repo.vaciar(u.id!);
    await cargar(u.id);
    return ResultadoCompra(folio, total, correoOk, pago);
  }
}
