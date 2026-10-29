import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/codigo_service.dart';
import '../services/otp_service.dart';
import '../services/preferencias_service.dart';
import '../services/security_service.dart';
import '../widgets/comunes.dart';

/// Segundo paso obligatorio del login (2FA). Devuelve `true` al verificar.
class OtpView extends StatefulWidget {
  final Usuario usuario;
  const OtpView({super.key, required this.usuario});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final _codigo = TextEditingController();
  final _auth = AuthService.instance;
  final _otp = OtpService.instance;

  late String _canal;
  bool _enviando = false;
  bool _verificando = false;
  EnvioCodigo? _envio;
  String? _error;
  Timer? _timer;
  Duration _restante = Duration.zero;
  int _reenvio = 0;

  String get _clave => AuthService.claveLogin(widget.usuario.id!);

  @override
  void initState() {
    super.initState();
    final pref = PreferenciasService.instance.canal2fa(widget.usuario.id!);
    _canal = (pref == 'sms' && widget.usuario.tieneTelefono) ? 'sms' : 'correo';
    // Enviamos tras el primer cuadro (no se puede llamar setState en initState).
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviar());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _restante = _otp.restante(_clave);
      _reenvio = _otp.segundosParaReenvio(_clave);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
      _codigo.clear();
    });
    final r = await _auth.enviarOtpLogin(widget.usuario, _canal);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _envio = r;
      if (!r.enviado && !r.esDemo) _error = r.mensaje;
    });
    _tick();
  }

  Future<void> _verificar() async {
    final c = _codigo.text.trim();
    if (c.length != 6) {
      setState(() => _error = 'Ingresa los 6 dígitos del código');
      return;
    }
    setState(() => _verificando = true);
    final r = _auth.verificarOtpLogin(widget.usuario, c);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _verificando = false);
    if (r.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = r.mensaje;
        _codigo.clear();
      });
    }
  }

  String _formato(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _chipCanal(String valor, String etiqueta, IconData icono, bool habilitado) {
    return Expanded(
      child: ChoiceChip(
        label: Text(etiqueta, style: const TextStyle(fontSize: 12)),
        avatar: Icon(icono, size: 16),
        selected: _canal == valor,
        onSelected: (!habilitado || _enviando)
            ? null
            : (v) {
                if (v && _canal != valor) {
                  setState(() => _canal = valor);
                  _enviar();
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = widget.usuario;
    final destino = _canal == 'sms'
        ? SecurityService.enmascararTelefono(u.telefono)
        : SecurityService.enmascararCorreo(u.email);
    final activo = _otp.existe(_clave) && _restante > Duration.zero;

    return PopScope(
      canPop: !_verificando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Verificación en 2 pasos')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BannerDegradado(
                        icono: Icons.verified_user_rounded,
                        titulo: 'Verificación 2FA',
                        subtitulo: 'Hola, ${u.primerNombre} · @${u.username}',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hemos enviado un código de seguridad temporal (OTP) a $destino. '
                        'Ingrésalo a continuación para completar tu autenticación.',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Selector de canal
                      Row(children: [
                        _chipCanal('correo', 'Correo', Icons.email_outlined, true),
                        const SizedBox(width: 8),
                        _chipCanal('sms', 'SMS', Icons.sms_outlined, u.tieneTelefono),
                      ]),
                      if (!u.tieneTelefono)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Agrega un teléfono en tu perfil para usar SMS.',
                              style: TextStyle(fontSize: 11, color: cs.outline)),
                        ),
                      const SizedBox(height: 10),

                      if (_envio != null && _envio!.esDemo)
                        AvisoDemo(
                          mensaje: _envio!.mensaje,
                          codigo: _envio!.codigoDemo,
                          canal: _canal,
                          onUsar: () => setState(() {
                            _codigo.text = _envio!.codigoDemo!;
                            _error = null;
                          }),
                        )
                      else if (_envio != null && _envio!.enviado)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            const Icon(Icons.mark_email_read_outlined,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_envio!.mensaje,
                                    style: const TextStyle(fontSize: 12))),
                          ]),
                        ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _codigo,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                          labelText: 'Código de 6 dígitos',
                          prefixIcon: const Icon(Icons.key_rounded),
                          errorText: _error,
                          errorMaxLines: 2,
                        ),
                        onSubmitted: (_) => _verificar(),
                      ),
                      const SizedBox(height: 14),

                      // Temporizador
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 16, color: activo ? Colors.grey : Colors.red),
                          const SizedBox(width: 6),
                          Text(
                            _enviando
                                ? 'Enviando código...'
                                : activo
                                    ? 'Expira en: ${_formato(_restante)}'
                                    : 'El código ha expirado',
                            style: TextStyle(
                              fontSize: 12,
                              color: activo || _enviando ? Colors.grey : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: (_enviando || _reenvio > 0) ? null : _enviar,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(_reenvio > 0
                            ? 'Reenviar código en $_reenvio s'
                            : 'Reenviar nuevo código OTP'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: (_verificando || _enviando) ? null : _verificar,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        icon: _verificando
                            ? const CargandoBoton()
                            : const Icon(Icons.verified_user_rounded),
                        label: const Text('Verificar y Entrar',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _verificando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      Text(
                        'Máximo ${OtpService.maxIntentos} intentos por código. Nunca compartas este código.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                    ],
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
