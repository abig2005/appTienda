import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nombre_persona.dart';
import '../models/notificacion.dart';
import '../models/usuario.dart';
import '../repository/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/codigo_service.dart';
import '../services/notification_service.dart';
import '../services/otp_service.dart';
import '../services/politica_rol.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// Registro. Público: siempre rol lector y verificación de correo.
/// Desde admin ([desdeAdmin] = true): elige rol y no requiere verificación.
class RegistroView extends StatefulWidget {
  final bool desdeAdmin;
  const RegistroView({super.key, this.desdeAdmin = false});

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _form = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _paterno = TextEditingController();
  final _materno = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  final _codigo = TextEditingController();

  String _rol = 'lector';
  bool _usernameEditado = false;
  bool _cargando = false;
  bool _esperandoCodigo = false;
  EnvioCodigo? _envio;
  String? _error;

  PoliticaRol get _politica => PoliticaRol.de(_rol);

  @override
  void dispose() {
    for (final c in [_nombres, _paterno, _materno, _email, _username, _telefono, _password, _confirmar, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sugerirUsername() async {
    if (_usernameEditado || !AuthService.esCorreoValido(_email.text)) return;
    final s = await UsuarioRepository.instance.sugerirUsername(_email.text);
    if (mounted && !_usernameEditado) setState(() => _username.text = s);
  }

  NombrePersona get _nombre => CamposNombre.leer(_nombres, _paterno, _materno);

  Future<void> _continuar() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    final error = await AuthService.instance.validarDatosCuenta(
      nombre: _nombre,
      email: _email.text,
      username: _username.text,
      password: _password.text,
      rol: _rol,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _cargando = false;
        _error = error;
      });
      return;
    }
    if (widget.desdeAdmin) {
      await _crear();
      return;
    }
    final envio = await AuthService.instance
        .enviarCodigoRegistro(_nombre.completo, _email.text.trim());
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _envio = envio;
      _esperandoCodigo = envio.enviado || envio.esDemo;
      if (!_esperandoCodigo) _error = envio.mensaje;
    });
  }

  Future<void> _verificarYCrear() async {
    final r = AuthService.instance
        .verificarCodigoRegistro(_email.text, _codigo.text.trim());
    if (!r.ok) {
      setState(() {
        _error = r.mensaje;
        _codigo.clear();
        if (r.estado != EstadoOtp.incorrecto) _esperandoCodigo = false;
      });
      return;
    }
    setState(() => _cargando = true);
    await _crear();
  }

  Future<void> _crear() async {
    final u = await AuthService.instance.crearCuenta(
      nombre: _nombre,
      email: _email.text,
      username: _username.text,
      password: _password.text,
      rol: widget.desdeAdmin ? _rol : 'lector',
      telefono: _telefono.text,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (u == null) {
      setState(() => _error = 'No se pudo crear la cuenta.');
      return;
    }
    await NotificationService.instance.notificar(
      titulo: widget.desdeAdmin ? 'Nuevo usuario registrado 👤' : 'Nueva cuenta registrada 👤',
      cuerpo: widget.desdeAdmin
          ? '${u.nombre} fue registrado con el rol "${u.rolLegible}".'
          : 'Bienvenido ${u.primerNombre}. Tu cuenta @${u.username} está lista.',
      tipo: TipoNotificacion.sistema,
      usuarioId: u.id,
    );
    if (!mounted) return;
    if (widget.desdeAdmin) {
      mostrarMensaje(context, 'Usuario registrado correctamente', exito: true);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.desdeAdmin ? 'Registrar Usuario' : 'Crear nueva cuenta')),
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _esperandoCodigo ? _pasoCodigo() : _pasoDatos(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoDatos() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey('datos'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BannerDegradado(
            icono: Icons.person_add_alt_1,
            titulo: widget.desdeAdmin ? 'Registrar Usuario' : 'Crear nueva cuenta',
            subtitulo: widget.desdeAdmin
                ? 'El administrador elige el rol'
                : 'Las cuentas nuevas son de tipo Comprador',
            compacto: true,
          ),
          const SizedBox(height: 20),
          CamposNombre(
            nombres: _nombres,
            apellidoPaterno: _paterno,
            apellidoMaterno: _materno,
          ),
          const SizedBox(height: 12),
          Focus(
            onFocusChange: (f) {
              if (!f) _sugerirUsername();
            },
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'nombre@dominio.com',
                  prefixIcon: Icon(Icons.email)),
              validator: (v) =>
                  AuthService.esCorreoValido(v ?? '') ? null : 'Ingresa un correo válido',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _username,
            autocorrect: false,
            onChanged: (_) => _usernameEditado = true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              labelText: 'Nombre de usuario',
              prefixIcon: const Icon(Icons.alternate_email),
              helperText: 'Sugerido desde tu correo; puedes cambiarlo.',
              suffixIcon: IconButton(
                tooltip: 'Sugerir',
                icon: const Icon(Icons.auto_fix_high),
                onPressed: () {
                  _usernameEditado = false;
                  _sugerirUsername();
                },
              ),
            ),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Mínimo 3 caracteres' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional, para SMS / 2FA)',
              hintText: '55 1234 5678',
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (v) =>
                AuthService.esTelefonoValido(v ?? '') ? null : 'Teléfono no válido',
          ),
          if (widget.desdeAdmin) ...[
            const SizedBox(height: 14),
            const Text('Selecciona el Rol de usuario',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['lector', 'editor', 'admin'].map((r) {
                final sel = _rol == r;
                final color = AppTheme.colorRol(r);
                return ChoiceChip(
                  avatar: Icon(AppTheme.iconoRol(r),
                      size: 16, color: sel ? Colors.white : color),
                  label: Text(Usuario.nombreRol(r)),
                  selected: sel,
                  selectedColor: color,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : cs.onSurface,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _rol = r),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          CampoPassword(
            controller: _password,
            etiqueta: 'Contraseña segura',
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                _politica.esValida(v ?? '') ? null : 'No cumple los requisitos',
          ),
          const SizedBox(height: 8),
          RequisitosPassword(politica: _politica, password: _password.text),
          const SizedBox(height: 12),
          CampoPassword(
            controller: _confirmar,
            etiqueta: 'Confirmar contraseña',
            validator: (v) =>
                v != _password.text ? 'Las contraseñas no coinciden' : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _cargando ? null : _continuar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _cargando
                ? const CargandoBoton()
                : Icon(widget.desdeAdmin ? Icons.save_rounded : Icons.mark_email_unread_outlined),
            label: Text(
              widget.desdeAdmin ? 'Registrar' : 'Verificar correo y continuar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (!widget.desdeAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Te enviaremos un código de 6 dígitos para confirmar tu correo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pasoCodigo() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('codigo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BannerDegradado(
          icono: Icons.mark_email_read_rounded,
          titulo: 'Verifica tu correo',
          subtitulo: 'Último paso para crear tu cuenta',
        ),
        const SizedBox(height: 16),
        Text(_envio?.mensaje ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        if (_envio?.esDemo ?? false)
          AvisoDemo(
            mensaje: 'Modo demostración: el correo no está configurado.',
            codigo: _envio!.codigoDemo,
            canal: 'correo',
            onUsar: () => setState(() => _codigo.text = _envio!.codigoDemo!),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            labelText: 'Código de 6 dígitos',
            prefixIcon: const Icon(Icons.key_rounded),
            errorText: _error,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _cargando ? null : _verificarYCrear,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: _cargando ? const CargandoBoton() : const Icon(Icons.how_to_reg_rounded),
          label: const Text('Verificar y crear cuenta',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: _cargando
              ? null
              : () => setState(() {
                    _esperandoCodigo = false;
                    _error = null;
                  }),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Corregir mis datos'),
        ),
      ],
    );
  }
}
