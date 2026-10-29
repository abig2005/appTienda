import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/nombre_persona.dart';
import '../models/notificacion.dart';
import '../models/usuario.dart';
import '../repository/usuario_repository.dart';
import 'codigo_service.dart';
import 'mail_helper.dart';
import 'notification_service.dart';
import 'otp_service.dart';
import 'politica_rol.dart';
import 'security_service.dart';
import 'sms_service.dart';

enum EstadoLogin { ok, credencialesInvalidas, bloqueado }

class ResultadoLogin {
  final EstadoLogin estado;
  final Usuario? usuario;
  final String mensaje;
  const ResultadoLogin(this.estado, this.mensaje, [this.usuario]);
  bool get ok => estado == EstadoLogin.ok;
}

/// Resultado de una operación simple (éxito + mensaje).
class Resultado {
  final bool ok;
  final String mensaje;
  const Resultado(this.ok, this.mensaje);
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _repo = UsuarioRepository.instance;
  final _sec = SecurityService.instance;
  final _otp = OtpService.instance;
  final _notif = NotificationService.instance;

  /// Después de verificar el código de recuperación hay 10 min para guardar.
  static const ventanaRecuperacion = Duration(minutes: 10);
  final Map<int, DateTime> _recuperacionVerificada = {};

  static const _mensajeGenerico = 'Usuario o contraseña incorrectos.';

  // ---------------------------------------------------------------------------
  // Login con contraseña
  // ---------------------------------------------------------------------------

  Future<ResultadoLogin> login(String identificador, String password) async {
    final usuario = await _repo.porIdentificador(identificador);
    if (usuario == null) {
      // Calculamos un hash igualmente para no revelar por tiempo de respuesta.
      await _sec.hashPassword(password);
      return const ResultadoLogin(
          EstadoLogin.credencialesInvalidas, _mensajeGenerico);
    }

    if (usuario.estaBloqueado) {
      return ResultadoLogin(EstadoLogin.bloqueado,
          'Cuenta bloqueada temporalmente. Intenta de nuevo en ${_minutosRestantes(usuario.bloqueadoHasta!)} min.');
    }

    final politica = PoliticaRol.de(usuario.rol);
    final valida = await _sec.verificarPassword(password, usuario.password);

    if (valida) {
      // Si la contraseña seguía en texto plano, la convertimos a hash.
      if (!SecurityService.esHash(usuario.password)) {
        await _repo.actualizarPassword(
            usuario.id!, await _sec.hashPassword(password));
      } else if (usuario.intentosFallidos > 0) {
        await _repo.desbloquear(usuario.id!);
      }
      return ResultadoLogin(EstadoLogin.ok, 'Contraseña correcta',
          usuario.copyWith(intentosFallidos: 0, limpiarBloqueo: true));
    }

    final intentos = usuario.intentosFallidos + 1;
    if (intentos >= politica.maxIntentos) {
      final hasta = DateTime.now().add(politica.duracionBloqueo);
      await _repo.registrarIntentoFallido(usuario.id!, 0, bloquearHasta: hasta);
      final minutos = politica.duracionBloqueo.inMinutes;
      // Alerta por correo y notificación (sin esperar el correo).
      MailHelper.enviarAlertaSeguridad(
        usuario.email,
        usuario.nombre,
        'Cuenta bloqueada',
        'Detectamos $intentos intentos fallidos de inicio de sesión. Por seguridad bloqueamos tu cuenta durante $minutos minutos. Si no fuiste tú, cambia tu contraseña.',
      );
      await _notif.notificar(
        titulo: '🔒 Cuenta bloqueada',
        cuerpo:
            'La cuenta @${usuario.username} se bloqueó $minutos min por intentos fallidos.',
        tipo: TipoNotificacion.seguridad,
        usuarioId: usuario.id,
      );
      return ResultadoLogin(EstadoLogin.bloqueado,
          'Demasiados intentos. La cuenta se bloqueó durante $minutos minutos.');
    }

    await _repo.registrarIntentoFallido(usuario.id!, intentos);
    final restantes = politica.maxIntentos - intentos;
    return ResultadoLogin(EstadoLogin.credencialesInvalidas,
        '$_mensajeGenerico Te quedan $restantes intento(s).');
  }

  static int _minutosRestantes(DateTime hasta) {
    final s = hasta.difference(DateTime.now()).inSeconds;
    return max(1, (s / 60).ceil());
  }

  // ---------------------------------------------------------------------------
  // 2FA
  // ---------------------------------------------------------------------------

  static String claveLogin(int usuarioId) => 'login:$usuarioId';
  static String claveRecuperacion(int usuarioId) => 'recuperar:$usuarioId';
  static String claveRegistro(String email) =>
      'registro:${email.trim().toLowerCase()}';

