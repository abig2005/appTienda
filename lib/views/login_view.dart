import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../controllers/carrito_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/usuario.dart';
import '../repository/database_helper.dart';
import '../repository/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/google_auth_service.dart';
import '../services/preferencias_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';
import 'otp_view.dart';
import 'recuperar_password_view.dart';
import 'recuperar_usuario_view.dart';
import 'registro_view.dart';

/// Completa el acceso: guarda la sesión, ofrece biometría y abre Home.
Future<void> completarAcceso(
    BuildContext context, Usuario u, String metodo) async {
  final sesion = context.read<SesionController>();
  final carrito = context.read<CarritoController>();
  await sesion.iniciar(u, metodo);
  await carrito.cargar(u.id);
  if (!context.mounted) return;

  // Ofrecer biometría solo una vez por usuario.
  final prefs = PreferenciasService.instance;
  if (!prefs.biometriaOfrecida(u.id!) &&
      prefs.biometriaUsuarioId != u.id &&
      await BiometricService.instance.disponible()) {
    await prefs.setBiometriaOfrecida(u.id!);
    if (!context.mounted) return;
    final activar = await confirmar(
      context,
      titulo: 'Acceso Biométrico Rápido',
      mensaje:
          '¿Quieres entrar la próxima vez con tu huella, rostro o PIN del dispositivo?',
      si: 'Activar',
      icono: Icons.fingerprint_rounded,
    );
    if (activar) {
      final err = await BiometricService.instance
          .autenticar(motivo: 'Confirma para activar el acceso biométrico');
      if (err == null) {
        await prefs.setBiometriaUsuarioId(u.id);
        if (context.mounted) {
          mostrarMensaje(context, 'Acceso biométrico activado', exito: true);
        }
      } else if (context.mounted) {
        mostrarMensaje(context, err, error: true);
      }
    }
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => const HomeView(),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
    (_) => false,
  );
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _mostrarPassword = false;
  String? _demoSeleccionado;
  String? _error;

  static const _demos = [
    ('juan', 'admin'),
    ('pedro', 'editor'),
    ('ana', 'lector'),
  ];

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  void _llenarDemo(String username) {
    setState(() {
      _demoSeleccionado = username;
      _usuario.text = username;
      _password.text = DatabaseHelper.passwordDemo;
      _error = null;
    });
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await AuthService.instance.login(_usuario.text, _password.text);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (!r.ok) {
      setState(() => _error = r.mensaje);
      mostrarMensaje(context, r.mensaje, error: true);
      return;
    }
    // Verificación en dos pasos (2FA) obligatoria.
    final verificado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OtpView(usuario: r.usuario!)),
    );
    if (!mounted) return;
    if (verificado != true) {
      mostrarMensaje(context, 'Verificación en dos pasos (2FA) cancelada o fallida',
          error: true);
      return;
    }
    _password.clear();
    await completarAcceso(context, r.usuario!, 'contraseña + código 2FA');
  }

  Future<void> _accesoBiometrico() async {
    final id = PreferenciasService.instance.biometriaUsuarioId;
    if (id == null) {
      mostrarMensaje(context,
          'Primero inicia sesión con tu contraseña y activa la biometría en tu perfil.');
      return;
    }
    if (!await BiometricService.instance.disponible()) {
      if (mounted) {
        mostrarMensaje(context, 'Este dispositivo no tiene biometría configurada.',
            error: true);
      }
      return;
    }
    final err = await BiometricService.instance.autenticar();
    if (!mounted) return;
    if (err != null) {
      mostrarMensaje(context, err, error: true);
      return;
    }
    final u = await UsuarioRepository.instance.porId(id);
    if (!mounted) return;
    if (u == null) {
      await PreferenciasService.instance.setBiometriaUsuarioId(null);
      if (mounted) {
        mostrarMensaje(context, 'La cuenta vinculada ya no existe.', error: true);
      }
      return;
    }
    if (u.estaBloqueado) {
      mostrarMensaje(context, 'La cuenta está bloqueada temporalmente.', error: true);
      return;
    }
    await completarAcceso(context, u, 'biometría');
  }

  Future<void> _loginGoogle() async {
    setState(() => _cargando = true);
    final r = await GoogleAuthService.instance.iniciar();
    if (!mounted) return;
    if (r.cancelado) {
      setState(() => _cargando = false);
      return;
    }
    if (r.error != null) {
      setState(() => _cargando = false);
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 32),
            SizedBox(width: 6),
            Text('Google Sign-In'),
          ]),
          content: Text(r.error!),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }
    final u = await AuthService.instance.usuarioDesdeGoogle(r.email!, r.nombre);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (u == null) return;
    if (u.estaBloqueado) {
      mostrarMensaje(context, 'La cuenta está bloqueada temporalmente.', error: true);
      return;
    }
    await completarAcceso(context, u, 'Google');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'modo',
        tooltip: 'Modo claro / oscuro',
        backgroundColor: Theme.of(context).cardTheme.color,
        foregroundColor: cs.primary,
        onPressed: () => context
            .read<TemaController>()
            .alternarClaroOscuro(Theme.of(context).brightness),
        child: Icon(Theme.of(context).brightness == Brightness.dark
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surfaceContainerLowest, cs.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BannerDegradado(
                          icono: Icons.storefront_rounded,
                          titulo: AppConfig.appName,
                          subtitulo: 'Acceso seguro con verificación en 2 pasos',
                        ),
                        const SizedBox(height: 16),

                        // Usuarios de prueba (solo en modo debug)
                        if (kDebugMode) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Usuarios de prueba:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface)),
                              Text('Demo 1-Click',
                                  style: TextStyle(fontSize: 11, color: cs.primary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _demos.map((d) {
                              final sel = _demoSeleccionado == d.$1;
                              final color = AppTheme.colorRol(d.$2);
                              return ChoiceChip(
                                avatar: Icon(AppTheme.iconoRol(d.$2),
                                    size: 16, color: sel ? Colors.white : color),
                                label: Text('${d.$1} · ${Usuario.nombreRol(d.$2)}'),
                                selected: sel,
                                selectedColor: color,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: sel ? Colors.white : cs.onSurface,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => _llenarDemo(d.$1),
                              );
                            }).toList(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                'Contraseña: ${DatabaseHelper.passwordDemo}',
                                style: TextStyle(fontSize: 11, color: cs.outline)),
                          ),
                          const SizedBox(height: 14),
                        ],

                        TextFormField(
                          controller: _usuario,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa tu correo o nombre de usuario'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Correo o Nombre de Usuario',
                            hintText: 'nombre@dominio.com o @usuario',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: !_mostrarPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _iniciarSesion(),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Ingresa tu contraseña' : null,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_mostrarPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _mostrarPassword = !_mostrarPassword),
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(children: [
                              const Icon(Icons.error_outline,
                                  size: 18, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),

                        // Olvidé mi contraseña o usuario
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RecuperarUsuarioView())),
                              child: const Text('¿Olvidaste tu usuario?',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RecuperarPasswordView())),
                              child: const Text('¿Olvidaste tu contraseña?',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Iniciar sesión (dispara 2FA)
                        FilledButton.icon(
                          onPressed: _cargando ? null : _iniciarSesion,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.acento,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: _cargando
                              ? const CargandoBoton()
                              : const Icon(Icons.security_rounded),
                          label: Text(
                            _cargando ? 'Verificando...' : 'Iniciar Sesión con 2FA',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Acceso rápido con biometría / PIN
                        OutlinedButton.icon(
                          onPressed: _cargando ? null : _accesoBiometrico,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.fingerprint_rounded, size: 22),
                          label: const Text('Acceso Rápido con Huella / PIN'),
                        ),
                        const SizedBox(height: 18),

                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('o continúa con',
                                style: TextStyle(fontSize: 12, color: cs.outline)),
                          ),
                          const Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: 16),

                        // Inicio de sesión social
                        Center(
                          child: _BotonSocial(
                            etiqueta: 'Google',
                            icono: Icons.g_mobiledata_rounded,
                            color: const Color(0xFFEA4335),
                            onTap: _cargando ? null : _loginGoogle,
                          ),
                        ),
                        const SizedBox(height: 18),

                        TextButton.icon(
                          onPressed: _cargando
                              ? null
                              : () async {
                                  final creado = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const RegistroView()));
                                  if (creado == true && mounted) {
                                    mostrarMensaje(context,
                                        'Cuenta creada correctamente. ¡Ahora inicia sesión!',
                                        exito: true);
                                  }
                                },
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('¿No tienes cuenta? Regístrate aquí'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonSocial extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final Color color;
  final VoidCallback? onTap;

  const _BotonSocial({
    required this.etiqueta,
    required this.icono,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, color: color, size: 32),
          const SizedBox(width: 6),
          Text('Continuar con $etiqueta',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
