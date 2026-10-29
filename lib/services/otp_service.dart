import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

enum EstadoOtp { valido, incorrecto, expirado, sinIntentos, inexistente }

class ResultadoOtp {
  final EstadoOtp estado;
  final int intentosRestantes;
  const ResultadoOtp(this.estado, this.intentosRestantes);

  bool get ok => estado == EstadoOtp.valido;

  String get mensaje {
    switch (estado) {
      case EstadoOtp.valido:
        return 'Código verificado';
      case EstadoOtp.incorrecto:
        return 'Código incorrecto. Te quedan $intentosRestantes intento(s).';
      case EstadoOtp.expirado:
        return 'El código expiró. Solicita uno nuevo.';
      case EstadoOtp.sinIntentos:
        return 'Agotaste los intentos. Solicita un código nuevo.';
      case EstadoOtp.inexistente:
        return 'No hay un código activo. Solicita uno nuevo.';
    }
  }
}

class _OtpPendiente {
  final String hash;
  final DateTime expira;
  final DateTime creado;
  int intentos = 0;
  _OtpPendiente(this.hash, this.expira, this.creado);
}

/// Genera y verifica códigos de un solo uso (6 dígitos).
/// Solo se guarda el hash SHA-256 del código, nunca el código.
class OtpService {
  OtpService({DateTime Function()? reloj, Random? random})
      : _reloj = reloj ?? DateTime.now,
        _random = random ?? Random.secure();

  static final OtpService instance = OtpService();

  static const int maxIntentos = 3;
  static const Duration esperaReenvio = Duration(seconds: 30);

  final DateTime Function() _reloj;
  final Random _random;
  final Map<String, _OtpPendiente> _pendientes = {};

  static String hashCodigo(String codigo) =>
      sha256.convert(utf8.encode(codigo.trim())).toString();

  String generarCodigo() =>
      List.generate(6, (_) => _random.nextInt(10)).join();

  /// Crea un código para [clave] (p. ej. "login:5") y lo devuelve para enviarlo.
  String crear(String clave, Duration vigencia) {
    final codigo = generarCodigo();
    final ahora = _reloj();
    _pendientes[clave] =
        _OtpPendiente(hashCodigo(codigo), ahora.add(vigencia), ahora);
    return codigo;
  }

  ResultadoOtp verificar(String clave, String codigo) {
    final p = _pendientes[clave];
    if (p == null) return const ResultadoOtp(EstadoOtp.inexistente, 0);
    if (_reloj().isAfter(p.expira)) {
      _pendientes.remove(clave);
      return const ResultadoOtp(EstadoOtp.expirado, 0);
    }
    if (p.intentos >= maxIntentos) {
      _pendientes.remove(clave);
      return const ResultadoOtp(EstadoOtp.sinIntentos, 0);
    }
    final esperado = p.hash;
    final recibido = hashCodigo(codigo);
    if (_iguales(esperado, recibido)) {
      _pendientes.remove(clave);
      return const ResultadoOtp(EstadoOtp.valido, maxIntentos);
    }
    p.intentos++;
    final restantes = maxIntentos - p.intentos;
    if (restantes <= 0) {
      _pendientes.remove(clave);
      return const ResultadoOtp(EstadoOtp.sinIntentos, 0);
    }
    return ResultadoOtp(EstadoOtp.incorrecto, restantes);
  }

  /// Tiempo restante de vigencia (cero si no existe o ya expiró).
  Duration restante(String clave) {
    final p = _pendientes[clave];
    if (p == null) return Duration.zero;
    final d = p.expira.difference(_reloj());
    return d.isNegative ? Duration.zero : d;
  }

  /// Segundos que faltan para poder reenviar.
  int segundosParaReenvio(String clave) {
    final p = _pendientes[clave];
    if (p == null) return 0;
    final d = esperaReenvio - _reloj().difference(p.creado);
    return d.isNegative ? 0 : d.inSeconds;
  }

  bool existe(String clave) => _pendientes.containsKey(clave);

  void cancelar(String clave) => _pendientes.remove(clave);

  static bool _iguales(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }
}