  Future<EnvioCodigo> enviarOtpLogin(Usuario u, String canal) async {
    final politica = PoliticaRol.de(u.rol);
    final codigo = _otp.crear(claveLogin(u.id!), politica.vigenciaOtp);
    return CodigoService.enviar(
      canal: canal,
      codigo: codigo,
      proposito: PropositoCodigo.login,
      minutos: politica.vigenciaOtp.inMinutes,
      nombre: u.nombre,
      email: u.email,
      telefono: u.telefono,
    );
  }

  ResultadoOtp verificarOtpLogin(Usuario u, String codigo) =>
      _otp.verificar(claveLogin(u.id!), codigo);

  /// Se llama al completar el acceso (cualquier método).
  Future<void> registrarInicioSesion(Usuario u, String metodo) async {
    _notif.usuarioActualId = u.id;
    await _notif.notificar(
      titulo: 'Nuevo inicio de sesión',
      cuerpo: 'Hola ${u.primerNombre}, entraste con $metodo.',
      tipo: TipoNotificacion.seguridad,
      usuarioId: u.id,
    );
  }

  // ---------------------------------------------------------------------------
  // Registro
  // ---------------------------------------------------------------------------

  Future<EnvioCodigo> enviarCodigoRegistro(String nombre, String email) async {
    final politica = PoliticaRol.lector;
    final codigo = _otp.crear(claveRegistro(email), politica.vigenciaOtp);
    return CodigoService.enviar(
      canal: 'correo',
      codigo: codigo,
      proposito: PropositoCodigo.registro,
      minutos: politica.vigenciaOtp.inMinutes,
      nombre: nombre,
      email: email,
    );
  }

  ResultadoOtp verificarCodigoRegistro(String email, String codigo) =>
      _otp.verificar(claveRegistro(email), codigo);

  /// Valida datos de registro / edición. Devuelve null si todo está bien.
  Future<String?> validarDatosCuenta({
    required NombrePersona nombre,
    required String email,
    required String username,
    String? password,
    String rol = 'lector',
    int? excepto,
  }) async {
    final errNombre = validarNombre(nombre);
    if (errNombre != null) return errNombre;
    if (!esCorreoValido(email)) return 'El correo no es válido.';
    if (!RegExp(r'^[a-zA-Z0-9._]{3,20}$').hasMatch(username.trim())) {
      return 'El usuario debe tener de 3 a 20 letras, números, punto o guion bajo.';
    }
    if (await _repo.emailEnUso(email, excepto: excepto)) {
      return 'Ese correo ya está registrado.';
    }
    if (await _repo.usernameEnUso(username, excepto: excepto)) {
      return 'Ese nombre de usuario ya está ocupado.';
    }
    if (password != null) {
      final faltan = PoliticaRol.de(rol).faltantes(password);
      if (faltan.isNotEmpty) return 'La contraseña no cumple: ${faltan.join(', ').toLowerCase()}.';
    }
    return null;
  }

  /// Nombre(s) y apellido paterno obligatorios; apellido materno opcional.
  static String? validarNombre(NombrePersona n) =>
      NombrePersona.validar(n.nombres, 'nombre') ??
      NombrePersona.validar(n.apellidoPaterno, 'apellido paterno') ??
      NombrePersona.validar(n.apellidoMaterno, 'apellido materno', requerido: false);

  static bool esCorreoValido(String e) =>
      RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(e.trim());

  static bool esTelefonoValido(String t) {
    final d = t.replaceAll(RegExp(r'\D'), '');
    return t.trim().isEmpty || (d.length >= 10 && d.length <= 15);
  }

