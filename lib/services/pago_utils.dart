import 'dart:math';

import 'package:flutter/services.dart';

enum MarcaTarjeta { visa, mastercard, amex, desconocida }

/// Validaciones del pago simulado (sin cargos reales).
class PagoUtils {
  PagoUtils._();

  static const tarjetaAprobada = '4242424242424242';
  static const tarjetaRechazada = '4000000000000002';

  static String soloDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  static MarcaTarjeta marca(String numero) {
    final n = soloDigitos(numero);
    if (n.startsWith('4')) return MarcaTarjeta.visa;
    if (RegExp(r'^3[47]').hasMatch(n)) return MarcaTarjeta.amex;
    if (n.length >= 2) {
      final dos = int.parse(n.substring(0, 2));
      if (dos >= 51 && dos <= 55) return MarcaTarjeta.mastercard;
    }
    if (n.length >= 4) {
      final cuatro = int.parse(n.substring(0, 4));
      if (cuatro >= 2221 && cuatro <= 2720) return MarcaTarjeta.mastercard;
    }
    return MarcaTarjeta.desconocida;
  }

  static String nombreMarca(MarcaTarjeta m) => switch (m) {
        MarcaTarjeta.visa => 'Visa',
        MarcaTarjeta.mastercard => 'Mastercard',
        MarcaTarjeta.amex => 'Amex',
        MarcaTarjeta.desconocida => 'Tarjeta',
      };

  static int longitudNumero(MarcaTarjeta m) => m == MarcaTarjeta.amex ? 15 : 16;
  static int longitudCvv(MarcaTarjeta m) => m == MarcaTarjeta.amex ? 4 : 3;

  /// Algoritmo de Luhn.
  static bool luhn(String numero) {
    final n = soloDigitos(numero);
    if (n.length < 12) return false;
    var suma = 0;
    var doble = false;
    for (var i = n.length - 1; i >= 0; i--) {
      var d = n.codeUnitAt(i) - 48;
      if (doble) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      suma += d;
      doble = !doble;
    }
    return suma % 10 == 0;
  }

  /// "MM/AA" vigente (válida hasta el último día del mes).
  static bool vigenciaValida(String mmaa, {DateTime? hoy}) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(mmaa);
    if (m == null) return false;
    final mes = int.parse(m.group(1)!);
    final anio = 2000 + int.parse(m.group(2)!);
    if (mes < 1 || mes > 12) return false;
    final ahora = hoy ?? DateTime.now();
    final finDeMes = DateTime(anio, mes + 1, 1);
    return ahora.isBefore(finDeMes);
  }

  static String referencia(String prefijo) {
    final r = Random.secure();
    final n = List.generate(10, (_) => r.nextInt(10)).join();
    return '$prefijo-$n';
  }
}

/// "4242424242424242" → "4242 4242 4242 4242"
class FormatoNumeroTarjeta extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = PagoUtils.soloDigitos(newValue.text);
    final max = PagoUtils.longitudNumero(PagoUtils.marca(d));
    if (d.length > max) d = d.substring(0, max);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(d[i]);
    }
    final t = b.toString();
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// "1228" → "12/28"
class FormatoVigencia extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = PagoUtils.soloDigitos(newValue.text);
    if (d.length > 4) d = d.substring(0, 4);
    final borrando = newValue.text.length < oldValue.text.length;
    String t;
    if (d.length >= 3) {
      t = '${d.substring(0, 2)}/${d.substring(2)}';
    } else if (d.length == 2 && !borrando) {
      t = '$d/';
    } else {
      t = d;
    }
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
