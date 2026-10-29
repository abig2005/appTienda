import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hash de contraseñas (PBKDF2-HMAC-SHA256) y cifrado AES-256-GCM.
class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  static const int iteraciones = 12000;
  // Nombre interno de la clave: no cambiarlo o se pierden los datos ya cifrados.
  static const String _claveAes = 'mi_tiendita_aes_key_v1';
  static const String _prefijoCifrado = 'enc:v1:';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  enc.Key? _key;

  // ---------------------------------------------------------------------------
  // Contraseñas
  // ---------------------------------------------------------------------------

  /// Devuelve `pbkdf2$iter$sal$hash` (base64). Se calcula en otro isolate.
  Future<String> hashPassword(String password) async {
    final sal = _bytesAleatorios(16);
    final hash = await compute(_pbkdf2Isolate, <String, dynamic>{
      'p': password,
      's': sal,
      'i': iteraciones,
    });
    return 'pbkdf2\$$iteraciones\$${base64Encode(sal)}\$${base64Encode(hash)}';
  }

  /// Verifica en tiempo constante. Acepta hashes antiguos en texto plano
  /// solo para la migración (devuelve true si coinciden exactamente).
  Future<bool> verificarPassword(String password, String almacenado) async {
    if (!esHash(almacenado)) {
      return _igualesTexto(password, almacenado);
    }
    final partes = almacenado.split('\$');
    if (partes.length != 4) return false;
    final iter = int.tryParse(partes[1]) ?? iteraciones;
    final sal = base64Decode(partes[2]);
    final esperado = base64Decode(partes[3]);
    final calculado = await compute(_pbkdf2Isolate, <String, dynamic>{
      'p': password,
      's': sal,
      'i': iter,
    });
    return igualesBytes(esperado, calculado);
  }

  static bool esHash(String valor) => valor.startsWith('pbkdf2\$');

  static Uint8List _pbkdf2Isolate(Map<String, dynamic> a) => pbkdf2(
        a['p'] as String,
        a['s'] as List<int>,
        a['i'] as int,
        32,
      );

  /// PBKDF2-HMAC-SHA256 (RFC 8018).
  static Uint8List pbkdf2(
      String password, List<int> sal, int iter, int longitud) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final bloques = (longitud / 32).ceil();
    final salida = BytesBuilder();
    for (var b = 1; b <= bloques; b++) {
      final entrada = Uint8List(sal.length + 4)
        ..setAll(0, sal)
        ..buffer.asByteData().setUint32(sal.length, b);
      var u = hmac.convert(entrada).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iter; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      salida.add(t);
    }
    return Uint8List.fromList(salida.toBytes().sublist(0, longitud));
  }

  static bool igualesBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a[i] ^ b[i];
    }
    return r == 0;
  }

  static bool _igualesTexto(String a, String b) =>
      igualesBytes(utf8.encode(a), utf8.encode(b));

  // ---------------------------------------------------------------------------
  // Cifrado AES-256-GCM
  // ---------------------------------------------------------------------------

  Future<enc.Key> _obtenerClave() async {
    if (_key != null) return _key!;
    String? b64;
    try {
      b64 = await _secure.read(key: _claveAes);
      if (b64 == null) {
        b64 = base64Encode(_bytesAleatorios(32));
        await _secure.write(key: _claveAes, value: b64);
      }
    } catch (e) {
      // Si el Keystore falla (algunos emuladores), usamos shared_preferences.
      debugPrint('SecureStorage no disponible, usando respaldo: $e');
      final prefs = await SharedPreferences.getInstance();
      b64 = prefs.getString(_claveAes);
      if (b64 == null) {
        b64 = base64Encode(_bytesAleatorios(32));
        await prefs.setString(_claveAes, b64);
      }
    }
    _key = enc.Key.fromBase64(b64);
    return _key!;
  }

  /// Cifra y devuelve `enc:v1:<iv>:<datos>`.
  Future<String> cifrar(String texto) async {
    if (texto.isEmpty) return '';
    final key = await _obtenerClave();
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final datos = encrypter.encrypt(texto, iv: iv);
    return '$_prefijoCifrado${iv.base64}:${datos.base64}';
  }

  /// Descifra; si el valor no está cifrado lo devuelve tal cual.
  Future<String> descifrar(String? valor) async {
    if (valor == null || valor.isEmpty) return '';
    if (!valor.startsWith(_prefijoCifrado)) return valor;
    try {
      final resto = valor.substring(_prefijoCifrado.length);
      final i = resto.indexOf(':');
      final iv = enc.IV.fromBase64(resto.substring(0, i));
      final datos = resto.substring(i + 1);
      final key = await _obtenerClave();
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt64(datos, iv: iv);
    } catch (e) {
      debugPrint('No se pudo descifrar: $e');
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  static final Random _rnd = Random.secure();

  static Uint8List _bytesAleatorios(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _rnd.nextInt(256)));

  /// "ju***@gmail.com"
  static String enmascararCorreo(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final usuario = email.substring(0, at);
    final dominio = email.substring(at);
    final visibles = usuario.length <= 2 ? 1 : 2;
    return '${usuario.substring(0, visibles)}${'*' * (usuario.length - visibles).clamp(3, 8).toInt()}$dominio';
  }

  /// "•••• •• 4567"
  static String enmascararTelefono(String? tel) {
    final t = (tel ?? '').replaceAll(RegExp(r'\D'), '');
    if (t.length < 4) return t.isEmpty ? 'Sin teléfono' : '••••';
    return '•••• •• ${t.substring(t.length - 4)}';
  }
}