  Future<Usuario?> crearCuenta({
    required NombrePersona nombre,
    required String email,
    required String username,
    required String password,
    String rol = 'lector',
    String? telefono,
  }) async {
    final id = await _repo.insertar(
      nombre: nombre,
      email: email,
      username: username,
      passwordHash: await _sec.hashPassword(password),
      rol: rol,
      telefono: telefono,
    );
    return _repo.porId(id);
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  /// Busca o crea (rol lector) la cuenta asociada al correo de Google.
  Future<Usuario?> usuarioDesdeGoogle(String email, String? nombre) async {
    final existente = await _repo.porEmail(email);
    if (existente != null) return existente;
    final username = await _repo.sugerirUsername(email);
    // Contraseña aleatoria: esta cuenta entra con Google.
    final aleatoria = List.generate(
        24, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
    final id = await _repo.insertar(
      // El nombre de Google llega en un solo texto: lo separamos en partes.
      nombre: NombrePersona.desdeCompleto(
          (nombre == null || nombre.trim().isEmpty) ? email.split('@').first : nombre),
      email: email,
      username: username,
      passwordHash: await _sec.hashPassword(aleatoria),
      rol: 'lector',
      proveedor: 'google',
    );
    return _repo.porId(id);
  }

  // ---------------------------------------------------------------------------
  // Recuperar usuario
  // ---------------------------------------------------------------------------

  static const mensajeRecuperarUsuario =
      'Si los datos corresponden a una cuenta, te enviamos tu nombre de usuario.';

  /// Siempre responde lo mismo para no revelar qué cuentas existen.
  /// Devuelve el texto de demo cuando no hay correo/SMS configurado.
  Future<String?> recuperarUsuario(String dato, String canal) async {
    String? demo;
    try {
      final List<Usuario> cuentas;
      if (canal == 'sms') {
        cuentas = await _repo.porTelefono(dato);
      } else {
        final u = await _repo.porEmail(dato);
        cuentas = u == null ? [] : [u];
      }
      for (final u in cuentas) {
        final enmascarado = SecurityService.enmascararCorreo(u.email);
        bool ok;
        if (canal == 'sms') {
          ok = await SmsService.enviar(u.telefono ?? '',
              'Tu usuario es @${u.username} (${u.rolLegible}, ${u.tipoCuenta}). Correo: $enmascarado');
        } else {
          ok = await MailHelper.enviarRecordatorioUsuario(
              u.email, u.nombre, u.username, u.tipoCuenta, enmascarado);
        }
        await _notif.notificar(
          titulo: 'Recuperación de usuario',
          cuerpo: 'Se solicitó un recordatorio de tu nombre de usuario.',
          tipo: TipoNotificacion.seguridad,
          usuarioId: u.id,
        );
        if (!ok) {
          demo = 'Modo demostración: tu usuario es @${u.username} '
              '(${u.rolLegible} · ${u.tipoCuenta} · $enmascarado)';
        }
      }
    } catch (e) {
      debugPrint('recuperarUsuario: $e');
    }
    return demo;
  }

  // ---------------------------------------------------------------------------
  // Recuperar / cambiar contraseña
  // ---------------------------------------------------------------------------

  Future<EnvioCodigo> enviarCodigoRecuperacion(Usuario u, String canal) async {
    final politica = PoliticaRol.de(u.rol);
    final codigo =
        _otp.crear(claveRecuperacion(u.id!), politica.vigenciaRecuperacion);
    return CodigoService.enviar(
      canal: canal,
      codigo: codigo,
      proposito: PropositoCodigo.recuperacion,
      minutos: politica.vigenciaRecuperacion.inMinutes,
      nombre: u.nombre,
      email: u.email,
      telefono: u.telefono,
    );
  }

  bool hayCodigoRecuperacion(Usuario u) =>
      _otp.existe(claveRecuperacion(u.id!));

  ResultadoOtp verificarCodigoRecuperacion(Usuario u, String codigo) {
    final r = _otp.verificar(claveRecuperacion(u.id!), codigo);
    if (r.ok) {
      _recuperacionVerificada[u.id!] = DateTime.now().add(ventanaRecuperacion);
    }
    return r;
  }

  Duration tiempoParaGuardar(Usuario u) {
    final h = _recuperacionVerificada[u.id!];
    if (h == null) return Duration.zero;
    final d = h.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Restablece tras verificar el código (dentro de la ventana de 10 min).
  Future<Resultado> restablecerPassword(Usuario u, String nueva) async {
    if (tiempoParaGuardar(u) == Duration.zero) {
      return const Resultado(false,
          'Se agotó el tiempo para guardar. Solicita un código nuevo.');
    }
    final r = await _guardarNuevaPassword(u, nueva, 'restableció');
    if (r.ok) _recuperacionVerificada.remove(u.id!);
    return r;
  }

  /// Cambio de contraseña desde Perfil (requiere la actual).
  Future<Resultado> cambiarPassword(
      Usuario u, String actual, String nueva) async {
    final fresco = await _repo.porId(u.id!);
    if (fresco == null) return const Resultado(false, 'La cuenta no existe.');
    if (!await _sec.verificarPassword(actual, fresco.password)) {
      return const Resultado(false, 'La contraseña actual no es correcta.');
    }
    return _guardarNuevaPassword(fresco, nueva, 'cambió');
  }

  Future<Resultado> _guardarNuevaPassword(
      Usuario u, String nueva, String verbo) async {
    final politica = PoliticaRol.de(u.rol);
    final faltan = politica.faltantes(nueva);
    if (faltan.isNotEmpty) {
      return Resultado(false, 'Falta: ${faltan.join(', ').toLowerCase()}.');
    }
    final fresco = await _repo.porId(u.id!) ?? u;
    if (await _sec.verificarPassword(nueva, fresco.password)) {
      return const Resultado(
          false, 'La nueva contraseña no puede ser igual a la anterior.');
    }
    await _repo.actualizarPassword(u.id!, await _sec.hashPassword(nueva));
    MailHelper.enviarAlertaSeguridad(
      u.email,
      u.nombre,
      'Contraseña actualizada',
      'La contraseña de tu cuenta @${u.username} se $verbo correctamente. Si no fuiste tú, contacta al administrador de inmediato.',
    );
    await _notif.notificar(
      titulo: 'Contraseña actualizada',
      cuerpo: 'La contraseña de @${u.username} se $verbo.',
      tipo: TipoNotificacion.seguridad,
      usuarioId: u.id,
    );
    return const Resultado(true, 'Contraseña actualizada correctamente.');
  }
}
