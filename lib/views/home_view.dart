import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/carrito_controller.dart';
import '../controllers/sesion_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'carrito_view.dart';
import 'historial_view.dart';
import 'login_view.dart';
import 'mas_view.dart';
import 'perfil_view.dart';
import 'tienda_view.dart';

class _Pestana {
  final String id;
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final Widget Function() constructor;
  const _Pestana(
      this.id, this.etiqueta, this.icono, this.iconoActivo, this.constructor);
}

/// Pestañas al estilo Amazon / Mercado Libre.
final List<_Pestana> _pestanas = [
  _Pestana('inicio', 'Inicio', Icons.home_outlined, Icons.home_rounded,
      () => const TiendaView()),
  _Pestana('compras', 'Mis compras', Icons.local_mall_outlined, Icons.local_mall,
      () => const HistorialView()),
  _Pestana('carrito', 'Carrito', Icons.shopping_cart_outlined,
      Icons.shopping_cart_rounded, () => const CarritoView()),
  _Pestana('cuenta', 'Mi cuenta', Icons.person_outline_rounded, Icons.person_rounded,
      () => const PerfilView()),
  _Pestana('mas', 'Más', Icons.menu_rounded, Icons.menu_open_rounded,
      () => const MasView()),
];

/// Cierra sesión con diálogo de confirmación (también hace signOut de Google).
Future<void> cerrarSesion(BuildContext context) async {
  final si = await confirmar(context,
      titulo: 'Cerrar sesión',
      mensaje: '¿Seguro que quieres salir de tu cuenta?',
      si: 'Salir',
      icono: Icons.logout_rounded,
      peligro: true);
  if (!si || !context.mounted) return;
  context.read<CarritoController>().limpiarSesion();
  await context.read<SesionController>().cerrar();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()), (_) => false);
}

/// Navegación principal con barra inferior: Inicio, Mis compras, Carrito,
/// Mi cuenta y Más.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  /// Cambia de pestaña desde cualquier pantalla: `HomeView.irA.value = 'carrito'`.
  static final ValueNotifier<String?> irA = ValueNotifier<String?>(null);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _indice = 0;
  final Map<int, Widget> _creadas = {}; // carga diferida

  @override
  void initState() {
    super.initState();
    HomeView.irA.addListener(_alCambiarDestino);
  }

  @override
  void dispose() {
    HomeView.irA.removeListener(_alCambiarDestino);
    super.dispose();
  }

  void _alCambiarDestino() {
    final id = HomeView.irA.value;
    if (id == null) return;
    final i = _pestanas.indexWhere((p) => p.id == id);
    if (i >= 0 && mounted) {
      // Cierra pantallas abiertas encima (p. ej. Mapa) y cambia de pestaña.
      Navigator.of(context).popUntil((r) => r.isFirst);
      setState(() => _indice = i);
    }
    HomeView.irA.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<SesionController>().usuario;
    if (usuario == null) return const Scaffold(body: SizedBox.shrink());
    _creadas.putIfAbsent(_indice, () => _pestanas[_indice].constructor());

    return PopScope(
      canPop: _indice == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _indice = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _indice,
          children: [
            for (var i = 0; i < _pestanas.length; i++)
              _creadas[i] ?? const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _BarraInferior(
          indice: _indice,
          onTap: (i) => setState(() => _indice = i),
        ),
      ),
    );
  }
}

/// Barra inferior tipo Amazon / Mercado Libre: línea superior en la pestaña
/// activa, iconos con etiqueta y contador en el carrito.
class _BarraInferior extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onTap;
  const _BarraInferior({required this.indice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enCarrito = context.watch<CarritoController>().cantidadTotal;
    return Material(
      color: Theme.of(context).cardTheme.color ?? cs.surface,
      elevation: 12,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _pestanas.length; i++)
                Expanded(
                  child: _ItemBarra(
                    pestana: _pestanas[i],
                    activa: i == indice,
                    contador: _pestanas[i].id == 'carrito' ? enCarrito : 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  final _Pestana pestana;
  final bool activa;
  final int contador;
  final VoidCallback onTap;

  const _ItemBarra({
    required this.pestana,
    required this.activa,
    required this.contador,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = activa ? cs.primary : cs.onSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      highlightShape: BoxShape.rectangle,
      containedInkWell: true,
      child: Column(
        children: [
          // Línea superior de la pestaña activa (estilo Amazon)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: activa ? 36 : 0,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: activa ? 1.12 : 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(activa ? pestana.iconoActivo : pestana.icono,
                    color: color, size: 26),
              ),
              if (contador > 0)
                Positioned(
                  right: -10,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      contador > 99 ? '99+' : '$contador',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            pestana.etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: activa ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Acciones comunes del AppBar: campana + cerrar sesión.
List<Widget> accionesAppBar(BuildContext context, {List<Widget> extra = const []}) => [
      ...extra,
      const BotonModoOscuro(),
      const CampanaNotificaciones(),
      IconButton(
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout_rounded),
        onPressed: () => cerrarSesion(context),
      ),
    ];


/// Botón sol / luna del AppBar para cambiar rápido entre claro y oscuro.
class BotonModoOscuro extends StatelessWidget {
  const BotonModoOscuro({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: oscuro ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(oscuro),
        ),
      ),
      onPressed: () =>
          context.read<TemaController>().alternarClaroOscuro(Theme.of(context).brightness),
    );
  }
}
