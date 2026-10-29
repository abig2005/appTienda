import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/carrito_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/resultado_pago.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';
import 'pago_view.dart';

class CarritoView extends StatefulWidget {
  const CarritoView({super.key});

  @override
  State<CarritoView> createState() => _CarritoViewState();
}

class _CarritoViewState extends State<CarritoView> {
  bool _procesando = false;

  Future<void> _pagar() async {
    final carrito = context.read<CarritoController>();
    final usuario = context.read<SesionController>().usuario;
    if (usuario == null || carrito.vacio) return;

    // Las formas de pago suben desde abajo, sin salir del carrito.
    final ResultadoPago? pago = await mostrarHojaPago(context, carrito.total);
    if (pago == null || !mounted) return;

    setState(() => _procesando = true);
    final r = await carrito.finalizarCompra(usuario, pago);
    if (!mounted) return;
    setState(() => _procesando = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        final color = pago.pendiente ? Colors.orange.shade800 : Colors.green;
        return AlertDialog(
          icon: Icon(
            pago.pendiente ? Icons.schedule_rounded : Icons.check_circle_rounded,
            size: 56,
            color: color,
          ),
          title: Text(pago.pendiente
              ? 'Pedido registrado (pago pendiente)'
              : '¡Compra realizada con éxito! 🛍️'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fila(c, 'Folio', r.folio),
              _fila(c, 'Total', dinero(r.total)),
              _fila(c, 'Método', pago.nombreMetodo),
              _fila(c, 'Detalle', pago.descripcion),
              const SizedBox(height: 6),
              Etiqueta(pago.pendiente ? 'Pago pendiente' : 'Aprobado', color: color),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  r.correoEnviado
                      ? Icons.mark_email_read_outlined
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: r.correoEnviado ? Colors.green : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.correoEnviado
                        ? 'Te enviamos la Nota de Remisión por correo.'
                        : 'No pudimos enviar el correo con la Nota de Remisión, pero tu compra quedó guardada en el historial.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Seguir comprando')),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                HomeView.irA.value = 'compras';
              },
              child: const Text('Ver mis compras'),
            ),
          ],
        );
      },
    );
  }

  Widget _fila(BuildContext c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 70,
              child: Text(k,
                  style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant))),
          Expanded(
              child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final carrito = context.watch<CarritoController>();
    final items = carrito.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(carrito.vacio ? 'Carrito' : 'Carrito (${carrito.cantidadTotal})'),
        actions: accionesAppBar(context),
      ),
      body: items.isEmpty
          ? EstadoVacio(
              icono: Icons.remove_shopping_cart_outlined,
              texto: 'Tu carrito está vacío',
              accion: FilledButton.tonalIcon(
                onPressed: () => HomeView.irA.value = 'inicio',
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Ir a la tienda'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return Dismissible(
                  key: ValueKey(it.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => carrito.quitar(it),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ImagenProducto(ruta: it.imagen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Precio: ${dinero(it.precio)} c/u',
                                  style: TextStyle(fontSize: 12, color: cs.outline)),
                              Text('Subtotal: ${dinero(it.subtotal)}',
                                  style: TextStyle(
                                      color: cs.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => carrito.cambiarCantidad(it, it.cantidad - 1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${it.cantidad}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => carrito.cambiarCantidad(it, it.cantidad + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Material(
                elevation: 8,
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Text('Total (${carrito.cantidadTotal} artículos)',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const Spacer(),
                      Text(dinero(carrito.total),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: cs.primary)),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _procesando ? null : _pagar,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _procesando
                            ? const CargandoBoton()
                            : const Text('Continuar al pago 💳',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}
