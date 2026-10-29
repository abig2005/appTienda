import '../models/nombre_persona.dart';
import '../models/notificacion.dart';
import '../models/usuario.dart';
import '../repository/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/codigo_service.dart';
import '../services/mail_helper.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';

/// Acciones de administración de usuarios (solo admin).
class UsuarioController {
  UsuarioController._();
  static final UsuarioController instance = UsuarioController._();

  final _repo = UsuarioRepository.instance;
  final _auth = AuthService.instance;

  Future<List<Usuario>> listar() => _repo.todos();

  Future<Resultado> eliminar(Usuario admin, Usuario u) async {
    if (admin.id == u.id) {
      return const Resultado(false, 'No puedes eliminar tu propia cuenta.');
    }
    await _repo.eliminar(u.id!);
    return Resultado(true, 'Se eliminó a @${u.username}.');
  }

  Future<Resultado> cambiarRol(Usuario admin, Usuario u, String rol) async {
    if (admin.id == u.id) {
      return const Resultado(false, 'No puedes cambiar tu propio rol.');
    }
    if (u.rol == rol) return const Resultado(true, 'Sin cambios.');
    await _repo.actualizarDatos(u.id!, rol: rol);
    await _avisarCambios(u, u.email, [
      'Rol: ${u.rolLegible} → ${Usuario.nombreRol(rol)}',
    ]);
    return Resultado(true, '@${u.username} ahora es ${Usuario.nombreRol(rol)}.');
  }

  /// Guarda la edición del admin y avisa al correo anterior y al nuevo.
  Future<Resultado> guardarEdicion({
    required Usuario admin,
    required Usuario original,
    required NombrePersona nombre,
    required String email,
    required String username,
    required String telefono,
    required String rol,
  }) async {
    final error = await _auth.validarDatosCuenta(
      nombre: nombre,
      email: email,
      username: username,
      excepto: original.id,
    );
    if (error != null) return Resultado(false, error);
    if (!AuthService.esTelefonoValido(telefono)) {
      return const Resultado(false, 'El teléfono debe tener al menos 10 dígitos.');
    }
    if (admin.id == original.id && rol != original.rol) {
      return const Resultado(false, 'No puedes cambiar tu propio rol.');
    }

    final cambios = <String>[];
    final emailN = email.trim().toLowerCase();
    final userN = username.trim().toLowerCase();
    final antes = original.partesNombre;
    void comparar(String campo, String anterior, String nuevo) {
      final n = NombrePersona.capitalizar(nuevo);
      if (n != anterior.trim()) {
        cambios.add('$campo: ${anterior.trim().isEmpty ? '(vacío)' : anterior.trim()} → ${n.isEmpty ? '(vacío)' : n}');
      }
    }

    comparar('Nombre(s)', antes.nombres, nombre.nombres);
    comparar('Apellido paterno', antes.apellidoPaterno, nombre.apellidoPaterno);
    comparar('Apellido materno', antes.apellidoMaterno, nombre.apellidoMaterno);
    if (emailN != original.email) {
      cambios.add('Correo: ${SecurityService.enmascararCorreo(original.email)} → ${SecurityService.enmascararCorreo(emailN)}');
    }
    if (userN != original.username) {
      cambios.add('Usuario: @${original.username} → @$userN');
    }
    if (telefono.trim() != (original.telefono ?? '')) {
      cambios.add('Teléfono: ${SecurityService.enmascararTelefono(original.telefono)} → ${SecurityService.enmascararTelefono(telefono)}');
    }
    if (rol != original.rol) {
      cambios.add('Rol: ${original.rolLegible} → ${Usuario.nombreRol(rol)}');
    }
    if (cambios.isEmpty) return const Resultado(true, 'No hubo cambios.');

    await _repo.actualizarDatos(
      original.id!,
      nombre: nombre,
      email: emailN,
      username: userN,
      telefono: telefono,
      rol: rol,
    );

    await _avisarCambios(original, original.email, cambios);
    if (emailN != original.email) {
      await _avisarCambios(original, emailN, cambios);
    }
    return const Resultado(true, 'Cambios guardados y notificados al usuario.');
  }

  Future<void> _avisarCambios(
      Usuario u, String correo, List<String> cambios) async {
    MailHelper.enviarAlertaSeguridad(
      correo,
      u.nombre,
      'Tu cuenta fue modificada',
      'Un administrador actualizó tu cuenta. Cambios: ${cambios.join('; ')}.',
    );
    await NotificationService.instance.notificar(
      titulo: 'Cuenta editada por el administrador',
      cuerpo: cambios.join('\n'),
      tipo: TipoNotificacion.seguridad,
      usuarioId: u.id,
    );
  }

  Future<Resultado> desbloquear(Usuario u) async {
    await _repo.desbloquear(u.id!);
    await NotificationService.instance.notificar(
      titulo: 'Cuenta desbloqueada',
      cuerpo: 'Un administrador desbloqueó la cuenta @${u.username}.',
      tipo: TipoNotificacion.seguridad,
      usuarioId: u.id,
    );
    return Resultado(true, 'Se desbloqueó @${u.username}.');
  }

  /// El admin no ve ni escribe contraseñas: envía un código al usuario.
  Future<EnvioCodigo> enviarCodigoRestablecer(Usuario u) =>
      _auth.enviarCodigoRecuperacion(u, 'correo');
}
