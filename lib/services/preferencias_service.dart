import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales (no sensibles).
class PreferenciasService {
  PreferenciasService._();
  static final PreferenciasService instance = PreferenciasService._();

  late SharedPreferences _p;

  Future<void> inicializar() async {
    _p = await SharedPreferences.getInstance();
  }

  // Apariencia
  String get acento => _p.getString('acento') ?? 'oceano';
  Future<void> setAcento(String v) => _p.setString('acento', v);

  String get fondoClaro => _p.getString('fondo_claro') ?? 'nube';
  Future<void> setFondoClaro(String v) => _p.setString('fondo_claro', v);

  String get fondoOscuro => _p.getString('fondo_oscuro') ?? 'pizarra';
  Future<void> setFondoOscuro(String v) => _p.setString('fondo_oscuro', v);

  /// claro | oscuro | sistema
  String get modoTema => _p.getString('modo_tema') ?? 'claro';
  Future<void> setModoTema(String v) => _p.setString('modo_tema', v);

  double get escalaTexto => _p.getDouble('escala_texto') ?? 1.0;
  Future<void> setEscalaTexto(double v) => _p.setDouble('escala_texto', v);

  // Notificaciones por tipo
  bool notificacionActiva(String tipo) => _p.getBool('notif_$tipo') ?? true;
  Future<void> setNotificacionActiva(String tipo, bool v) =>
      _p.setBool('notif_$tipo', v);

  // Biometría: usuario que puede entrar con huella en este dispositivo
  int? get biometriaUsuarioId => _p.getInt('bio_usuario_id');
  Future<void> setBiometriaUsuarioId(int? id) async {
    if (id == null) {
      await _p.remove('bio_usuario_id');
    } else {
      await _p.setInt('bio_usuario_id', id);
    }
  }

  bool biometriaOfrecida(int usuarioId) =>
      _p.getBool('bio_ofrecida_$usuarioId') ?? false;
  Future<void> setBiometriaOfrecida(int usuarioId) =>
      _p.setBool('bio_ofrecida_$usuarioId', true);

  // Canal 2FA preferido: correo | sms
  String canal2fa(int usuarioId) => _p.getString('canal2fa_$usuarioId') ?? 'correo';
  Future<void> setCanal2fa(int usuarioId, String canal) =>
      _p.setString('canal2fa_$usuarioId', canal);

  // Catálogo offline
  DateTime? get catalogoActualizado {
    final ms = _p.getInt('catalogo_actualizado');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setCatalogoActualizado(DateTime f) =>
      _p.setInt('catalogo_actualizado', f.millisecondsSinceEpoch);

  // Promoción del día
  String? ultimaPromo(int usuarioId) => _p.getString('promo_$usuarioId');
  Future<void> setUltimaPromo(int usuarioId, String fecha) =>
      _p.setString('promo_$usuarioId', fecha);
}
