import 'package:flutter/material.dart';

import '../services/preferencias_service.dart';

class ColorAcento {
  final String id;
  final String nombre;
  final Color color;
  const ColorAcento(this.id, this.nombre, this.color);
}

/// Estilo de fondo para un modo (claro u oscuro).
class FondoTema {
  final String id;
  final String nombre;
  final Color fondo; // fondo de las pantallas
  final Color superficie; // tarjetas, campos, barra inferior
  final Color borde; // bordes de campos
  final bool oscuro;
  const FondoTema(this.id, this.nombre, this.fondo, this.superficie, this.borde,
      {required this.oscuro});
}

/// Tema prediseñado: combina acento, fondos y modo.
class TemaPreset {
  final String id;
  final String nombre;
  final String descripcion;
  final String acentoId;
  final String claroId;
  final String oscuroId;
  final ThemeMode modo;
  const TemaPreset(this.id, this.nombre, this.descripcion, this.acentoId,
      this.claroId, this.oscuroId, this.modo);
}

/// Tema de la app: color de acento, fondo para modo claro, fondo para modo
/// oscuro y modo (claro / oscuro / sistema). Mantiene el estilo de la versión
/// anterior: AppBar sólido, tarjetas elevadas y encabezados con degradado.
class AppTheme {
  AppTheme._();

  static const acentos = <ColorAcento>[
    ColorAcento('oceano', 'Océano', Color(0xFF0284C7)),
    ColorAcento('indigo', 'Índigo', Color(0xFF4F46E5)),
    ColorAcento('purpura', 'Púrpura', Color(0xFF8B5CF6)),
    ColorAcento('rosa', 'Rosa', Color(0xFFDB2777)),
    ColorAcento('rubi', 'Rubí', Color(0xFFE11D48)),
    ColorAcento('coral', 'Coral', Color(0xFFF2694F)),
    ColorAcento('ambar', 'Ámbar', Color(0xFFF59E0B)),
    ColorAcento('esmeralda', 'Esmeralda', Color(0xFF10B981)),
    ColorAcento('turquesa', 'Turquesa', Color(0xFF0D9488)),
    ColorAcento('grafito', 'Grafito', Color(0xFF475569)),
  ];

  static const fondosClaros = <FondoTema>[
    FondoTema('nube', 'Nube', Color(0xFFF8FAFC), Colors.white, Color(0xFFCBD5E1),
        oscuro: false),
    FondoTema('crema', 'Crema', Color(0xFFFBF6EE), Color(0xFFFFFDF9), Color(0xFFE5D9C6),
        oscuro: false),
    FondoTema('lavanda', 'Lavanda', Color(0xFFF5F3FF), Colors.white, Color(0xFFD9D3F5),
        oscuro: false),
    FondoTema('menta', 'Menta', Color(0xFFF0FAF5), Colors.white, Color(0xFFC9E7D8),
        oscuro: false),
  ];

  static const fondosOscuros = <FondoTema>[
    FondoTema('pizarra', 'Pizarra', Color(0xFF0F172A), Color(0xFF1E293B),
        Color(0xFF334155),
        oscuro: true),
    FondoTema('amoled', 'AMOLED', Color(0xFF000000), Color(0xFF121212), Color(0xFF2A2A2A),
        oscuro: true),
    FondoTema('medianoche', 'Medianoche', Color(0xFF0B1026), Color(0xFF161E3F),
        Color(0xFF2A3566),
        oscuro: true),
    FondoTema('carbon', 'Carbón', Color(0xFF18181B), Color(0xFF27272A), Color(0xFF3F3F46),
        oscuro: true),
  ];

  static const presets = <TemaPreset>[
    TemaPreset('clasico', 'Clásico', 'Océano sobre fondo claro', 'oceano', 'nube',
        'pizarra', ThemeMode.light),
    TemaPreset('noche', 'Noche', 'Océano en modo oscuro', 'oceano', 'nube', 'pizarra',
        ThemeMode.dark),
    TemaPreset('amoled', 'AMOLED', 'Negro puro, ahorra batería', 'turquesa', 'nube',
        'amoled', ThemeMode.dark),
    TemaPreset('galaxia', 'Galaxia', 'Púrpura y azul medianoche', 'purpura', 'lavanda',
        'medianoche', ThemeMode.dark),
    TemaPreset('bosque', 'Bosque', 'Esmeralda con fondo menta', 'esmeralda', 'menta',
        'carbon', ThemeMode.light),
    TemaPreset('atardecer', 'Atardecer', 'Coral con fondo crema', 'coral', 'crema',
        'carbon', ThemeMode.light),
    TemaPreset('elegante', 'Elegante', 'Rubí sobre negro', 'rubi', 'crema', 'amoled',
        ThemeMode.dark),
    TemaPreset('auto', 'Automático', 'Índigo, sigue al sistema', 'indigo', 'nube',
        'medianoche', ThemeMode.system),
  ];

  static ColorAcento _acento = acentos.first;
  static FondoTema _claro = fondosClaros.first;
  static FondoTema _oscuro = fondosOscuros.first;

  static ColorAcento get acentoActual => _acento;
  static FondoTema get fondoClaroActual => _claro;
  static FondoTema get fondoOscuroActual => _oscuro;

  /// Color de acento (equivale a 0xFF0284C7 en Océano).
  static Color get acento => _acento.color;

  /// Tono claro del acento para el final de los degradados (≈ 0xFF38BDF8).
  static Color get acentoClaro => Color.lerp(_acento.color, Colors.white, 0.3)!;

  static LinearGradient get degradado => degradadoDe(acento);

