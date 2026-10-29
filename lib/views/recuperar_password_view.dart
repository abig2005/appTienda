import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario.dart';
import '../repository/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/codigo_service.dart';
import '../services/otp_service.dart';
import '../services/politica_rol.dart';
import '../widgets/comunes.dart';

/// Recuperar contraseña en 3 pasos: identificar → código → nueva contraseña.
class RecuperarPasswordView extends StatefulWidget {
  const RecuperarPasswordView({super.key});

  @override
  State<RecuperarPasswordView> createState() => _RecuperarPasswordViewState();
}

class _RecuperarPasswordViewState extends State<RecuperarPasswordView> {
  final _identificador = TextEditingController();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  final _auth = AuthService.instance;

  int _paso = 0;
  String _canal = 'correo';
  Usuario? _usuario;
  EnvioCodigo? _envio;
  String? _error;
  bool _cargando = false;
  Timer? _timer;

  static const _titulos = ['Identifícate', 'Código de verificación', 'Nueva contraseña'];
  static const _iconos = [
    Icons.manage_search_rounded,
    Icons.pin_rounded,
    Icons.lock_reset_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _paso > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_identificador, _codigo, _nueva, _confirmar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _paso1({bool yaTengoCodigo = false}) async {
    if (_identificador.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu correo o nombre de usuario');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
      _envio = null;
    });
    final u = await UsuarioRepository.instance.porIdentificador(_identificador.text);
    EnvioCodigo? envio;
    if (u != null && !yaTengoCodigo) {
      final canal = (_canal == 'sms' && u.tieneTelefono) ? 'sms' : 'correo';
      envio = await _auth.enviarCodigoRecuperacion(u, canal);
    }
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _usuario = u;
      _envio = envio;
      _codigo.clear();
      if (envio != null && !envio.enviado && !envio.esDemo) {
        _error = envio.mensaje;
      } else {
        _paso = 1;
      }
    });
  }

  void _paso2() {
    final c = _codigo.text.trim();
    if (c.length != 6) {
      setState(() => _error = 'Ingresa los 6 dígitos del código');
      return;
    }
    // Si la cuenta no existe, respondemos igual que con un código inválido.
    final ResultadoOtp r = _usuario == null
        ? const ResultadoOtp(EstadoOtp.inexistente, 0)
        : _auth.verificarCodigoRecuperacion(_usuario!, c);
    setState(() {
      if (r.ok) {
        _paso = 2;
        _error = null;
      } else {
        _error = r.mensaje;
        _codigo.clear();
      }
    });
  }

  Future<void> _paso3() async {
    final politica = PoliticaRol.de(_usuario!.rol);
    if (!politica.esValida(_nueva.text)) {
      setState(() => _error = 'La contraseña no cumple los requisitos');
      return;
    }
    if (_nueva.text != _confirmar.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await _auth.restablecerPassword(_usuario!, _nueva.text);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (!r.ok) {
      setState(() => _error = r.mensaje);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 52),
        title: const Text('¡Contraseña actualizada!'),
        content: const Text(
            'Ya puedes iniciar sesión con tu nueva contraseña. Te enviamos una alerta de seguridad a tu correo.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c), child: const Text('Iniciar sesión')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperación de Acceso')),
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
                      icono: _iconos[_paso],
                      titulo: 'Restablecer contraseña',
                      subtitulo: 'Paso ${_paso + 1} de 3 · ${_titulos[_paso]}',
                    ),
                    const SizedBox(height: 14),
                    // Barra de progreso
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: (_paso + 1) / 3),
                      duration: const Duration(milliseconds: 350),
                      builder: (_, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          color: cs.primary,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Text(
                            _titulos[i],
                            textAlign: i == 0
                                ? TextAlign.start
                                : i == 1
                                    ? TextAlign.center
                                    : TextAlign.end,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: i == _paso ? FontWeight.bold : FontWeight.normal,
                              color: i <= _paso ? cs.primary : cs.outline,
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: switch (_paso) {
                        0 => _vistaPaso1(),
                        1 => _vistaPaso2(),
                        _ => _vistaPaso3(),
                      },
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

  Widget _errorWidget() => _error == null
      ? const SizedBox(height: 4)
      : Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        );

  Widget _boton(String texto, IconData icono, VoidCallback onPressed) => FilledButton.icon(
        onPressed: _cargando ? null : onPressed,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        icon: _cargando ? const CargandoBoton() : Icon(icono),
        label: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _chip(String valor, String etiqueta, IconData icono) => Expanded(
        child: ChoiceChip(
          label: Text(etiqueta, style: const TextStyle(fontSize: 12)),
          avatar: Icon(icono, size: 16),
          selected: _canal == valor,
          onSelected: (_) => setState(() => _canal = valor),
        ),
      );

  Widget _vistaPaso1() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _identificador,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'Correo o nombre de usuario',
              hintText: 'nombre@dominio.com o @usuario',
              prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 16),
        const Text('¿Dónde quieres recibir el código?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          _chip('correo', 'Correo', Icons.email_outlined),
          const SizedBox(width: 8),
          _chip('sms', 'SMS', Icons.sms_outlined),
        ]),
        if (_canal == 'sms')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Si tu cuenta no tiene teléfono, lo enviaremos a tu correo.',
                style: TextStyle(fontSize: 11, color: cs.outline)),
          ),
        _errorWidget(),
        const SizedBox(height: 18),
        _boton('Enviar código', Icons.send_rounded, _paso1),
        TextButton(
          onPressed: _cargando ? null : () => _paso1(yaTengoCodigo: true),
          child: const Text('Ya tengo un código (enviado por el administrador)',
              style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _vistaPaso2() {
    final cs = Theme.of(context).colorScheme;
    final u = _usuario;
    final clave = u == null ? '' : AuthService.claveRecuperacion(u.id!);
    final restante = u == null ? Duration.zero : OtpService.instance.restante(clave);
    final segReenvio = u == null ? 0 : OtpService.instance.segundosParaReenvio(clave);
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Si los datos corresponden a una cuenta, enviamos un código de 6 dígitos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        if (_envio?.esDemo ?? false)
          AvisoDemo(
            mensaje: _envio!.mensaje,
            codigo: _envio!.codigoDemo,
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
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
            labelText: 'Código de 6 dígitos',
            prefixIcon: Icon(Icons.key_rounded),
          ),
          onSubmitted: (_) => _paso2(),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.timer_outlined,
              size: 16, color: restante > Duration.zero ? Colors.grey : Colors.red),
          const SizedBox(width: 6),
          Text(
            restante > Duration.zero
                ? 'Expira en: ${_mmss(restante)}'
                : 'Sin código activo o ya expiró',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: restante > Duration.zero ? Colors.grey : Colors.red),
          ),
        ]),
        _errorWidget(),
        const SizedBox(height: 16),
        _boton('Verificar código', Icons.verified_rounded, _paso2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                _paso = 0;
                _error = null;
              }),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Cambiar datos'),
            ),
            TextButton.icon(
              onPressed: (_cargando || segReenvio > 0) ? null : () => _paso1(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(segReenvio > 0 ? 'Reenviar en $segReenvio s' : 'Reenviar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vistaPaso3() {
    final cs = Theme.of(context).colorScheme;
    final u = _usuario!;
    final politica = PoliticaRol.de(u.rol);
    final tiempo = _auth.tiempoParaGuardar(u);
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: cs.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tienes ${_mmss(tiempo)} para guardar',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                Text('Cuenta @${u.username}',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
              ]),
            ),
            InsigniaRol(rol: u.rol),
          ]),
        ),
        const SizedBox(height: 14),
        CampoPassword(
          controller: _nueva,
          etiqueta: 'Nueva contraseña',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        RequisitosPassword(politica: politica, password: _nueva.text),
        const SizedBox(height: 12),
        CampoPassword(
          controller: _confirmar,
          etiqueta: 'Confirmar contraseña',
          onChanged: (_) => setState(() {}),
        ),
        if (_confirmar.text.isNotEmpty && _confirmar.text != _nueva.text)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Las contraseñas no coinciden',
                style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('No puede ser igual a tu contraseña anterior.',
              style: TextStyle(fontSize: 11, color: cs.outline)),
        ),
        _errorWidget(),
        const SizedBox(height: 16),
        _boton('Guardar contraseña', Icons.save_rounded, _paso3),
      ],
    );
  }
}
