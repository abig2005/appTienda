import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../repository/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/notification_service.dart';

/// Usuario con sesión activa.
class SesionController extends ChangeNotifier {
  Usuario? _usuario;
  String? _metodo;

  Usuario? get usuario => _usuario;
  String? get metodo => _metodo;
  bool get activa => _usuario != null;

  Future<void> iniciar(Usuario u, String metodo) async {
    _usuario = u;
    _metodo = metodo;
    NotificationService.instance.usuarioActualId = u.id;
    await AuthService.instance.registrarInicioSesion(u, metodo);
    await NotificationService.instance.refrescarContador();
    notifyListeners();
  }

  /// Vuelve a leer al usuario desde la BD (tras editar perfil, etc.).
  Future<void> refrescar() async {
    if (_usuario?.id == null) return;
    final u = await UsuarioRepository.instance.porId(_usuario!.id!);
    if (u != null) {
      _usuario = u;
      notifyListeners();
    }
  }

  Future<void> cerrar() async {
    if (_usuario?.proveedor == 'google' || _metodo == 'Google') {
      await GoogleAuthService.instance.cerrarSesion();
    }
    _usuario = null;
    _metodo = null;
    NotificationService.instance.usuarioActualId = null;
    NotificationService.instance.noLeidas.value = 0;
    notifyListeners();
  }
}
