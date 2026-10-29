import 'package:flutter_test/flutter_test.dart';
import 'package:app_tienda/services/otp_service.dart';
import 'package:app_tienda/services/pago_utils.dart';

void main() {
  group('OtpService', () {
    late DateTime ahora;
    late OtpService otp;

    setUp(() {
      ahora = DateTime(2026, 1, 1, 12);
      otp = OtpService(reloj: () => ahora);
    });

    test('genera códigos de 6 dígitos', () {
      for (var i = 0; i < 50; i++) {
        expect(otp.generarCodigo(), matches(RegExp(r'^\d{6}$')));
      }
    });

    test('solo guarda el hash SHA-256 (64 hex), nunca el código', () {
      final h = OtpService.hashCodigo('123456');
      expect(h, hasLength(64));
      expect(h, isNot(contains('123456')));
      expect(OtpService.hashCodigo('123456'), h);
    });

    test('un código válido se acepta una sola vez', () {
      final c = otp.crear('login:1', const Duration(minutes: 5));
      expect(otp.verificar('login:1', c).ok, isTrue);
      expect(otp.verificar('login:1', c).estado, EstadoOtp.inexistente);
    });

    test('código incorrecto descuenta intentos y bloquea al tercero', () {
      final c = otp.crear('login:2', const Duration(minutes: 5));
      final malo = c == '000000' ? '111111' : '000000';
      final r1 = otp.verificar('login:2', malo);
      expect(r1.estado, EstadoOtp.incorrecto);
      expect(r1.intentosRestantes, 2);
      final r2 = otp.verificar('login:2', malo);
      expect(r2.intentosRestantes, 1);
      final r3 = otp.verificar('login:2', malo);
      expect(r3.estado, EstadoOtp.sinIntentos);
      // Ni el correcto sirve ya.
      expect(otp.verificar('login:2', c).ok, isFalse);
    });

    test('el código expira según la vigencia', () {
      final c = otp.crear('login:3', const Duration(minutes: 3));
      expect(otp.restante('login:3'), const Duration(minutes: 3));
      ahora = ahora.add(const Duration(minutes: 3, seconds: 1));
      expect(otp.restante('login:3'), Duration.zero);
      expect(otp.verificar('login:3', c).estado, EstadoOtp.expirado);
    });

    test('reenvío disponible a los 30 s', () {
      otp.crear('login:4', const Duration(minutes: 5));
      expect(otp.segundosParaReenvio('login:4'), 30);
      ahora = ahora.add(const Duration(seconds: 31));
      expect(otp.segundosParaReenvio('login:4'), 0);
    });

    test('un código nuevo reemplaza al anterior', () {
      final viejo = otp.crear('rec:1', const Duration(minutes: 5));
      final nuevo = otp.crear('rec:1', const Duration(minutes: 5));
      if (viejo != nuevo) {
        expect(otp.verificar('rec:1', viejo).ok, isFalse);
      }
      expect(otp.verificar('rec:1', nuevo).ok, isTrue);
    });
  });

  group('PagoUtils', () {
    test('Luhn y marcas de prueba', () {
      expect(PagoUtils.luhn('4242 4242 4242 4242'), isTrue);
      expect(PagoUtils.luhn('4000 0000 0000 0002'), isTrue);
      expect(PagoUtils.luhn('4242 4242 4242 4241'), isFalse);
      expect(PagoUtils.marca('4242'), MarcaTarjeta.visa);
      expect(PagoUtils.marca('5555 5555 5555 4444'), MarcaTarjeta.mastercard);
      expect(PagoUtils.marca('3782 822463 10005'), MarcaTarjeta.amex);
      expect(PagoUtils.longitudCvv(MarcaTarjeta.amex), 4);
    });

    test('vigencia MM/AA', () {
      final hoy = DateTime(2026, 10, 2);
      expect(PagoUtils.vigenciaValida('10/26', hoy: hoy), isTrue);
      expect(PagoUtils.vigenciaValida('09/26', hoy: hoy), isFalse);
      expect(PagoUtils.vigenciaValida('13/30', hoy: hoy), isFalse);
    });
  });
}
