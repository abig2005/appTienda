import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notificacion.dart';
import '../services/notification_service.dart';
import '../widgets/comunes.dart';

class NotificacionesView extends StatefulWidget {
  const NotificacionesView({super.key});

  @override
  State<NotificacionesView> createState() => _NotificacionesViewState();
}

class _NotificacionesViewState extends State<NotificacionesView> {
  final _svc = NotificationService.instance;
  List<Notificacion> _lista = [];
  bool _cargando = true;
  String _filtro = 'todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final l = await _svc.bandeja();
    if (!mounted) return;
    setState(() {
      _lista = l;
      _cargando = false;
    });
  }

  Future<void> _marcarTodas() async {
    await _svc.marcarTodasLeidas();
    _cargar();
  }

  Future<void> _borrarTodas() async {
    final si = await confirmar(context,
        titulo: 'Borrar notificaciones',
        mensaje: '¿Borrar todas las notificaciones de tu bandeja?',
        si: 'Borrar',
        icono: Icons.delete_sweep_outlined,
        peligro: true);
    if (!si) return;
    await _svc.borrarTodas();
    _cargar();
  }

  Future<void> _prueba() async {
    await _svc.notificar(
      titulo: 'Alerta de prueba ⚡',
      cuerpo: 'Así se ven las notificaciones en tiempo real de la tienda.',
      tipo: TipoNotificacion.sistema,
    );
    _cargar();
  }

  String _fecha(DateTime f) {
    final hoy = DateTime.now();
    if (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
      return 'Hoy ${DateFormat('HH:mm').format(f)}';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(f);
  }

  Widget _chipFiltro(String valor, String etiqueta) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          selected: _filtro == valor,
          label: Text(etiqueta),
          onSelected: (_) => setState(() => _filtro = valor),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noLeidas = _lista.where((n) => !n.leida).length;
    final filtradas = _lista.where((n) {
      if (_filtro == 'todas') return true;
      if (_filtro == 'no_leidas') return !n.leida;
      return n.tipo == _filtro;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            onPressed: noLeidas > 0 ? _marcarTodas : null,
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Borrar todas',
            onPressed: _lista.isEmpty ? null : _borrarTodas,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$noLeidas sin leer',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${_lista.length} notificaciones en total',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          // Filtros
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _chipFiltro('todas', 'Todas'),
                _chipFiltro('no_leidas', 'No leídas'),
                for (final t in TipoNotificacion.todos)
                  _chipFiltro(t, TipoNotificacion.nombre(t)),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : filtradas.isEmpty
                    ? EstadoVacio(
                        icono: Icons.notifications_off_outlined,
                        texto: 'No hay notificaciones en esta categoría',
                        accion: FilledButton.tonalIcon(
                          onPressed: _prueba,
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('Generar Alerta de Prueba'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtradas.length,
                          itemBuilder: (_, i) {
                            final n = filtradas[i];
                            final color = NotificationService.color(n.tipo);
                            return Dismissible(
                              key: Key('notif_${n.id}_$i'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                setState(() => _lista.removeWhere((x) => x.id == n.id));
                                if (n.id != null) await _svc.eliminar(n.id!);
                              },
                              child: Card(
                                elevation: n.leida ? 1 : 3,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: n.leida
                                        ? Colors.transparent
                                        : color.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  onTap: n.leida || n.id == null
                                      ? null
                                      : () async {
                                          await _svc.marcarLeida(n.id!);
                                          _cargar();
                                        },
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    child: Icon(NotificationService.icono(n.tipo),
                                        color: color),
                                  ),
                                  title: Row(children: [
                                    Expanded(
                                      child: Text(n.titulo,
                                          style: TextStyle(
                                              fontWeight: n.leida
                                                  ? FontWeight.w600
                                                  : FontWeight.bold,
                                              fontSize: 15)),
                                    ),
                                    if (!n.leida)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: cs.primary, shape: BoxShape.circle),
                                      ),
                                  ]),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(n.cuerpo,
                                          style: TextStyle(
                                              color: cs.onSurfaceVariant, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Etiqueta(TipoNotificacion.nombre(n.tipo),
                                              color: color),
                                          Text(_fecha(n.fecha),
                                              style: TextStyle(
                                                  fontSize: 11, color: cs.outline)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
