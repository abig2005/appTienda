import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/carrito_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/compra.dart';
import '../repository/historial_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';

class HistorialView extends StatefulWidget {
  const HistorialView({super.key});

  @override
  State<HistorialView> createState() => _HistorialViewState();
}

class _HistorialViewState extends State<HistorialView> {
  List<Compra> _compras = [];
  bool _cargando = true;
  int _ultimoConteoCarrito = -1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final u = context.read<SesionController>().usuario;
    if (u == null) return;
    final lista = u.esAdmin
        ? await HistorialRepository.instance.todas()
        : await HistorialRepository.instance.deUsuario(u.id!);
    if (!mounted) return;
    setState(() {
      _compras = lista;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = context.watch<SesionController>().usuario?.esAdmin ?? false;
    // Recarga cuando el carrito se vacía tras una compra.
    final n = context.watch<CarritoController>().cantidadTotal;
    if (_ultimoConteoCarrito > 0 && n == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
    }
    _ultimoConteoCarrito = n;

    final totalGeneral = _compras.fold<double>(0, (s, c) => s + c.total);
    final pendientes = _compras.where((c) => c.pendiente).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(esAdmin ? 'Ventas' : 'Mis compras'),
        actions: accionesAppBar(context),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? ListView(children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppTheme.degradado,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esAdmin
                                  ? '${_compras.length} venta(s) de todos los usuarios'
                                  : '${_compras.length} compra(s) realizadas',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            Text(
                              pendientes > 0
                                  ? '$pendientes con pago pendiente'
                                  : 'Todas pagadas',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(dinero(totalGeneral),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (_compras.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: EstadoVacio(
                        icono: Icons.receipt_outlined,
                        texto:
                            'Aún no has realizado compras.\nExplora la tienda y realiza tu primera compra.',
                      ),
                    ),
                  for (final c in _compras) _TarjetaCompra(compra: c, esAdmin: esAdmin),
                ],
              ),
      ),
    );
  }
}

class _TarjetaCompra extends StatelessWidget {
  final Compra compra;
  final bool esAdmin;
  const _TarjetaCompra({required this.compra, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = compra;
    final colorEstado = c.pendiente ? Colors.orange.shade800 : Colors.green.shade700;
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(c.fecha);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: colorEstado.withValues(alpha: 0.15),
            foregroundColor: colorEstado,
            child: Icon(c.pendiente
                ? Icons.schedule_rounded
                : Icons.check_circle_outline),
          ),
          title: Text(dinero(c.total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              if (esAdmin && c.nombreUsuario != null)
                Text('${c.nombreUsuario} · ${c.emailUsuario}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${c.productos.length} producto(s) · $fecha',
                  style: TextStyle(fontSize: 11, color: cs.outline)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                Etiqueta(c.metodoPago.isEmpty ? 'Pago' : c.metodoPago,
                    color: cs.primary),
                Etiqueta(c.pendiente ? 'Pendiente' : 'Pagado', color: colorEstado),
              ]),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.6),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: cs.primary),
                    children: const [
                      _Celda('Producto', encabezado: true),
                      _Celda('Cant.', encabezado: true, centro: true),
                      _Celda('Subtotal', encabezado: true, derecha: true),
                    ],
                  ),
                  for (var i = 0; i < c.productos.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: i.isOdd
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                            : null,
                      ),
                      children: [
                        _Celda(c.productos[i].nombre),
                        _Celda('${c.productos[i].cantidad}', centro: true),
                        _Celda(dinero(c.productos[i].subtotal), derecha: true),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _dato(context, 'Folio', c.transactionId),
            if (c.detallePago.isNotEmpty) _dato(context, 'Detalle', c.detallePago),
            _dato(context, 'Estado', c.pendiente ? 'Pago pendiente' : 'Pagado',
                color: colorEstado),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir comprobante'),
                onPressed: () => SharePlus.instance.share(ShareParams(
                  subject: 'Comprobante ${c.transactionId}',
                  text: 'Comprobante de compra ${c.transactionId}\n'
                      '${c.productos.map((l) => '${l.cantidad}× ${l.nombre}').join('\n')}\n'
                      'Total: ${dinero(c.total)} · ${c.metodoPago} · $fecha',
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(BuildContext context, String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 70,
              child: Text(k,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline, fontSize: 13))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: color))),
        ]),
      );
}

class _Celda extends StatelessWidget {
  final String texto;
  final bool encabezado;
  final bool centro;
  final bool derecha;
  const _Celda(this.texto,
      {this.encabezado = false, this.centro = false, this.derecha = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          texto,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: derecha
              ? TextAlign.right
              : centro
                  ? TextAlign.center
                  : TextAlign.left,
          style: TextStyle(
            fontSize: 12,
            fontWeight: encabezado ? FontWeight.bold : FontWeight.normal,
            color: encabezado ? Colors.white : null,
          ),
        ),
      );
}
