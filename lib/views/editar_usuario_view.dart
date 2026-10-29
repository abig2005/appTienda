import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/sesion_controller.dart';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// Edición de usuario por el admin. Devuelve `true` si hubo cambios.
class EditarUsuarioView extends StatefulWidget {
  final Usuario usuario;
  const EditarUsuarioView({super.key, required this.usuario});

  @override
  State<EditarUsuarioView> createState() => _EditarUsuarioViewState();
}

class _EditarUsuarioViewState extends State<EditarUsuarioView> {
  final _form = GlobalKey<FormState>();
  late final _nombres = TextEditingController(text: widget.usuario.partesNombre.nombres);
  late final _paterno =
      TextEditingController(text: widget.usuario.partesNombre.apellidoPaterno);
  late final _materno =
      TextEditingController(text: widget.usuario.partesNombre.apellidoMaterno);
  late final _email = TextEditingController(text: widget.usuario.email);
  late final _username = TextEditingController(text: widget.usuario.username);
  late final _telefono = TextEditingController(text: widget.usuario.telefono ?? '');
  late String _rol = widget.usuario.rol;
  late Usuario _u = widget.usuario;
  bool _guardando = false;
  bool _huboCambios = false;

  final _ctrl = UsuarioController.instance;

  @override
  void dispose() {
    for (final c in [_nombres, _paterno, _materno, _email, _username, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Usuario get _admin => context.read<SesionController>().usuario!;
  bool get _esYo => _admin.id == _u.id;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final r = await _ctrl.guardarEdicion(
      admin: _admin,
      original: _u,
      nombre: CamposNombre.leer(_nombres, _paterno, _materno),
      email: _email.text,
      username: _username.text,
      telefono: _telefono.text,
      rol: _rol,
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    mostrarMensaje(context, r.mensaje, error: !r.ok, exito: r.ok);
    if (r.ok) Navigator.pop(context, true);
  }

  Future<void> _desbloquear() async {
    final r = await _ctrl.desbloquear(_u);
    if (!mounted) return;
    setState(() {
      _u = _u.copyWith(intentosFallidos: 0, limpiarBloqueo: true);
      _huboCambios = true;
    });
    mostrarMensaje(context, r.mensaje, exito: true);
  }

  Future<void> _enviarCodigo() async {
    final si = await confirmar(context,
        titulo: 'Restablecer contraseña',
        mensaje:
            'Enviaremos un código a ${_u.email}. El usuario lo escribirá en "¿Olvidaste tu contraseña?" → "Ya tengo un código" y elegirá su nueva contraseña. Tú no verás ni escribirás la contraseña.',
        si: 'Enviar código',
        icono: Icons.lock_reset_rounded);
    if (!si) return;
    final r = await _ctrl.enviarCodigoRestablecer(_u);
    if (!mounted) return;
    if (r.esDemo) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Código generado'),
          content: AvisoDemo(mensaje: r.mensaje, codigo: r.codigoDemo, canal: 'correo'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
          ],
        ),
      );
    } else {
      mostrarMensaje(context, r.mensaje, error: !r.enviado, exito: r.enviado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar Usuario')),
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
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BannerDegradado(
                          icono: Icons.manage_accounts_rounded,
                          titulo: _u.nombre,
                          subtitulo: '@${_u.username} · ${_u.tipoCuenta}',
                          compacto: true,
                        ),
                        if (_u.estaBloqueado) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(children: [
                              const Icon(Icons.lock_clock, color: Colors.redAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cuenta bloqueada hasta las ${TimeOfDay.fromDateTime(_u.bloqueadoHasta!).format(context)}',
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              TextButton(
                                  onPressed: _desbloquear,
                                  child: const Text('Desbloquear cuenta')),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 20),
                        CamposNombre(
                          nombres: _nombres,
                          apellidoPaterno: _paterno,
                          apellidoMaterno: _materno,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email)),
                          validator: (v) => AuthService.esCorreoValido(v ?? '')
                              ? null
                              : 'Ingresa un correo válido',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _username,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          decoration: const InputDecoration(
                              labelText: 'Nombre de usuario',
                              prefixIcon: Icon(Icons.alternate_email)),
                          validator: (v) =>
                              (v ?? '').trim().length < 3 ? 'Mínimo 3 caracteres' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefono,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Teléfono', prefixIcon: Icon(Icons.phone)),
                          validator: (v) => AuthService.esTelefonoValido(v ?? '')
                              ? null
                              : 'Teléfono no válido',
                        ),
                        const SizedBox(height: 14),
                        const Text('Rol de usuario',
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
                              onSelected: _esYo ? null : (_) => setState(() => _rol = r),
                            );
                          }).toList(),
                        ),
                        if (_esYo)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('No puedes cambiar tu propio rol.',
                                style: TextStyle(fontSize: 11, color: cs.outline)),
                          ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _guardando ? null : _guardar,
                          style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16)),
                          icon: _guardando
                              ? const CargandoBoton()
                              : const Icon(Icons.save_rounded),
                          label: const Text('Guardar cambios',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _enviarCodigo,
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: const Text('Enviar código para restablecer contraseña'),
                        ),
                        if (!_u.estaBloqueado && _u.intentosFallidos > 0) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _desbloquear,
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14)),
                            icon: const Icon(Icons.lock_open_rounded),
                            label: Text(
                                'Reiniciar intentos fallidos (${_u.intentosFallidos})'),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline, size: 16, color: cs.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Al guardar, avisaremos al usuario por correo (al anterior y al nuevo) y con una notificación de seguridad.',
                              style: TextStyle(fontSize: 11, color: cs.outline),
                            ),
                          ),
                        ]),
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
