/// Nombre de una persona separado en nombres, apellido paterno y materno.
class NombrePersona {
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;

  const NombrePersona({
    required this.nombres,
    required this.apellidoPaterno,
    this.apellidoMaterno = '',
  });

  /// "Juan Carlos Pérez Gómez"
  String get completo => unir(nombres, apellidoPaterno, apellidoMaterno);

  static String unir(String nombres, String paterno, String materno) => [
        nombres,
        paterno,
        materno,
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');

  /// Separa un nombre completo guardado en un solo campo (datos anteriores
  /// o el nombre de Google). Con 3+ palabras toma las dos últimas como
  /// apellidos; con 2, la última como apellido paterno.
  factory NombrePersona.desdeCompleto(String completo) {
    final p = completo.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return const NombrePersona(nombres: '', apellidoPaterno: '');
    if (p.length == 1) return NombrePersona(nombres: p[0], apellidoPaterno: '');
    if (p.length == 2) return NombrePersona(nombres: p[0], apellidoPaterno: p[1]);
    return NombrePersona(
      nombres: p.sublist(0, p.length - 2).join(' '),
      apellidoPaterno: p[p.length - 2],
      apellidoMaterno: p.last,
    );
  }

  /// "jUAN  carlos" → "Juan Carlos" (respeta partículas como "de", "del", "la").
  static String capitalizar(String texto) {
    const particulas = {'de', 'del', 'la', 'las', 'los', 'y', 'van', 'von'};
    final palabras = texto.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return [
      for (var i = 0; i < palabras.length; i++)
        (i > 0 && particulas.contains(palabras[i].toLowerCase()))
            ? palabras[i].toLowerCase()
            : palabras[i][0].toUpperCase() + palabras[i].substring(1).toLowerCase(),
    ].join(' ');
  }

  static final _valido = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' .\-]+$");

  /// Valida un campo de nombre. [requerido] = false para el apellido materno.
  static String? validar(String? valor, String campo, {bool requerido = true}) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return requerido ? 'Escribe tu $campo' : null;
    if (v.length < 2) return 'El $campo es muy corto';
    if (v.length > 40) return 'El $campo es muy largo';
    if (!_valido.hasMatch(v)) return 'El $campo solo puede tener letras';
    return null;
  }
}
