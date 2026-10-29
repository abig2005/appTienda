import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

import '../config/app_config.dart';
import '../models/item_carrito.dart';

/// Envío de correos HTML vía Gmail SMTP.
/// [sendEmail] nunca lanza excepciones: devuelve `false` si no hay
/// configuración (modo demostración) o si el envío falla.
class MailHelper {
  MailHelper._();

  static const _azul = '#1E2A47';
  static const _azulClaro = '#2E3F66';
  static const _fondo = '#F2F4F8';

  static final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  static Future<bool> sendEmail({
    required String para,
    required String asunto,
    required String html,
    String? texto,
  }) async {
    if (!AppConfig.correoConfigurado) {
      debugPrint('[MailHelper] Correo no configurado: modo demostración.');
      return false;
    }
    try {
      final servidor = gmail(AppConfig.smtpUsuario, AppConfig.smtpPassword);
      final mensaje = Message()
        ..from = Address(AppConfig.smtpUsuario, AppConfig.smtpRemitente)
        ..recipients.add(para)
        ..subject = asunto
        ..text = texto ?? _sinHtml(html)
        ..html = html;
      await send(mensaje, servidor, timeout: const Duration(seconds: 20))
          .timeout(const Duration(seconds: 20));
      return true;
    } on MailerException catch (e) {
      debugPrint('[MailHelper] Error SMTP: ${e.message}');
      for (final p in e.problems) {
        debugPrint('  ${p.code}: ${p.msg}');
      }
      return false;
    } on TimeoutException {
      debugPrint('[MailHelper] Tiempo de espera agotado.');
      return false;
    } catch (e) {
      debugPrint('[MailHelper] Error: $e');
      return false;
    }
  }

  static String _sinHtml(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
      .trim();

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Plantilla común con la paleta azul oscuro.
  static String plantilla({
    required String titulo,
    required String contenido,
    String? pie,
  }) {
    final anio = DateTime.now().year;
    return '''
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:$_fondo;font-family:Arial,Helvetica,sans-serif;color:#1d1d1f;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_fondo;padding:24px 0;">
    <tr><td align="center">
      <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;background:#ffffff;border-radius:14px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.06);">
        <tr><td style="background:$_azul;padding:22px 28px;color:#ffffff;">
          <div style="font-size:13px;opacity:.8;letter-spacing:1px;text-transform:uppercase;">${_esc(AppConfig.appName)}</div>
          <div style="font-size:22px;font-weight:bold;margin-top:4px;">${_esc(titulo)}</div>
        </td></tr>
        <tr><td style="padding:26px 28px;font-size:15px;line-height:1.55;">
          $contenido
        </td></tr>
        <tr><td style="background:$_fondo;padding:16px 28px;font-size:12px;color:#6b7280;">
          ${pie ?? 'Si no reconoces esta actividad, cambia tu contraseña y contacta al administrador.'}<br>
          © $anio ${_esc(AppConfig.appName)}. Este es un correo automático, no respondas.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>''';
  }

  static String _cajaCodigo(String codigo) => '''
<div style="margin:22px 0;text-align:center;">
  <span style="display:inline-block;background:$_azulClaro;color:#ffffff;font-size:32px;letter-spacing:10px;font-weight:bold;padding:14px 26px;border-radius:10px;">$codigo</span>
</div>''';

  // ---------------------------------------------------------------------------
  // Plantillas
  // ---------------------------------------------------------------------------

  static Future<bool> enviarOtpLogin(
      String para, String nombre, String codigo, int minutos) {
    return sendEmail(
      para: para,
      asunto: 'Tu código de acceso: $codigo',
      html: plantilla(
        titulo: 'Código de inicio de sesión',
        contenido: '''
<p>Hola <b>${_esc(nombre)}</b>,</p>
<p>Usa este código para completar tu inicio de sesión:</p>
${_cajaCodigo(codigo)}
<p>Vence en <b>$minutos minutos</b> y solo puede usarse una vez. Nunca lo compartas con nadie.</p>''',
      ),
    );
  }

  static Future<bool> enviarCodigoRegistro(
      String para, String nombre, String codigo, int minutos) {
    return sendEmail(
      para: para,
      asunto: 'Verifica tu correo: $codigo',
      html: plantilla(
        titulo: 'Verifica tu correo',
        contenido: '''
<p>Hola <b>${_esc(nombre)}</b>, ¡gracias por registrarte!</p>
<p>Escribe este código en la app para confirmar tu correo:</p>
${_cajaCodigo(codigo)}
<p>Vence en <b>$minutos minutos</b>.</p>''',
        pie: 'Si no creaste una cuenta, ignora este correo.',
      ),
    );
  }

  static Future<bool> enviarCodigoRecuperacion(
      String para, String nombre, String codigo, int minutos) {
    return sendEmail(
      para: para,
      asunto: 'Código para restablecer tu contraseña',
      html: plantilla(
        titulo: 'Restablecer contraseña',
        contenido: '''
<p>Hola <b>${_esc(nombre)}</b>,</p>
<p>Recibimos una solicitud para restablecer tu contraseña. Tu código es:</p>
${_cajaCodigo(codigo)}
<p>Vence en <b>$minutos minutos</b>. Si no lo solicitaste, ignora este correo: tu contraseña no cambiará.</p>''',
      ),
    );
  }

  static Future<bool> enviarRecordatorioUsuario(
      String para, String nombre, String username, String tipoCuenta,
      String correoEnmascarado) {
    return sendEmail(
      para: para,
      asunto: 'Tu nombre de usuario en ${AppConfig.appName}',
      html: plantilla(
        titulo: 'Recordatorio de usuario',
        contenido: '''
<p>Hola <b>${_esc(nombre)}</b>,</p>
<p>Estos son los datos de tu cuenta:</p>
<table cellpadding="8" style="border-collapse:collapse;width:100%;background:$_fondo;border-radius:8px;">
  <tr><td style="color:#6b7280;">Usuario</td><td><b>@${_esc(username)}</b></td></tr>
  <tr><td style="color:#6b7280;">Tipo de cuenta</td><td>${_esc(tipoCuenta)}</td></tr>
  <tr><td style="color:#6b7280;">Correo</td><td>${_esc(correoEnmascarado)}</td></tr>
</table>
<p>Puedes iniciar sesión con tu usuario o con tu correo.</p>''',
      ),
    );
  }

  static Future<bool> enviarAlertaSeguridad(
      String para, String nombre, String titulo, String detalle) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    return sendEmail(
      para: para,
      asunto: 'Alerta de seguridad: $titulo',
      html: plantilla(
        titulo: '⚠️ $titulo',
        contenido: '''
<p>Hola <b>${_esc(nombre)}</b>,</p>
<p>${_esc(detalle)}</p>
<p style="color:#6b7280;font-size:13px;">Fecha: $fecha</p>''',
      ),
    );
  }

