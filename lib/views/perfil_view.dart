import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/sesion_controller.dart';
import '../models/notificacion.dart';
import '../models/usuario.dart';
import '../repository/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/politica_rol.dart';
import '../services/preferencias_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';
import 'temas_view.dart';

/// Perfil, personalización y seguridad (todos los roles).
class PerfilView extends StatefulWidget {
  const PerfilView({super.key});

  @override
  State<PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<PerfilView> {
  final _prefs = PreferenciasService.instance;
  bool _bioDisponible = false;

  @override
  void initState() {
    super.initState();
    BiometricService.instance.disponible().then((v) {
      if (mounted) setState(() => _bioDisponible = v);
    });
  }

  Future<void> _editar(Usuario u) async {
    final nombres = TextEditingController();
    final paterno = TextEditingController();
    final materno = TextEditingController();
    CamposNombre.llenar(u, nombres, paterno, materno);
    final tel = TextEditingController(text: u.telefono ?? '');
    final form = GlobalKey<FormState>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 20,
          bottom: MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            const AsaHoja(),
            const BannerDegradado(
                icono: Icons.edit_rounded, titulo: 'Editar Perfil', compacto: true),
            const SizedBox(height: 20),
            CamposNombre(
              nombres: nombres,
              apellidoPaterno: paterno,
              apellidoMaterno: materno,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (para SMS / 2FA)',
                hintText: '55 1234 5678',
                prefixIcon: Icon(Icons.phone),
                helperText: 'Se guarda cifrado con AES-256',
              ),
              validator: (v) =>
                  AuthService.esTelefonoValido(v ?? '') ? null : 'Teléfono no válido',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  if (form.currentState!.validate()) Navigator.pop(c, true);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar cambios',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            ]),
          ),
        ),
      ),
    );
    if (ok == true) {
      await UsuarioRepository.instance.actualizarDatos(u.id!,
          nombre: CamposNombre.leer(nombres, paterno, materno), telefono: tel.text);
      if (!mounted) return;
      await context.read<SesionController>().refrescar();
      if (mounted) mostrarMensaje(context, 'Perfil actualizado correctamente', exito: true);
    }
  }

  Future<void> _alternarBiometria(Usuario u, bool activar) async {
    if (activar) {
      final err = await BiometricService.instance
          .autenticar(motivo: 'Confirma para activar el acceso biométrico');
      if (!mounted) return;
      if (err != null) {
        mostrarMensaje(context, err, error: true);
        return;
      }
      await _prefs.setBiometriaUsuarioId(u.id);
      if (mounted) mostrarMensaje(context, 'Biometría habilitada', exito: true);
    } else {
      await _prefs.setBiometriaUsuarioId(null);
      if (mounted) mostrarMensaje(context, 'Biometría deshabilitada');
    }
    if (mounted) setState(() {});
  }

  void _infoCifrado() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            const AsaHoja(),
            Row(children: [
              Icon(Icons.enhanced_encryption_rounded,
                  color: Theme.of(c).colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('¿Cómo protegemos tus datos?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 14),
            const _ItemCifrado(Icons.password_rounded, 'Contraseñas',
                'Hash PBKDF2-HMAC-SHA256 con 12 000 iteraciones y sal aleatoria de 16 bytes. Nunca se guardan en texto plano.'),
            const _ItemCifrado(Icons.phone_locked_rounded, 'Teléfono',
                'Cifrado AES-256-GCM. La clave se genera en el dispositivo y vive en el almacén seguro (Keystore/Keychain).'),
            const _ItemCifrado(Icons.pin_rounded, 'Códigos 2FA',
                '6 dígitos aleatorios; solo guardamos su hash SHA-256. Vencen en minutos y permiten 3 intentos.'),
            const _ItemCifrado(Icons.lock_clock_rounded, 'Bloqueo de cuenta',
                'Tras varios intentos fallidos la cuenta se bloquea y te avisamos por correo.'),
            const _ItemCifrado(Icons.credit_card_rounded, 'Pagos',
                'Modo simulación. De la tarjeta solo se guarda la marca y los últimos 4 dígitos.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sesion = context.watch<SesionController>();
    final tema = context.watch<TemaController>();
    final u = sesion.usuario;
    if (u == null) return const SizedBox.shrink();
    final bioActiva = _prefs.biometriaUsuarioId == u.id;
    final canal = _prefs.canal2fa(u.id!);
    final colRol = AppTheme.colorRol(u.rol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        actions: accionesAppBar(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---------------------------------------------------------------- Perfil
          Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppTheme.degradado),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: colRol),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.nombre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('@${u.username}',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar perfil',
                    onPressed: () => _editar(u),
                    icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(children: [
                  _dato(Icons.email_outlined, 'Correo', u.email),
                  _dato(Icons.phone_outlined, 'Teléfono',
                      SecurityService.enmascararTelefono(u.telefono)),
                  _dato(
                      u.proveedor == 'google'
                          ? Icons.g_mobiledata_rounded
                          : Icons.verified_user_outlined,
                      'Tipo de cuenta',
                      u.tipoCuenta),
                  if (sesion.metodo != null)
                    _dato(Icons.login_rounded, 'Acceso con', sesion.metodo!),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: InsigniaRol(rol: u.rol)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ------------------------------------------------------- Apariencia
          const TituloSeccion('Apariencia y Tema', icono: Icons.palette_outlined),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Oscuro'),
                  icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {tema.modo},
            onSelectionChanged: (s) => tema.cambiarModo(s.first),
          ),
          const SizedBox(height: 12),
          // Acceso a la pantalla completa de temas
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const TemasView())),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  // Muestras de los acentos disponibles
                  SizedBox(
                    width: 64,
                    height: 40,
                    child: Stack(children: [
                      for (var k = 0; k < 4; k++)
                        Positioned(
                          left: k * 14.0,
                          top: 4,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).cardTheme.color,
                            child: CircleAvatar(
                                radius: 13,
                                backgroundColor: AppTheme.acentos[k * 2].color),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Temas, colores y fondos',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            '${AppTheme.presets.length} temas · ${AppTheme.acentos.length} colores · fondos claros y oscuros',
                            style: TextStyle(fontSize: 12, color: cs.outline)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.format_size_rounded),
            const SizedBox(width: 10),
            const Expanded(child: Text('Tamaño de texto')),
            Text('${(tema.escalaTexto * 100).round()} %',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
          ]),
          Slider(
            value: tema.escalaTexto,
            min: 0.85,
            max: 1.30,
            divisions: 9,
            label: '${(tema.escalaTexto * 100).round()} %',
            onChanged: tema.cambiarEscala,
          ),

          const SizedBox(height: 20),
          const Divider(),

          // ---------------------------------------------------- Notificaciones
          const TituloSeccion('Preferencias de Notificaciones',
              icono: Icons.notifications_active_outlined),
          _switchNotif(TipoNotificacion.seguridad, 'Alertas de Seguridad y 2FA',
              'Inicios de sesión, bloqueos y cambios de contraseña'),
          _switchNotif(TipoNotificacion.compras, 'Compras y Pedidos',
              'Confirmación de pedidos y estado de pago'),
          _switchNotif(TipoNotificacion.promociones, 'Promociones y Novedades',
              'Promoción del día y productos nuevos'),
          ListTile(
            leading: const Icon(Icons.bolt_rounded),
            title: const Text('Enviar notificación de prueba'),
            subtitle: const Text('Verifica que las alertas lleguen a tu dispositivo'),
            trailing: FilledButton.tonal(
              onPressed: () => NotificationService.instance.notificar(
                titulo: 'Alerta de prueba ⚡',
                cuerpo: '¡Funciona! Así verás los avisos de la tienda.',
                tipo: TipoNotificacion.sistema,
              ),
              child: const Text('Probar'),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),

          // --------------------------------------------------------- Seguridad
          const TituloSeccion('Seguridad y Acceso Biométrico',
              icono: Icons.security_rounded),
          SwitchListTile(
            title: const Text('Autenticación Biométrica (Huella / Facial / PIN)'),
            subtitle: Text(_bioDisponible
                ? 'Permite entrar con tu sensor biométrico en este dispositivo'
                : 'Este dispositivo no tiene biometría configurada'),
            secondary: const Icon(Icons.fingerprint_rounded),
            value: bioActiva,
            onChanged: _bioDisponible ? (v) => _alternarBiometria(u, v) : null,
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Canal preferido del código 2FA'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                ChoiceChip(
                  avatar: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('Correo'),
                  selected: !(canal == 'sms' && u.tieneTelefono),
                  onSelected: (_) async {
                    await _prefs.setCanal2fa(u.id!, 'correo');
                    setState(() {});
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.sms_outlined, size: 16),
                  label: const Text('SMS'),
                  selected: canal == 'sms' && u.tieneTelefono,
                  onSelected: u.tieneTelefono
                      ? (_) async {
                          await _prefs.setCanal2fa(u.id!, 'sms');
                          setState(() {});
                        }
                      : null,
                ),
              ]),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: const Text('Cambiar Contraseña'),
            subtitle: Text('Requisitos de tu rol: ${PoliticaRol.de(u.rol).resumenTexto}'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CambiarPasswordView(usuario: u))),
          ),
          ListTile(
            leading: const Icon(Icons.enhanced_encryption_outlined),
            title: const Text('Información de Cifrado'),
            subtitle: const Text('PBKDF2, AES-256-GCM y códigos de un solo uso'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _infoCifrado,
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => cerrarSesion(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar Sesión'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _switchNotif(String tipo, String titulo, String subtitulo) => SwitchListTile(
        secondary: Icon(NotificationService.icono(tipo), color: NotificationService.color(tipo)),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        value: _prefs.notificacionActiva(tipo),
        onChanged: (v) async {
          await _prefs.setNotificacionActiva(tipo, v);
          setState(() {});
        },
      );

  Widget _dato(IconData icono, String etiqueta, String valor) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icono, size: 20, color: cs.primary),
        const SizedBox(width: 10),
        Text('$etiqueta: ', style: TextStyle(color: cs.outline)),
        Expanded(
            child: Text(valor,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

class _ItemCifrado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _ItemCifrado(this.icono, this.titulo, this.texto);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: cs.primaryContainer,
          child: Icon(icono, size: 18, color: cs.primary),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(texto, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// Cambio de contraseña con los requisitos del rol.
class CambiarPasswordView extends StatefulWidget {
  final Usuario usuario;
  const CambiarPasswordView({super.key, required this.usuario});

  @override
  State<CambiarPasswordView> createState() => _CambiarPasswordViewState();
}

class _CambiarPasswordViewState extends State<CambiarPasswordView> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nueva.text != _confirmar.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await AuthService.instance
        .cambiarPassword(widget.usuario, _actual.text, _nueva.text);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!r.ok) {
      setState(() => _error = r.mensaje);
      return;
    }
    mostrarMensaje(context, r.mensaje, exito: true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final politica = PoliticaRol.de(widget.usuario.rol);
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar Contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BannerDegradado(
                      icono: Icons.lock_reset_rounded,
                      titulo: 'Nueva contraseña',
                      subtitulo: 'Requisitos de ${widget.usuario.rolLegible}',
                      compacto: true,
                    ),
                    const SizedBox(height: 16),
                    if (widget.usuario.proveedor == 'google')
                      const AvisoDemo(
                          mensaje:
                              'Tu cuenta entra con Google. Si nunca creaste una contraseña, usa "¿Olvidaste tu contraseña?" en el inicio de sesión.'),
                    CampoPassword(controller: _actual, etiqueta: 'Contraseña actual'),
                    const SizedBox(height: 12),
                    CampoPassword(
                        controller: _nueva,
                        etiqueta: 'Nueva contraseña',
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    RequisitosPassword(politica: politica, password: _nueva.text),
                    const SizedBox(height: 12),
                    CampoPassword(
                        controller: _confirmar, etiqueta: 'Confirmar nueva contraseña'),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed:
                          _guardando || !politica.esValida(_nueva.text) ? null : _guardar,
                      icon: _guardando ? const CargandoBoton() : const Icon(Icons.save_rounded),
                      label: const Text('Guardar contraseña',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
