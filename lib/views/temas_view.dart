import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// Temas y apariencia: modo claro/oscuro, temas prediseñados, color de
/// acento, fondos de cada modo y tamaño de texto, con vista previa en vivo.
class TemasView extends StatelessWidget {
  const TemasView({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<TemaController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Temas y apariencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _VistaPrevia(),
          const SizedBox(height: 22),

          // ----------------------------------------------------------- Modo
          const TituloSeccion('Modo', icono: Icons.contrast_rounded),
          Row(children: [
            for (final m in const [
              (ThemeMode.light, 'Claro', Icons.light_mode_rounded),
              (ThemeMode.dark, 'Oscuro', Icons.dark_mode_rounded),
              (ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _OpcionModo(
                    icono: m.$3,
                    texto: m.$2,
                    seleccionado: tema.modo == m.$1,
                    onTap: () => tema.cambiarModo(m.$1),
                  ),
                ),
              ),
          ]),
          if (tema.modo == ThemeMode.system)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La app cambiará sola según el modo de tu teléfono.',
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
            ),
          const SizedBox(height: 24),

          // ------------------------------------------------ Temas prediseñados
          const TituloSeccion('Temas prediseñados', icono: Icons.auto_awesome_rounded),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppTheme.presets.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (_, i) {
              final p = AppTheme.presets[i];
              return _TarjetaPreset(
                preset: p,
                seleccionado: tema.esPreset(p),
                onTap: () {
                  tema.aplicarPreset(p);
                  mostrarMensaje(context, 'Tema "${p.nombre}" aplicado', exito: true);
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // --------------------------------------------------- Color de acento
          const TituloSeccion('Color de acento', icono: Icons.palette_rounded),
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              for (final a in AppTheme.acentos)
                _CirculoAcento(
                  acento: a,
                  seleccionado: tema.acentoId == a.id,
                  onTap: () => tema.cambiarAcento(a.id),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------------- Fondos
          const TituloSeccion('Fondo en modo claro', icono: Icons.wb_sunny_outlined),
          _FilaFondos(
            fondos: AppTheme.fondosClaros,
            seleccionado: tema.fondoClaroId,
            onTap: (f) {
              tema.cambiarFondoClaro(f.id);
              if (tema.modo == ThemeMode.dark) tema.cambiarModo(ThemeMode.light);
            },
          ),
          const SizedBox(height: 20),
          const TituloSeccion('Fondo en modo oscuro', icono: Icons.nightlight_outlined),
          _FilaFondos(
            fondos: AppTheme.fondosOscuros,
            seleccionado: tema.fondoOscuroId,
            onTap: (f) {
              tema.cambiarFondoOscuro(f.id);
              if (tema.modo == ThemeMode.light) tema.cambiarModo(ThemeMode.dark);
            },
          ),
          const SizedBox(height: 24),

          // --------------------------------------------------- Tamaño de texto
          const TituloSeccion('Tamaño de texto', icono: Icons.format_size_rounded),
          Row(children: [
            const Text('A', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Slider(
                value: tema.escalaTexto,
                min: 0.85,
                max: 1.30,
                divisions: 9,
                label: '${(tema.escalaTexto * 100).round()} %',
                onChanged: tema.cambiarEscala,
              ),
            ),
            const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          Center(
            child: Text('${(tema.escalaTexto * 100).round()} %',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              tema.aplicarPreset(AppTheme.presets.first);
              tema.cambiarEscala(1.0);
              mostrarMensaje(context, 'Apariencia restablecida');
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Restablecer apariencia original'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Mini maqueta de la app con el tema actual.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Container(
        color: t.scaffoldBackgroundColor,
        child: Column(children: [
          Container(
            height: 46,
            color: t.appBarTheme.backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Row(children: [
              Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Vista previa',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Spacer(),
              Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.headphones_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Audífonos inalámbricos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: cs.onSurface)),
                          Text(dinero(899),
                              style: TextStyle(
                                  color: cs.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: () {}, child: const Text('Comprar')),
            ]),
          ),
          Container(
            height: 44,
            color: t.cardTheme.color,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(Icons.home_rounded, color: cs.primary),
                Icon(Icons.local_mall_outlined, color: cs.onSurfaceVariant),
                Icon(Icons.shopping_cart_outlined, color: cs.onSurfaceVariant),
                Icon(Icons.person_outline_rounded, color: cs.onSurfaceVariant),
                Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _OpcionModo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
  const _OpcionModo(
      {required this.icono,
      required this.texto,
      required this.seleccionado,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: seleccionado ? cs.primaryContainer : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: seleccionado ? cs.primary : cs.outlineVariant,
              width: seleccionado ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icono, color: seleccionado ? cs.primary : cs.onSurfaceVariant, size: 28),
          const SizedBox(height: 6),
          Text(texto,
              style: TextStyle(
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                  color: seleccionado ? cs.primary : cs.onSurface)),
        ]),
      ),
    );
  }
}

class _TarjetaPreset extends StatelessWidget {
  final TemaPreset preset;
  final bool seleccionado;
  final VoidCallback onTap;
  const _TarjetaPreset(
      {required this.preset, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final acento = AppTheme.buscarAcento(preset.acentoId).color;
    final fondo = preset.modo == ThemeMode.dark
        ? AppTheme.buscarOscuro(preset.oscuroId)
        : AppTheme.buscarClaro(preset.claroId);
    final textoPrincipal = fondo.oscuro ? Colors.white : const Color(0xFF1E293B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: fondo.fondo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: seleccionado ? cs.primary : cs.outlineVariant,
              width: seleccionado ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Barra superior del mini tema
          Container(
            height: 30,
            color: fondo.oscuro ? fondo.superficie : acento,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.white70, borderRadius: BorderRadius.circular(3))),
              const Spacer(),
              if (seleccionado)
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: fondo.superficie,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fondo.borde),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    CircleAvatar(radius: 6, backgroundColor: acento),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                              color: fondo.borde,
                              borderRadius: BorderRadius.circular(3))),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 18,
                  width: 60,
                  decoration: BoxDecoration(
                    gradient: AppTheme.degradadoDe(acento),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const Spacer(),
                Row(children: [
                  Icon(
                    switch (preset.modo) {
                      ThemeMode.dark => Icons.dark_mode_rounded,
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.system => Icons.brightness_auto_rounded,
                    },
                    size: 14,
                    color: textoPrincipal.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(preset.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textoPrincipal)),
                  ),
                ]),
                Text(preset.descripcion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, color: textoPrincipal.withValues(alpha: 0.65))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CirculoAcento extends StatelessWidget {
  final ColorAcento acento;
  final bool seleccionado;
  final VoidCallback onTap;
  const _CirculoAcento(
      {required this.acento, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.degradadoDe(acento.color),
              shape: BoxShape.circle,
              border: Border.all(
                  color: seleccionado ? cs.onSurface : Colors.transparent, width: 3),
              boxShadow: [
                if (seleccionado)
                  BoxShadow(
                      color: acento.color.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1),
              ],
            ),
            child: seleccionado
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(acento.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _FilaFondos extends StatelessWidget {
  final List<FondoTema> fondos;
  final String seleccionado;
  final ValueChanged<FondoTema> onTap;
  const _FilaFondos(
      {required this.fondos, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      for (final f in fondos)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onTap(f),
              borderRadius: BorderRadius.circular(14),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 64,
                  decoration: BoxDecoration(
                    color: f.fondo,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: f.id == seleccionado ? cs.primary : cs.outlineVariant,
                        width: f.id == seleccionado ? 3 : 1),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Stack(children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: f.superficie,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: f.borde),
                        ),
                      ),
                    ),
                    if (f.id == seleccionado)
                      Align(
                        alignment: Alignment.topRight,
                        child: Icon(Icons.check_circle_rounded,
                            size: 18, color: cs.primary),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(f.nombre,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            f.id == seleccionado ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          ),
        ),
    ]);
  }
}