  static LinearGradient degradadoDe(Color c) => LinearGradient(
        colors: [c, Color.lerp(c, Colors.white, 0.3)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Colores de estado
  static const Color exito = Color(0xFF16A34A);
  static const Color advertencia = Color(0xFFEA580C);
  static const Color error = Colors.redAccent;

  static ColorAcento buscarAcento(String id) =>
      acentos.firstWhere((a) => a.id == id, orElse: () => acentos.first);
  static FondoTema buscarClaro(String id) =>
      fondosClaros.firstWhere((f) => f.id == id, orElse: () => fondosClaros.first);
  static FondoTema buscarOscuro(String id) =>
      fondosOscuros.firstWhere((f) => f.id == id, orElse: () => fondosOscuros.first);

  static void usarAcento(String id) => _acento = buscarAcento(id);
  static void usarFondoClaro(String id) => _claro = buscarClaro(id);
  static void usarFondoOscuro(String id) => _oscuro = buscarOscuro(id);

  /// Color por rol, como en la lista de usuarios anterior.
  static Color colorRol(String rol) {
    switch (rol) {
      case 'admin':
        return Colors.red.shade700;
      case 'editor':
        return Colors.orange.shade800;
      default:
        return const Color(0xFF0284C7);
    }
  }

  static IconData iconoRol(String rol) {
    switch (rol) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'editor':
        return Icons.edit_note;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  static ThemeData tema(Brightness brillo) {
    final f = brillo == Brightness.dark ? _oscuro : _claro;
    final oscuro = f.oscuro;
    final acento = AppTheme.acento;
    final esquema = ColorScheme.fromSeed(
      seedColor: acento,
      brightness: brillo,
      surface: f.superficie,
    );
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: f.borde),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: f.fondo,
      canvasColor: f.fondo,
      appBarTheme: AppBarTheme(
        backgroundColor: oscuro ? f.superficie : acento,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: acento,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: oscuro ? 0 : 2,
        color: f.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: oscuro ? BorderSide(color: f.borde) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: f.superficie,
        border: borde,
        enabledBorder: borde,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: acento, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: f.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: f.superficie,
        modalBackgroundColor: f.superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: f.superficie),
      dividerTheme: DividerThemeData(color: f.borde.withValues(alpha: 0.6)),
    );
  }
}

/// Modo, acento, fondos y tamaño de texto, con persistencia.
class TemaController extends ChangeNotifier {
  TemaController() {
    final prefs = PreferenciasService.instance;
    AppTheme.usarAcento(prefs.acento);
    AppTheme.usarFondoClaro(prefs.fondoClaro);
    AppTheme.usarFondoOscuro(prefs.fondoOscuro);
    _modo = _modoDesdeTexto(prefs.modoTema);
    _escala = prefs.escalaTexto;
  }

  ThemeMode _modo = ThemeMode.light;
  double _escala = 1.0;

  ThemeMode get modo => _modo;
  double get escalaTexto => _escala;
  String get acentoId => AppTheme.acentoActual.id;
  String get fondoClaroId => AppTheme.fondoClaroActual.id;
  String get fondoOscuroId => AppTheme.fondoOscuroActual.id;

  static ThemeMode _modoDesdeTexto(String t) => switch (t) {
        'oscuro' => ThemeMode.dark,
        'sistema' => ThemeMode.system,
        _ => ThemeMode.light,
      };

  static String _modoATexto(ThemeMode m) => switch (m) {
        ThemeMode.dark => 'oscuro',
        ThemeMode.system => 'sistema',
        ThemeMode.light => 'claro',
      };

  /// ¿Está aplicado este tema prediseñado?
  bool esPreset(TemaPreset p) =>
      p.acentoId == acentoId &&
      p.claroId == fondoClaroId &&
      p.oscuroId == fondoOscuroId &&
      p.modo == _modo;

  Future<void> cambiarModo(ThemeMode m) async {
    _modo = m;
    await PreferenciasService.instance.setModoTema(_modoATexto(m));
    notifyListeners();
  }

  /// Alterna entre claro y oscuro según cómo se ve la app ahora mismo.
  Future<void> alternarClaroOscuro(Brightness actual) =>
      cambiarModo(actual == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> cambiarAcento(String id) async {
    AppTheme.usarAcento(id);
    await PreferenciasService.instance.setAcento(id);
    _avisar();
  }

  Future<void> cambiarFondoClaro(String id) async {
    AppTheme.usarFondoClaro(id);
    await PreferenciasService.instance.setFondoClaro(id);
    _avisar();
  }

  Future<void> cambiarFondoOscuro(String id) async {
    AppTheme.usarFondoOscuro(id);
    await PreferenciasService.instance.setFondoOscuro(id);
    _avisar();
  }

  Future<void> aplicarPreset(TemaPreset p) async {
    final prefs = PreferenciasService.instance;
    AppTheme.usarAcento(p.acentoId);
    AppTheme.usarFondoClaro(p.claroId);
    AppTheme.usarFondoOscuro(p.oscuroId);
    _modo = p.modo;
    await prefs.setAcento(p.acentoId);
    await prefs.setFondoClaro(p.claroId);
    await prefs.setFondoOscuro(p.oscuroId);
    await prefs.setModoTema(_modoATexto(p.modo));
    _avisar();
  }

  Future<void> cambiarEscala(double v) async {
    _escala = v.clamp(0.85, 1.30).toDouble();
    await PreferenciasService.instance.setEscalaTexto(_escala);
    notifyListeners();
  }

  void _avisar() {
    notifyListeners();
    // Los degradados leen AppTheme directamente: forzamos reconstruir todo.
    WidgetsBinding.instance.addPostFrameCallback((_) => reconstruirTodo());
  }

  static void reconstruirTodo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(marcar);
  }
}
