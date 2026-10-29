import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Envío de SMS con la API REST de Twilio (Basic Auth).
class SmsService {
  SmsService._();

  /// Normaliza a E.164 usando la lada por defecto.
  /// "55 1234 5678" → "+525512345678"
  static String aE164(String telefono) {
    final t = telefono.trim();
    if (t.isEmpty) return '';
    final digitos = t.replaceAll(RegExp(r'\D'), '');
    if (t.startsWith('+')) return '+$digitos';
    if (t.startsWith('00')) return '+${digitos.substring(2)}';
    final lada = AppConfig.ladaPorDefecto.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 10) return '+$lada$digitos';
    if (digitos.startsWith(lada) && digitos.length > 10) return '+$digitos';
    return '+$lada$digitos';
  }

  /// Devuelve `true` si Twilio aceptó el mensaje.
  static Future<bool> enviar(String telefono, String mensaje) async {
    if (!AppConfig.smsConfigurado) return false;
    final destino = aE164(telefono);
    if (destino.length < 8) return false;
    try {
      final uri = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/${AppConfig.twilioAccountSid}/Messages.json');
      final auth = base64Encode(utf8.encode(
          '${AppConfig.twilioAccountSid}:${AppConfig.twilioAuthToken}'));
      final r = await http
          .post(
            uri,
            headers: {'Authorization': 'Basic $auth'},
            body: {
              'To': destino,
              'From': AppConfig.twilioNumero,
              'Body': mensaje,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 201 || r.statusCode == 200) return true;
      debugPrint('[SMS] Twilio respondió ${r.statusCode}: ${r.body}');
      return false;
    } catch (e) {
      debugPrint('[SMS] Error: $e');
      return false;
    }
  }
}
