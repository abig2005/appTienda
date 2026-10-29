import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/comunes.dart';

class RecuperarUsuarioView extends StatefulWidget {
  const RecuperarUsuarioView({super.key});

  @override
  State<RecuperarUsuarioView> createState() => _RecuperarUsuarioViewState();
}

class _RecuperarUsuarioViewState extends State<RecuperarUsuarioView> {
  final _dato = TextEditingController();
  String _canal = 'correo';
  bool _cargando = false;
  bool _enviado = false;
  String? _demo;
  String? _error;

  @override
  void dispose() {
    _dato.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final v = _dato.text.trim();
    if (_canal == 'correo' && !AuthService.esCorreoValido(v)) {
      setState(() => _error = 'Ingresa un correo válido');
      return;
    }
    if (_canal == 'sms' && v.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'Ingresa tu teléfono a 10 dígitos');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final demo = await AuthService.instance.recuperarUsuario(v, _canal);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _enviado = true;
      _demo = demo;
    });
  }

  Widget _chip(String valor, String etiqueta, IconData icono) => Expanded(
        child: ChoiceChip(
          label: Text(etiqueta, style: const TextStyle(fontSize: 12)),
          avatar: Icon(icono, size: 16),
          selected: _canal == valor,
          onSelected: (_) => setState(() {
            _canal = valor;
            _dato.clear();
            _enviado = false;
            _demo = null;
            _error = null;
          }),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperación de Usuario')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BannerDegradado(
                      icono: Icons.person_search_rounded,
                      titulo: '¿Olvidaste tu usuario?',
                      subtitulo: 'Te enviamos tu usuario, tipo de cuenta y correo',
                    ),
                    const SizedBox(height: 18),
                    const Text('¿Cómo quieres buscar tu cuenta?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _chip('correo', 'Por correo', Icons.email_outlined),
                      const SizedBox(width: 8),
                      _chip('sms', 'Por teléfono', Icons.phone_outlined),
                    ]),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _dato,
                      keyboardType: _canal == 'correo'
                          ? TextInputType.emailAddress
                          : TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: _canal == 'correo'
                            ? 'Correo de tu cuenta'
                            : 'Teléfono registrado',
                        hintText:
                            _canal == 'correo' ? 'nombre@dominio.com' : '55 1234 5678',
                        prefixIcon: Icon(_canal == 'correo' ? Icons.email : Icons.phone),
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _cargando ? null : _enviar,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: _cargando ? const CargandoBoton() : const Icon(Icons.send_rounded),
                      label: const Text('Enviar recordatorio',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: !_enviado
                          ? const SizedBox.shrink()
                          : Column(
                              key: ValueKey(_demo),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.green.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.mark_email_read_outlined,
                                        color: Colors.green),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(AuthService.mensajeRecuperarUsuario,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                          Text(
                                            _canal == 'correo'
                                                ? 'Revisa tu bandeja de entrada y spam.'
                                                : 'Revisa tus mensajes SMS.',
                                            style: TextStyle(
                                                fontSize: 12, color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ),
                                if (_demo != null) AvisoDemo(mensaje: _demo!),
                              ],
                            ),
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
