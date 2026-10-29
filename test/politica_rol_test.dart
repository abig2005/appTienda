import 'package:flutter_test/flutter_test.dart';
import 'package:app_tienda/services/politica_rol.dart';

void main() {
  group('PoliticaRol', () {
    test('de() devuelve la política correcta y lector por defecto', () {
      expect(PoliticaRol.de('admin'), same(PoliticaRol.admin));
      expect(PoliticaRol.de('editor'), same(PoliticaRol.editor));
      expect(PoliticaRol.de('lector'), same(PoliticaRol.lector));
      expect(PoliticaRol.de('desconocido'), same(PoliticaRol.lector));
    });

    test('admin: 10+, mayúscula, número y símbolo', () {
      final p = PoliticaRol.admin;
      expect(p.esValida('Admin1234!'), isTrue);
      expect(p.esValida('Admin123!'), isFalse, reason: 'solo 9 caracteres');
      expect(p.esValida('admin1234!'), isFalse, reason: 'sin mayúscula');
      expect(p.esValida('Administra!'), isFalse, reason: 'sin número');
      expect(p.esValida('Admin12345'), isFalse, reason: 'sin símbolo');
    });

    test('editor: 8+, mayúscula y número (símbolo opcional)', () {
      final p = PoliticaRol.editor;
      expect(p.esValida('Editor12'), isTrue);
      expect(p.esValida('editor12'), isFalse);
      expect(p.esValida('Editorrr'), isFalse);
      expect(p.esValida('Edit12'), isFalse);
    });

    test('lector: 8+, letra y número', () {
      final p = PoliticaRol.lector;
      expect(p.esValida('password123'), isTrue);
      expect(p.esValida('12345678'), isFalse, reason: 'sin letra');
      expect(p.esValida('password'), isFalse, reason: 'sin número');
      expect(p.esValida('pass12'), isFalse, reason: 'muy corta');
    });

    test('más privilegios = reglas más estrictas', () {
      expect(PoliticaRol.admin.maxIntentos, 3);
      expect(PoliticaRol.editor.maxIntentos, 5);
      expect(PoliticaRol.lector.maxIntentos, 5);

      expect(PoliticaRol.admin.duracionBloqueo, const Duration(minutes: 15));
      expect(PoliticaRol.editor.duracionBloqueo, const Duration(minutes: 10));
      expect(PoliticaRol.lector.duracionBloqueo, const Duration(minutes: 5));

      expect(PoliticaRol.admin.vigenciaOtp, const Duration(minutes: 3));
      expect(PoliticaRol.editor.vigenciaOtp, const Duration(minutes: 5));
      expect(PoliticaRol.lector.vigenciaOtp, const Duration(minutes: 5));

      expect(PoliticaRol.admin.vigenciaRecuperacion, const Duration(minutes: 5));
      expect(PoliticaRol.editor.vigenciaRecuperacion, const Duration(minutes: 10));
      expect(PoliticaRol.lector.vigenciaRecuperacion, const Duration(minutes: 15));
    });

    test('faltantes() lista lo que no se cumple', () {
      final f = PoliticaRol.admin.faltantes('abc');
      expect(f, contains('Al menos 10 caracteres'));
      expect(f, contains('Al menos una mayúscula'));
      expect(f, contains('Al menos un número'));
      expect(f.any((e) => e.startsWith('Al menos un símbolo')), isTrue);
      expect(PoliticaRol.admin.faltantes('Admin1234!'), isEmpty);
    });

    test('la contraseña demo cumple la política de lector', () {
      expect(PoliticaRol.lector.esValida('password123'), isTrue);
    });
  });
}
