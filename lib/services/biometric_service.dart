import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Huella, rostro o PIN del dispositivo.
/// En Android, MainActivity debe extender FlutterFragmentActivity.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> disponible() async {
    if (kIsWeb) return false;
    try {
      final soportado = await _auth.isDeviceSupported();
      final puede = await _auth.canCheckBiometrics;
      return soportado || puede;
    } catch (_) {
      return false;
    }
  }

  /// Devuelve null si se autenticó; si no, un mensaje de error.
  Future<String?> autenticar(
      {String motivo = 'Confirma tu identidad para entrar'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN/patrón como respaldo
          stickyAuth: true,
        ),
      );
      return ok ? null : 'Autenticación cancelada.';
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
          return 'Este dispositivo no tiene huella, rostro ni PIN configurado.';
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return 'Demasiados intentos. Desbloquea tu dispositivo e inténtalo de nuevo.';
        case 'no_fragment_activity':
          return 'Configuración incompleta: MainActivity debe extender FlutterFragmentActivity.';
        default:
          return 'No se pudo usar la biometría (${e.code}).';
      }
    } catch (e) {
      return 'No se pudo usar la biometría.';
    }
  }
}
