import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/sesion_controller.dart';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'editar_usuario_view.dart';
import 'home_view.dart';
import 'registro_view.dart';

/// Gestión de usuarios y roles (solo admin).
class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final _ctrl = UsuarioController.instance;
  final _busqueda = TextEditingController();
  List<Usuario> _usuarios = [];
  bool _cargando = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final l = await _ctrl.listar();
    if (!mounted) return;
    setState(() {
      _usuarios = l;
      _cargando = false;
    });
  }

  Usuario get _admin => context.read<SesionController>().usuario!;

  Future<void> _cambioRapidoRol(Usuario u) async {
    if (u.id == _admin.id) {
      mostrarMensaje(context, 'No puedes cambiar tu propio rol', error: true);
      return;
    }
    final rol = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const AsaHoja(),
            BannerDegradado(
              icono: Icons.manage_accounts_rounded,
              titulo: 'Cambiar rol',
              subtitulo: '${u.nombre} · @${u.username}',
              compacto: true,
            ),
            const SizedBox(height: 12),
            for (final r in const ['admin', 'editor', 'lector'])
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.colorRol(r).withValues(alpha: 0.15),
                  child: Icon(AppTheme.iconoRol(r), color: AppTheme.colorRol(r)),
                ),
                title: Text(Usuario.nombreRol(r),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: u.rol == r
                    ? Icon(Icons.check_circle_rounded, color: AppTheme.colorRol(r))
                    : null,
                onTap: () => Navigator.pop(c, r),
              ),
          ]),
        ),
      ),
    );
    if (rol == null || !mounted) return;
    final r = await _ctrl.cambiarRol(_admin, u, rol);
    if (!mounted) return;
    mostrarMensaje(context, r.mensaje, error: !r.ok, exito: r.ok);
    _cargar();
  }

  Future<void> _eliminar(Usuario u) async {
    if (u.id == _admin.id) {
      mostrarMensaje(context, 'No puedes eliminar tu propia cuenta', error: true);
      return;
    }
    final si = await confirmar(context,
        titulo: 'Eliminar usuario',
        mensaje:
            '¿Eliminar a ${u.nombre} (@${u.username})? También se borrarán su carrito, historial y notificaciones.',
        si: 'Eliminar',
        icono: Icons.person_remove_rounded,
        peligro: true);
    if (!si || !mounted) return;
    final r = await _ctrl.eliminar(_admin, u);
    if (!mounted) return;
    mostrarMensaje(context, r.mensaje, error: !r.ok);
    _cargar();
  }

  Future<void> _abrir(Usuario u) async {
    final cambio = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => EditarUsuarioView(usuario: u)));
    if (cambio == true) {
      _cargar();
      if (mounted) context.read<SesionController>().refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final yo = context.watch<SesionController>().usuario;
    final q = _query.toLowerCase();
    final filtrados = _usuarios.where((u) {
      if (q.isEmpty) return true;
      return u.nombre.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.rolLegible.toLowerCase().contains(q);
    }).toList();
    final bloqueados = _usuarios.where((u) => u.estaBloqueado).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: accionesAppBar(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const RegistroView(desdeAdmin: true)));
          if (ok == true) _cargar();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
      body: Column(
        children: [
          if (yo != null)
            EncabezadoSesion(
              usuario: yo,
              detalle:
                  '${_usuarios.length} cuentas registradas${bloqueados > 0 ? ' · $bloqueados bloqueada(s)' : ''}',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _busqueda,
              decoration: InputDecoration(
                hintText: 'Buscar usuario por nombre, correo, @usuario o rol...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busqueda.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(children: [
              Icon(Icons.touch_app_outlined, size: 14, color: cs.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Toca para editar · mantén presionado para cambiar el rol',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ),
            ]),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                    ? EstadoVacio(
                        icono: Icons.people_outline,
                        texto: _query.isEmpty
                            ? 'No hay usuarios registrados'
                            : 'No hay usuarios que coincidan con "$_query"',
                      )
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) {
                            final u = filtrados[i];
                            final col = AppTheme.colorRol(u.rol);
                            final esYo = u.id == yo?.id;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: u.estaBloqueado
                                    ? const BorderSide(color: Colors.redAccent, width: 1.5)
                                    : BorderSide.none,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                onTap: () => _abrir(u),
                                onLongPress: () => _cambioRapidoRol(u),
                                leading: CircleAvatar(
                                  backgroundColor: col.withValues(alpha: 0.15),
                                  foregroundColor: col,
                                  child: Text(
                                    u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                title: Row(children: [
                                  Flexible(
                                    child: Text(u.nombre,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                  if (esYo)
                                    Text('  (tú)',
                                        style: TextStyle(fontSize: 12, color: cs.outline)),
                                ]),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('@${u.username} · ${u.email}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13)),
                                    if (u.tieneTelefono)
                                      Text(
                                          'Tel: ${SecurityService.enmascararTelefono(u.telefono)}',
                                          style:
                                              TextStyle(fontSize: 11, color: cs.outline)),
                                    const SizedBox(height: 6),
                                    Wrap(spacing: 6, runSpacing: 4, children: [
                                      InsigniaRol(rol: u.rol),
                                      if (u.proveedor == 'google')
                                        const Etiqueta('Google', color: Color(0xFFEA4335)),
                                      if (u.estaBloqueado)
                                        const Etiqueta('🔒 Bloqueada',
                                            color: Colors.redAccent),
                                    ]),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: esYo
                                      ? 'No puedes eliminar tu cuenta'
                                      : 'Eliminar usuario',
                                  onPressed: esYo ? null : () => _eliminar(u),
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.redAccent,
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