  static Future<bool> enviarNotaRemision({
    required String para,
    required String nombre,
    required String folio,
    required List<ItemCarrito> items,
    required double total,
    required String metodoPago,
    required String estadoPago,
    required String referencia,
  }) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final filas = items.map((i) => '''
<tr>
  <td style="padding:8px;border-bottom:1px solid #e5e7eb;">${_esc(i.nombre)}</td>
  <td style="padding:8px;border-bottom:1px solid #e5e7eb;text-align:center;">${i.cantidad}</td>
  <td style="padding:8px;border-bottom:1px solid #e5e7eb;text-align:right;">${_moneda.format(i.precio)}</td>
  <td style="padding:8px;border-bottom:1px solid #e5e7eb;text-align:right;">${_moneda.format(i.subtotal)}</td>
</tr>''').join();
    final pendiente = estadoPago == 'pendiente';
    return sendEmail(
      para: para,
      asunto: 'Nota de Remisión $folio',
      html: plantilla(
        titulo: 'Nota de Remisión',
        contenido: '''
<p>Hola <b>${_esc(nombre)}</b>, ${pendiente ? 'registramos tu pedido. Lo enviaremos en cuanto se confirme tu pago.' : '¡gracias por tu compra!'}</p>
<table cellpadding="4" style="width:100%;font-size:14px;margin-bottom:12px;">
  <tr><td style="color:#6b7280;">Folio</td><td><b>$folio</b></td></tr>
  <tr><td style="color:#6b7280;">Fecha</td><td>$fecha</td></tr>
  <tr><td style="color:#6b7280;">Método de pago</td><td>${_esc(metodoPago)}</td></tr>
  <tr><td style="color:#6b7280;">Referencia</td><td>${_esc(referencia)}</td></tr>
  <tr><td style="color:#6b7280;">Estado</td><td style="color:${pendiente ? '#D97706' : '#059669'};font-weight:bold;">${pendiente ? 'Pago pendiente' : 'Pagado'}</td></tr>
</table>
<table cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;font-size:14px;">
  <tr style="background:$_azul;color:#ffffff;">
    <th style="padding:8px;text-align:left;">Producto</th>
    <th style="padding:8px;">Cant.</th>
    <th style="padding:8px;text-align:right;">Precio</th>
    <th style="padding:8px;text-align:right;">Subtotal</th>
  </tr>
  $filas
  <tr>
    <td colspan="3" style="padding:10px 8px;text-align:right;font-weight:bold;">Total</td>
    <td style="padding:10px 8px;text-align:right;font-weight:bold;font-size:16px;">${_moneda.format(total)}</td>
  </tr>
</table>
<p style="font-size:12px;color:#6b7280;margin-top:16px;">Pago simulado con fines de demostración: no se realizó ningún cargo real.</p>''',
        pie: 'Conserva este correo como comprobante de tu pedido.',
      ),
    );
  }
}
