import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/nombre_persona.dart';
import '../models/usuario.dart';
import '../services/notification_service.dart';
import '../services/politica_rol.dart';
import '../theme/app_theme.dart';
import '../views/notificaciones_view.dart';

final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

String dinero(num v) => formatoMoneda.format(v);

/// SnackBar flotante (rojo para errores, verde para éxito).
void mostrarMensaje(BuildContext context, String texto,
    {bool error = false,
    bool exito = false,
    String? accion,
    VoidCallback? onAccion}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      action: accion == null || onAccion == null
          ? null
          : SnackBarAction(
              label: accion, textColor: Colors.white, onPressed: onAccion),
      backgroundColor: error
          ? Colors.redAccent
          : exito
              ? Colors.green
              : null,
    ));
}

/// Banner con degradado del color de acento (estilo "Portal de Acceso Seguro").
class BannerDegradado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;

  /// true = fila compacta (icono + título), como el encabezado de los formularios.
  final bool compacto;

  const BannerDegradado({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoracion = BoxDecoration(
      gradient: AppTheme.degradado,
      borderRadius: BorderRadius.circular(compacto ? 18 : 20),
    );
    if (compacto) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: decoracion,
        child: Row(children: [
          Icon(icono, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (subtitulo != null)
                  Text(subtitulo!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: decoracion,
      child: Column(children: [
        Icon(icono, color: Colors.white, size: 40),
        const SizedBox(height: 10),
        Text(titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(subtitulo!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ]),
    );
  }
}

/// Franja "Sesión activa como: Rol" bajo el AppBar.
class EncabezadoSesion extends StatelessWidget {
  final Usuario usuario;
  final String? detalle;
  const EncabezadoSesion({super.key, required this.usuario, this.detalle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final permisos = switch (usuario.rol) {
      'admin' => 'Tienes permisos para administrar usuarios, productos y ventas',
      'editor' => 'Puedes agregar y eliminar productos del catálogo',
      _ => 'Explora el catálogo y realiza tus compras',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          child: Icon(AppTheme.iconoRol(usuario.rol), color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesión activa como: ${usuario.rolLegible}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(detalle ?? permisos,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Título de sección: icono del acento + texto en negritas.
class TituloSeccion extends StatelessWidget {
  final String texto;
  final IconData? icono;
  const TituloSeccion(this.texto, {super.key, this.icono});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(children: [
        if (icono != null) ...[
          Icon(icono, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(texto,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

/// Aviso ámbar del modo demostración, con el código y el botón [Usar].
class AvisoDemo extends StatelessWidget {
  final String mensaje;
  final String? codigo;
  final String? canal;
  final VoidCallback? onUsar;

  const AvisoDemo({
    super.key,
    required this.mensaje,
    this.codigo,
    this.canal,
    this.onUsar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                codigo == null
                    ? mensaje
                    : '$mensaje\nCódigo${canal == null ? '' : ' (${canal!.toUpperCase()})'}:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900),
              ),
              if (codigo != null)
                Text(codigo!,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Colors.amber.shade900)),
            ],
          ),
        ),
        if (codigo != null && onUsar != null)
          TextButton(onPressed: onUsar, child: const Text('Usar')),
      ]),
    );
  }
}

/// Lista de requisitos de contraseña con ✓ en vivo.
class RequisitosPassword extends StatelessWidget {
  final PoliticaRol politica;
  final String password;

  const RequisitosPassword(
      {super.key, required this.politica, required this.password});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: politica.requisitos.map((r) {
          final ok = r.cumple(password);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  key: ValueKey(ok),
                  size: 18,
                  color: ok ? Colors.green : cs.outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.descripcion,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
                        color: ok ? Colors.green : cs.onSurfaceVariant)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

/// Campo de contraseña con botón para mostrar/ocultar.
class CampoPassword extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputAction? accion;
  final VoidCallback? onSubmit;

  const CampoPassword({
    super.key,
    required this.controller,
    this.etiqueta = 'Contraseña',
    this.onChanged,
    this.validator,
    this.accion,
    this.onSubmit,
  });

  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool _mostrar = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_mostrar,
      onChanged: widget.onChanged,
      validator: widget.validator,
      textInputAction: widget.accion,
      onFieldSubmitted: (_) => widget.onSubmit?.call(),
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_mostrar ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _mostrar = !_mostrar),
        ),
      ),
    );
  }
}

/// Imagen de producto: red (con caché offline) o archivo local.
class ImagenProducto extends StatelessWidget {
  final String ruta;
  final double? alto;
  final BoxFit fit;

  const ImagenProducto(
      {super.key, required this.ruta, this.alto, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: alto,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, color: cs.onPrimaryContainer, size: 34),
    );
    if (ruta.isEmpty) return placeholder;
    if (ruta.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: ruta,
        height: alto,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) => SizedBox(
          height: alto,
          child: const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        errorWidget: (_, _, _) => placeholder,
      );
    }
    return Image.file(File(ruta),
        height: alto, fit: fit, errorBuilder: (_, _, _) => placeholder);
  }
}

/// Insignia de rol en mayúsculas con el color del rol.
class InsigniaRol extends StatelessWidget {
  final String rol;
  const InsigniaRol({super.key, required this.rol});

  @override
  Widget build(BuildContext context) {
    final col = AppTheme.colorRol(rol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Text(Usuario.nombreRol(rol).toUpperCase(),
          style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

/// Etiqueta pequeña de color (tipo de notificación, estado, etc.).
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const Etiqueta(this.texto, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

/// Campana con contador rojo de no leídas (para el AppBar).
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.noLeidas,
      builder: (context, noLeidas, _) => Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificacionesView())),
          ),
          if (noLeidas > 0)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    noLeidas > 99 ? '99+' : '$noLeidas',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Estado vacío: icono grande + mensaje + acción opcional.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;
  const EstadoVacio({super.key, required this.icono, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 14),
          Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          if (accion != null) ...[const SizedBox(height: 10), accion!],
        ]),
      ),
    );
  }
}

/// Indicador de carga dentro de botones.
class CargandoBoton extends StatelessWidget {
  const CargandoBoton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

/// Asa superior para hojas inferiores, como en la versión anterior.
class AsaHoja extends StatelessWidget {
  const AsaHoja({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 48,
          height: 5,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
}

Future<bool> confirmar(BuildContext context,
    {required String titulo,
    required String mensaje,
    String si = 'Aceptar',
    IconData icono = Icons.help_outline,
    bool peligro = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Row(children: [
        Icon(icono, color: peligro ? Colors.redAccent : Theme.of(c).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(titulo)),
      ]),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: peligro ? FilledButton.styleFrom(backgroundColor: Colors.redAccent) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(si),
        ),
      ],
    ),
  );
  return r ?? false;
}


/// Campos de nombre separados: Nombre(s), Apellido paterno y Apellido materno.
/// Se usa en el registro, en la edición del admin y en Mi cuenta.
class CamposNombre extends StatelessWidget {
  final TextEditingController nombres;
  final TextEditingController apellidoPaterno;
  final TextEditingController apellidoMaterno;
  final bool mostrarTitulo;

  const CamposNombre({
    super.key,
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    this.mostrarTitulo = true,
  });

  /// Llena los tres controladores a partir de un usuario existente.
  static void llenar(Usuario u, TextEditingController n, TextEditingController p,
      TextEditingController m) {
    final partes = u.partesNombre;
    n.text = partes.nombres;
    p.text = partes.apellidoPaterno;
    m.text = partes.apellidoMaterno;
  }

  /// Lee los tres controladores como [NombrePersona].
  static NombrePersona leer(TextEditingController n, TextEditingController p,
          TextEditingController m) =>
      NombrePersona(
        nombres: n.text.trim(),
        apellidoPaterno: p.text.trim(),
        apellidoMaterno: m.text.trim(),
      );

  static final _soloLetras =
      FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' .\-]"));

  Widget _campo(TextEditingController c, String etiqueta, String pista, IconData icono,
      String nombreCampo,
      {bool requerido = true}) {
    return TextFormField(
      controller: c,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      inputFormatters: [_soloLetras, LengthLimitingTextInputFormatter(40)],
      decoration: InputDecoration(
        labelText: requerido ? etiqueta : '$etiqueta (opcional)',
        hintText: pista,
        prefixIcon: Icon(icono),
      ),
      validator: (v) => NombrePersona.validar(v, nombreCampo, requerido: requerido),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mostrarTitulo)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Icons.badge_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              const Text('Nombre completo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        _campo(nombres, 'Nombre(s)', 'Juan Carlos', Icons.person, 'nombre'),
        const SizedBox(height: 12),
        _campo(apellidoPaterno, 'Apellido paterno', 'Pérez', Icons.person_outline,
            'apellido paterno'),
        const SizedBox(height: 12),
        _campo(apellidoMaterno, 'Apellido materno', 'Gómez', Icons.person_outline,
            'apellido materno',
            requerido: false),
      ],
    );
  }
}
