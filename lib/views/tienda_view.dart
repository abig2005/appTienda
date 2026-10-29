import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../controllers/carrito_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/producto.dart';
import '../repository/producto_repository.dart';
import '../services/catalogo_service.dart';
import '../services/recomendacion_service.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';
import 'producto_form_view.dart';

class TiendaView extends StatefulWidget {
  const TiendaView({super.key});

  @override
  State<TiendaView> createState() => _TiendaViewState();
}

class _TiendaViewState extends State<TiendaView> {
  final _buscar = TextEditingController();
  List<Producto> _productos = [];
  Recomendaciones _rec = const Recomendaciones(false, []);
  bool _cargando = true;
  bool _offline = false;
  DateTime? _actualizado;
  String _categoria = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargar();
    CatalogoService.instance.cambios.addListener(_cargar);
  }

  @override
  void dispose() {
    CatalogoService.instance.cambios.removeListener(_cargar);
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!_cargando) setState(() => _cargando = true);
    final r = await CatalogoService.instance.cargar();
    if (!mounted) return;
    final u = context.read<SesionController>().usuario;
    Recomendaciones rec = const Recomendaciones(false, []);
    if (u != null) {
      rec = await RecomendacionService.instance.obtener(u.id!, r.productos);
      RecomendacionService.instance.promocionDelDia(u.id!, r.productos);
    }
    if (!mounted) return;
    setState(() {
      _productos = r.productos;
      _offline = r.offline;
      _actualizado = r.actualizado;
      _rec = rec;
      _cargando = false;
      if (!_categorias.contains(_categoria)) _categoria = 'Todas';
    });
  }

  List<String> get _categorias {
    final s = _productos.map((p) => p.categoria).toSet().toList()..sort();
    return ['Todas', ...s];
  }

  List<Producto> get _filtrados {
    final q = _buscar.text.trim().toLowerCase();
    return _productos.where((p) {
      final cat = _categoria == 'Todas' || p.categoria == _categoria;
      final txt = q.isEmpty ||
          p.nombre.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q) ||
          p.categoria.toLowerCase().contains(q);
      return cat && txt;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _abrirDetalle(Producto p) async {
    final u = context.read<SesionController>().usuario;
    if (u != null && p.id != null) {
      RecomendacionService.instance.registrar(u.id!, p.id!, 'vista');
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final cs = Theme.of(c).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (c, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
            children: [
              const AsaHoja(),
              Container(
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Hero(tag: 'img-${p.id}', child: ImagenProducto(ruta: p.imagen)),
              ),
              const SizedBox(height: 16),
              Text(p.nombre,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Text(dinero(p.precio),
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: cs.primary)),
                const Spacer(),
                Etiqueta(p.categoria, color: cs.primary),
              ]),
              const SizedBox(height: 6),
              Text(
                p.stock > 0 ? 'Disponibles: ${p.stock}' : 'Agotado',
                style: TextStyle(
                    color: p.stock > 0 ? cs.onSurfaceVariant : Colors.redAccent,
                    fontWeight: FontWeight.w600),
              ),
              const Divider(height: 28),
              Text(p.descripcion.isEmpty ? 'Sin descripción.' : p.descripcion,
                  style: TextStyle(height: 1.45, color: cs.onSurfaceVariant)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _compartir(p),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: p.stock <= 0
                        ? null
                        : () {
                            Navigator.pop(c);
                            _agregar(p);
                          },
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Agregar'),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Future<void> _compartir(Producto p) async {
    await SharePlus.instance.share(ShareParams(
      subject: p.nombre,
      text: '¡Mira esto en ${AppConfig.appName}! 🛍️\n'
          '${p.nombre} — disponible por solo ${dinero(p.precio)}.\n'
          '${p.imagen.startsWith('http') ? p.imagen : ''}',
    ));
  }

  Future<void> _agregar(Producto p) async {
    final formKey = GlobalKey<FormState>();
    final cantidadCtrl = TextEditingController(text: '1');
    final cantidad = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(children: [
          Icon(Icons.add_shopping_cart, color: Theme.of(c).colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('Agregar al carrito')),
        ]),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Precio unitario: ${dinero(p.precio)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: cantidadCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  helperText: 'Disponibles: ${p.stock}',
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Ingresa una cantidad mayor que cero';
                  if (n > p.stock) return 'No hay suficientes unidades disponibles';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(c, int.parse(cantidadCtrl.text.trim()));
              }
            },
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (cantidad == null || !mounted) return;
    await context.read<CarritoController>().agregar(p, cantidad);
    if (mounted) {
      mostrarMensaje(context, 'Agregaste $cantidad × ${p.nombre} al carrito 🛒',
          exito: true,
          accion: 'Ver carrito',
          onAccion: () => HomeView.irA.value = 'carrito');
    }
  }

  Future<void> _eliminar(Producto p) async {
    final si = await confirmar(context,
        titulo: 'Eliminar producto',
        mensaje: '¿Eliminar "${p.nombre}"? No volverá a aparecer en el catálogo.',
        si: 'Eliminar',
        icono: Icons.delete_outline,
        peligro: true);
    if (!si) return;
    await ProductoRepository.instance.eliminar(p);
    if (!mounted) return;
    await context
        .read<CarritoController>()
        .cargar(context.read<SesionController>().usuario?.id);
    if (!mounted) return;
    mostrarMensaje(context, 'Producto eliminado');
    _cargar();
  }

  Future<void> _nuevo() async {
    final creado = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const ProductoFormView()));
    if (creado == true) _cargar();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = context.watch<SesionController>().usuario;
    final puedeGestionar = u?.puedeGestionarProductos ?? false;
    final lista = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: accionesAppBar(context),
      ),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: _nuevo,
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (u != null) SliverToBoxAdapter(child: EncabezadoSesion(usuario: u)),
            if (_offline)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade700),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wifi_off, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión, catálogo guardado'
                        '${_actualizado == null ? '' : ' (actualizado ${DateFormat('dd/MM HH:mm').format(_actualizado!)})'}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _buscar,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto por nombre o categoría...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    suffixIcon: _buscar.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_buscar.clear),
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    for (final c in _categorias)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(c),
                          selected: _categoria == c,
                          onSelected: (_) => setState(() => _categoria = c),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_cargando && _productos.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_productos.isEmpty)
              const SliverFillRemaining(
                child: EstadoVacio(
                  icono: Icons.inventory_2_outlined,
                  texto:
                      'No hay productos guardados.\nConéctate a internet y desliza hacia abajo para cargar el catálogo.',
                ),
              )
            else ...[
              if (_rec.productos.isNotEmpty &&
                  _buscar.text.isEmpty &&
                  _categoria == 'Todas') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TituloSeccion(
                      _rec.personalizadas ? 'Recomendado para ti' : 'Populares',
                      icono: _rec.personalizadas
                          ? Icons.auto_awesome_outlined
                          : Icons.local_fire_department_outlined,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      itemCount: _rec.productos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = _rec.productos[i];
                        return SizedBox(
                          width: 150,
                          child: _TarjetaProducto(
                            producto: p,
                            compacta: true,
                            onTap: () => _abrirDetalle(p),
                            onAgregar: () => _agregar(p),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TituloSeccion('Todos los productos (${lista.length})',
                        icono: Icons.inventory_2_outlined),
                  ),
                ),
              ],
              if (lista.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No hay productos que coincidan con "${_buscar.text}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.64,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final p = lista[i];
                      return _TarjetaProducto(
                        producto: p,
                        onTap: () => _abrirDetalle(p),
                        onAgregar: () => _agregar(p),
                        onCompartir: () => _compartir(p),
                        onEliminar: puedeGestionar ? () => _eliminar(p) : null,
                      );
                    },
                    childCount: lista.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  final VoidCallback onAgregar;
  final VoidCallback? onCompartir;
  final VoidCallback? onEliminar;
  final bool compacta;

  const _TarjetaProducto({
    required this.producto,
    required this.onTap,
    required this.onAgregar,
    this.onCompartir,
    this.onEliminar,
    this.compacta = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = producto;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: compacta
                        ? ImagenProducto(ruta: p.imagen)
                        : Hero(
                            tag: 'img-${p.id}', child: ImagenProducto(ruta: p.imagen)),
                  ),
                ),
                if (p.esLocal)
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: Etiqueta('Nuevo', color: Colors.green),
                  ),
                if (p.stock <= 0)
                  const Positioned(
                    left: 8,
                    bottom: 8,
                    child: Etiqueta('Agotado', color: Colors.redAccent),
                  ),
                if (!compacta)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
                      onSelected: (v) {
                        if (v == 'compartir') onCompartir?.call();
                        if (v == 'eliminar') onEliminar?.call();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'compartir',
                            child: ListTile(
                                leading: Icon(Icons.share_outlined),
                                title: Text('Compartir en redes'))),
                        if (onEliminar != null)
                          const PopupMenuItem(
                              value: 'eliminar',
                              child: ListTile(
                                  leading: Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  title: Text('Eliminar producto'))),
                      ],
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compacta ? 12 : 13, fontWeight: FontWeight.bold)),
                  if (!compacta)
                    Text(p.categoria,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                  Row(children: [
                    Expanded(
                      child: Text(dinero(p.precio),
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: cs.primary)),
                    ),
                    if (!compacta)
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Agregar al carrito',
                        onPressed: p.stock > 0 ? onAgregar : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
