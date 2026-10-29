/// Configuración de la app leída al compilar con:
///   flutter run --dart-define-from-file=config/env.json
///
/// Ningún secreto vive en el código fuente. Si una clave no se define,
/// la app funciona en "modo demostración" (los códigos se muestran en pantalla).
class AppConfig {
  AppConfig._();

  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'App Tienda');

  static const String productosApiUrl = String.fromEnvironment(
    'PRODUCTOS_API_URL',
    defaultValue: 'https://fakestoreapi.com/products',
  );

  static const String ladaPorDefecto =
      String.fromEnvironment('LADA_POR_DEFECTO', defaultValue: '+52');

  // Enlace público del perfil de PayPal.Me (no es una credencial).
  static const String paypalMeUrl = String.fromEnvironment('PAYPAL_ME_URL');

  // Correo (Gmail con contraseña de aplicación)
  static const String smtpUsuario = String.fromEnvironment('SMTP_USUARIO');
  static const String smtpPassword = String.fromEnvironment('SMTP_PASSWORD');
  static const String smtpRemitente =
      String.fromEnvironment('SMTP_REMITENTE', defaultValue: 'App Tienda');

  // SMS (Twilio, opcional)
  static const String twilioAccountSid =
      String.fromEnvironment('TWILIO_ACCOUNT_SID');
  static const String twilioAuthToken =
      String.fromEnvironment('TWILIO_AUTH_TOKEN');
  static const String twilioNumero = String.fromEnvironment('TWILIO_NUMERO');

  // Usuarios de prueba
  static const String demoAdminEmail =
      String.fromEnvironment('DEMO_ADMIN_EMAIL');
  static const String demoEditorEmail =
      String.fromEnvironment('DEMO_EDITOR_EMAIL');
  static const String demoLectorEmail =
      String.fromEnvironment('DEMO_LECTOR_EMAIL');
  static const String demoAdminTelefono =
      String.fromEnvironment('DEMO_ADMIN_TELEFONO');
  static const String demoEditorTelefono =
      String.fromEnvironment('DEMO_EDITOR_TELEFONO');
  static const String demoLectorTelefono =
      String.fromEnvironment('DEMO_LECTOR_TELEFONO');

  static bool get correoConfigurado =>
      smtpUsuario.trim().isNotEmpty && smtpPassword.trim().isNotEmpty;

  static bool get smsConfigurado =>
      twilioAccountSid.trim().isNotEmpty &&
      twilioAuthToken.trim().isNotEmpty &&
      twilioNumero.trim().isNotEmpty;

  /// Resumen seguro para imprimir al arrancar (sin secretos).
  static String get resumen {
    String marca(bool ok) => ok ? 'configurado' : 'modo demostración';
    String oculto(String v) => v.isEmpty ? '(vacío)' : '(definido)';
    return '''
=== $appName ===
Catálogo:   $productosApiUrl
Lada:       $ladaPorDefecto
Correo:     ${marca(correoConfigurado)} · usuario ${oculto(smtpUsuario)}
SMS:        ${marca(smsConfigurado)}
Demo admin: ${oculto(demoAdminEmail)} · editor: ${oculto(demoEditorEmail)} · lector: ${oculto(demoLectorEmail)}
''';
  }
}
