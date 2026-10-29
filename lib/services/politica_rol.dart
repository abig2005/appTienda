/// Reglas de seguridad por rol: más privilegios = reglas más estrictas.
///
/// | Rol    | Contraseña                         | Intentos | Bloqueo | OTP  | Recuperación |
/// |--------|------------------------------------|----------|---------|------|--------------|
/// | admin  | 10+, mayúscula, número, símbolo    | 3        | 15 min  | 3 min| 5 min        |
/// | editor | 8+, mayúscula, número              | 5        | 10 min  | 5 min| 10 min       |
/// | lector | 8+, letra y número                 | 5        | 5 min   | 5 min| 15 min       |
library;

class RequisitoPassword {
  final String descripcion;
  final bool Function(String) cumple;
  const RequisitoPassword(this.descripcion, this.cumple);
}

class PoliticaRol {
  final String rol;
  final int longitudMinima;
  final bool requiereMayuscula;
  final bool requiereNumero;
  final bool requiereSimbolo;
  final bool requiereLetra;
  final int maxIntentos;
  final Duration duracionBloqueo;
  final Duration vigenciaOtp;
  final Duration vigenciaRecuperacion;

  const PoliticaRol._({
    required this.rol,
    required this.longitudMinima,
    required this.requiereMayuscula,
    required this.requiereNumero,
    required this.requiereSimbolo,
    required this.requiereLetra,
    required this.maxIntentos,
    required this.duracionBloqueo,
    required this.vigenciaOtp,
    required this.vigenciaRecuperacion,
  });

  static const admin = PoliticaRol._(
    rol: 'admin',
    longitudMinima: 10,
    requiereMayuscula: true,
    requiereNumero: true,
    requiereSimbolo: true,
    requiereLetra: true,
    maxIntentos: 3,
    duracionBloqueo: Duration(minutes: 15),
    vigenciaOtp: Duration(minutes: 3),
    vigenciaRecuperacion: Duration(minutes: 5),
  );

  static const editor = PoliticaRol._(
    rol: 'editor',
    longitudMinima: 8,
    requiereMayuscula: true,
    requiereNumero: true,
    requiereSimbolo: false,
    requiereLetra: true,
    maxIntentos: 5,
    duracionBloqueo: Duration(minutes: 10),
    vigenciaOtp: Duration(minutes: 5),
    vigenciaRecuperacion: Duration(minutes: 10),
  );

  static const lector = PoliticaRol._(
    rol: 'lector',
    longitudMinima: 8,
    requiereMayuscula: false,
    requiereNumero: true,
    requiereSimbolo: false,
    requiereLetra: true,
    maxIntentos: 5,
    duracionBloqueo: Duration(minutes: 5),
    vigenciaOtp: Duration(minutes: 5),
    vigenciaRecuperacion: Duration(minutes: 15),
  );

  static PoliticaRol de(String rol) {
    switch (rol) {
      case 'admin':
        return admin;
      case 'editor':
        return editor;
      default:
        return lector;
    }
  }

  static final _mayuscula = RegExp(r'[A-ZÁÉÍÓÚÑ]');
  static final _letra = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]');
  static final _numero = RegExp(r'[0-9]');
  static final _simbolo = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/;'`~¿¡°]''');

  List<RequisitoPassword> get requisitos => [
        RequisitoPassword('Al menos $longitudMinima caracteres',
            (p) => p.length >= longitudMinima),
        if (requiereLetra && !requiereMayuscula)
          RequisitoPassword('Al menos una letra', (p) => _letra.hasMatch(p)),
        if (requiereMayuscula)
          RequisitoPassword(
              'Al menos una mayúscula', (p) => _mayuscula.hasMatch(p)),
        if (requiereNumero)
          RequisitoPassword('Al menos un número', (p) => _numero.hasMatch(p)),
        if (requiereSimbolo)
          RequisitoPassword(
              'Al menos un símbolo (!@#\$...)', (p) => _simbolo.hasMatch(p)),
      ];

  bool esValida(String password) => requisitos.every((r) => r.cumple(password));

  List<String> faltantes(String password) => requisitos
      .where((r) => !r.cumple(password))
      .map((r) => r.descripcion)
      .toList();

  String get resumenTexto =>
      requisitos.map((r) => r.descripcion.toLowerCase()).join(', ');
}
