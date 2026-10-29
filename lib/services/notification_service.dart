import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notificacion.dart';
import '../repository/notificacion_repository.dart';
import 'preferencias_service.dart';

/// Notificaciones del sistema + bandeja interna en SQLite.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _repo = NotificacionRepository.instance;

  /// Contador de no leídas para la campana.
  final ValueNotifier<int> noLeidas = ValueNotifier<int>(0);

  /// Usuario con sesión activa (para filtrar la bandeja).
  int? usuarioActualId;

  bool _listo = false;
  int _siguienteId = 1;

  static const _canales = {
    TipoNotificacion.seguridad: (
      'Seguridad',
      'Inicios de sesión, bloqueos y cambios de cuenta'
    ),
    TipoNotificacion.compras: ('Compras', 'Confirmaciones de pedidos'),
    TipoNotificacion.promociones: ('Promociones', 'Ofertas y recomendaciones'),
    TipoNotificacion.sistema: ('Sistema', 'Avisos generales de la app'),
  };

  Future<void> inicializar() async {
    if (_listo) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);

      if (!kIsWeb && Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        for (final e in _canales.entries) {
          await android?.createNotificationChannel(AndroidNotificationChannel(
            e.key,
            e.value.$1,
            description: e.value.$2,
            importance: e.key == TipoNotificacion.promociones
                ? Importance.defaultImportance
                : Importance.high,
          ));
        }
        // Android 13+ pide permiso explícito.
        await android?.requestNotificationsPermission();
      } else if (!kIsWeb && Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      _listo = true;
    } catch (e) {
      debugPrint('[Notificaciones] No se pudieron inicializar: $e');
    }
  }

  /// Muestra la notificación del sistema y la guarda en la bandeja.
  Future<void> notificar({
    required String titulo,
    required String cuerpo,
    String tipo = TipoNotificacion.sistema,
    int? usuarioId,
    bool general = false, // true = visible para todos los usuarios
    bool guardar = true,
  }) async {
    final destino = general ? null : (usuarioId ?? usuarioActualId);
    if (guardar) {
      await _repo.insertar(Notificacion(
        usuarioId: destino,
        titulo: titulo,
        cuerpo: cuerpo,
        tipo: tipo,
        fecha: DateTime.now(),
      ));
      await refrescarContador();
    }
    // Solo mostramos en el sistema si el usuario no desactivó ese tipo
    // y si la notificación es para quien tiene la sesión (o no hay sesión).
    final esParaEsteDispositivo =
        destino == null || usuarioActualId == null || destino == usuarioActualId;
    if (PreferenciasService.instance.notificacionActiva(tipo) &&
        esParaEsteDispositivo) {
      await mostrarSistema(titulo, cuerpo, tipo: tipo);
    }
  }

  /// Solo notificación del sistema (no se guarda). Se usa p. ej. para el SMS de demo.
  Future<void> mostrarSistema(String titulo, String cuerpo,
      {String tipo = TipoNotificacion.sistema}) async {
    if (!_listo) return;
    try {
      final canal = _canales[tipo] ?? _canales[TipoNotificacion.sistema]!;
      await _plugin.show(
        _siguienteId++,
        titulo,
        cuerpo,
        NotificationDetails(
          android: AndroidNotificationDetails(
            tipo,
            canal.$1,
            channelDescription: canal.$2,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(cuerpo),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[Notificaciones] Error al mostrar: $e');
    }
  }

  Future<void> refrescarContador() async {
    noLeidas.value = await _repo.noLeidas(usuarioActualId);
  }

  Future<List<Notificacion>> bandeja() => _repo.deUsuario(usuarioActualId);

  Future<void> marcarTodasLeidas() async {
    await _repo.marcarLeidas(usuarioActualId);
    await refrescarContador();
  }

  Future<void> marcarLeida(int id) async {
    await _repo.marcarLeida(id);
    await refrescarContador();
  }

  Future<void> eliminar(int id) async {
    await _repo.eliminar(id);
    await refrescarContador();
  }

  Future<void> borrarTodas() async {
    await _repo.borrarTodas(usuarioActualId);
    await refrescarContador();
  }

  static IconData icono(String tipo) {
    switch (tipo) {
      case TipoNotificacion.seguridad:
        return Icons.shield_outlined;
      case TipoNotificacion.compras:
        return Icons.shopping_bag_outlined;
      case TipoNotificacion.promociones:
        return Icons.local_offer_outlined;
      default:
        return Icons.info_outline;
    }
  }

  static Color color(String tipo) {
    switch (tipo) {
      case TipoNotificacion.seguridad:
        return const Color(0xFFE57373);
      case TipoNotificacion.compras:
        return const Color(0xFF66BB6A);
      case TipoNotificacion.promociones:
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF64B5F6);
    }
  }
}
