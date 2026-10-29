import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ResultadoGoogle {
  final String? email;
  final String? nombre;
  final String? error;
  const ResultadoGoogle({this.email, this.nombre, this.error});
  bool get cancelado => email == null && error == null;
}

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _google = GoogleSignIn(scopes: const ['email']);

  Future<ResultadoGoogle> iniciar() async {
    try {
      final cuenta = await _google.signIn();
      if (cuenta == null) return const ResultadoGoogle(); // canceló
      return ResultadoGoogle(email: cuenta.email, nombre: cuenta.displayName);
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In: ${e.code} ${e.message}');
      final msg = '${e.code} ${e.message}';
      if (msg.contains('10') || msg.contains('DEVELOPER_ERROR') ||
          e.code == 'sign_in_failed') {
        return const ResultadoGoogle(
          error: 'Google Sign-In no está configurado: registra el SHA-1 de '
              'tu app (cd android && gradlew signingReport) en Firebase o '
              'Google Cloud y vuelve a intentarlo.',
        );
      }
      if (e.code == 'network_error') {
        return const ResultadoGoogle(error: 'Sin conexión a internet.');
      }
      return ResultadoGoogle(error: 'No se pudo iniciar con Google (${e.code}).');
    } catch (e) {
      return ResultadoGoogle(error: 'No se pudo iniciar con Google: $e');
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await _google.signOut();
    } catch (_) {}
  }
}
