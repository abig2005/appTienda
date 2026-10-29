import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../controllers/sesion_controller.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';
import 'mapa_view.dart';
import 'notificaciones_view.dart';
import 'producto_form_view.dart';
import 'temas_view.dart';
import 'usuarios_view.dart';

/// Pestaña "Más": menú general al estilo Mercado Libre / Amazon.
class MasView extends StatelessWidget {
  const MasView({super.key});

  void _abrir(BuildContext context, Widget pagina) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = context.watch<SesionController>().usuario;
    if (u == null) return const SizedBox.shrink();

    final accesos = <_Acceso>[
      _Acceso('Inicio', Icons.home_rounded, () => HomeView.irA.value = 'inicio'),
      _Acceso('Mis compras', Icons.local_mall_rounded,
          () => HomeView.irA.value = 'compras'),
      _Acceso('Carrito', Icons.shopping_cart_rounded,
          () => HomeView.irA.value = 'carrito'),
      _Acceso('Sucursales', Icons.location_on_rounded,
          () => _abrir(context, const MapaView())),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Más'), actions: accionesAppBar(context)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado de cuenta
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => HomeView.irA.value = 'cuenta',
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppTheme.degradado,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.colorRol(u.rol)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola, ${u.primerNombre}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('@${u.username} · ${u.rolLegible}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text('Ver mi cuenta ›',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Accesos rápidos
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              for (final a in accesos)
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: a.onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(a.icono, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        Text(a.titulo,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          const TituloSeccion('Explorar', icono: Icons.explore_outlined),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Sucursales y mapa'),
                subtitle: const Text('Tiendas cercanas, cómo llegar y tu recorrido'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _abrir(context, const MapaView()),
              ),
              const Divider(height: 1, indent: 56),
              ValueListenableBuilder<int>(
                valueListenable: NotificationService.instance.noLeidas,
                builder: (_, n, _) => ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: Text(n > 0 ? '$n sin leer' : 'Estás al día'),
                  trailing: n > 0
                      ? Badge(label: Text('$n'))
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => _abrir(context, const NotificacionesView()),
                ),
              ),
            ]),
          ),

          if (u.puedeGestionarProductos) ...[
            const SizedBox(height: 12),
            TituloSeccion(u.esAdmin ? 'Administración' : 'Catálogo',
                icono: Icons.admin_panel_settings_outlined),
            Card(
              child: Column(children: [
                if (u.esAdmin) ...[
                  ListTile(
                    leading: Icon(Icons.people_alt_outlined,
                        color: AppTheme.colorRol('admin')),
                    title: const Text('Gestión de usuarios y roles'),
                    subtitle: const Text('Editar, bloquear, cambiar rol y eliminar'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _abrir(context, const UsuariosView()),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.bar_chart_rounded,
                        color: AppTheme.colorRol('admin')),
                    title: const Text('Ventas de todos los usuarios'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => HomeView.irA.value = 'compras',
                  ),
                  const Divider(height: 1, indent: 56),
                ],
                ListTile(
                  leading: Icon(Icons.add_business_outlined,
                      color: AppTheme.colorRol('editor')),
                  title: const Text('Agregar producto'),
                  subtitle: const Text('Foto, precio, categoría y descripción'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _abrir(context, const ProductoFormView()),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          const TituloSeccion('Cuenta', icono: Icons.manage_accounts_outlined),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Temas y apariencia'),
                subtitle: const Text('Modo claro u oscuro, colores y fondos'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _abrir(context, const TemasView()),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Mi cuenta y seguridad'),
                subtitle: const Text('Datos, apariencia, biometría y contraseña'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => HomeView.irA.value = 'cuenta',
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Cerrar sesión',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () => cerrarSesion(context),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('${AppConfig.appName} · v1.0.0',
                style: TextStyle(fontSize: 11, color: cs.outline)),
          ),
        ],
      ),
    );
  }
}

class _Acceso {
  final String titulo;
  final IconData icono;
  final VoidCallback onTap;
  const _Acceso(this.titulo, this.icono, this.onTap);
}
