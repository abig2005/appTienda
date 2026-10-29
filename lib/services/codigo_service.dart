import '../config/app_config.dart';
import '../models/notificacion.dart';
import 'mail_helper.dart';
import 'notification_service.dart';
import 'security_service.dart';
import 'sms_service.dart';

enum PropositoCodigo { login, registro, recuperacion }

/// Resultado de enviar un código. Si [codigoDemo] no es nulo, la app está en
/// modo demostración y el código se muestra en el aviso amarillo.
class EnvioCodigo {
  final bool enviado;
  final String? codigoDemo;
  final String mensaje;
  const EnvioCodigo({
    required this.enviado,
    required this.mensaje,
    this.codigoDemo,
  });

  bool get esDemo => codigoDemo != null;
}

/// Envía códigos por correo o SMS, con modo demostración si no hay configuración.
class CodigoService {
  CodigoService._();

  static Future<EnvioCodigo> enviar({
    required String canal, // correo | sms
    required String codigo,
    required PropositoCodigo proposito,
    required int minutos,
    required String nombre,
    String? email,
    String? telefono,
  }) async {
    if (canal == 'sms') {
      return _porSms(codigo, proposito, minutos, telefono ?? '');
    }
    return _porCorreo(codigo, proposito, minutos, nombre, email ?? '');
  }

  static Future<EnvioCodigo> _porCorreo(String codigo, PropositoCodigo p,
      int minutos, String nombre, String email) async {
    if (!AppConfig.correoConfigurado) {
      return EnvioCodigo(
        enviado: false,
        codigoDemo: codigo,
        mensaje: 'Modo demostración: el correo no está configurado.',
      );
    }
    final bool ok;
    switch (p) {
      case PropositoCodigo.login:
        ok = await MailHelper.enviarOtpLogin(email, nombre, codigo, minutos);
      case PropositoCodigo.registro:
        ok = await MailHelper.enviarCodigoRegistro(
            email, nombre, codigo, minutos);
      case PropositoCodigo.recuperacion:
        ok = await MailHelper.enviarCodigoRecuperacion(
            email, nombre, codigo, minutos);
    }
    return EnvioCodigo(
      enviado: ok,
      mensaje: ok
          ? 'Enviamos un código a ${SecurityService.enmascararCorreo(email)}'
          : 'No pudimos enviar el correo. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  static Future<EnvioCodigo> _porSms(
      String codigo, PropositoCodigo p, int minutos, String telefono) async {
    final texto = switch (p) {
      PropositoCodigo.login =>
        '${AppConfig.appName}: tu código de acceso es $codigo. Vence en $minutos min. No lo compartas.',
      PropositoCodigo.registro =>
        '${AppConfig.appName}: tu código de verificación es $codigo. Vence en $minutos min.',
      PropositoCodigo.recuperacion =>
        '${AppConfig.appName}: tu código para restablecer la contraseña es $codigo. Vence en $minutos min.',
    };
    if (!AppConfig.smsConfigurado) {
      // SMS simulado con una notificación local.
      await NotificationService.instance.mostrarSistema(
        'SMS (demo) para ${SecurityService.enmascararTelefono(telefono)}',
        texto,
        tipo: TipoNotificacion.seguridad,
      );
      return EnvioCodigo(
        enviado: false,
        codigoDemo: codigo,
        mensaje: 'Modo demostración: el SMS no está configurado.',
      );
    }
    final ok = await SmsService.enviar(telefono, texto);
    return EnvioCodigo(
      enviado: ok,
      mensaje: ok
          ? 'Enviamos un SMS a ${SecurityService.enmascararTelefono(telefono)}'
          : 'No pudimos enviar el SMS. Intenta por correo.',
    );
  }
}
