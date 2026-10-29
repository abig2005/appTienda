import 'package:flutter_test/flutter_test.dart';
import 'package:app_tienda/models/nombre_persona.dart';

void main() {
  group('NombrePersona', () {
    test('une las partes y omite el apellido materno vacío', () {
      expect(NombrePersona.unir('Juan Carlos', 'Pérez', 'Gómez'), 'Juan Carlos Pérez Gómez');
      expect(NombrePersona.unir('Ana', 'García', ''), 'Ana García');
    });

    test('separa nombres completos guardados antes de la versión 5', () {
      final a = NombrePersona.desdeCompleto('Juan Carlos Pérez Gómez');
      expect(a.nombres, 'Juan Carlos');
      expect(a.apellidoPaterno, 'Pérez');
      expect(a.apellidoMaterno, 'Gómez');

      final b = NombrePersona.desdeCompleto('Ana García');
      expect(b.nombres, 'Ana');
      expect(b.apellidoPaterno, 'García');
      expect(b.apellidoMaterno, '');

      final c = NombrePersona.desdeCompleto('  Pedro  ');
      expect(c.nombres, 'Pedro');
      expect(c.apellidoPaterno, '');
    });

    test('capitaliza respetando partículas', () {
      expect(NombrePersona.capitalizar('jUAN  carlos'), 'Juan Carlos');
      expect(NombrePersona.capitalizar('DE LA FUENTE'), 'De la Fuente');
      expect(NombrePersona.capitalizar('maría josé'), 'María José');
    });

    test('valida campos requeridos y opcionales', () {
      expect(NombrePersona.validar('', 'nombre'), isNotNull);
      expect(NombrePersona.validar('', 'apellido materno', requerido: false), isNull);
      expect(NombrePersona.validar('J', 'nombre'), isNotNull);
      expect(NombrePersona.validar('Juan3', 'nombre'), isNotNull);
      expect(NombrePersona.validar('Núñez', 'apellido paterno'), isNull);
      expect(NombrePersona.validar("O'Connor", 'apellido paterno'), isNull);
    });
  });
}
