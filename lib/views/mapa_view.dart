import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'home_view.dart';

class _Sucursal {
  final String nombre;
  final String horario;
  final LatLng punto;
  double distancia = 0;
  _Sucursal(this.nombre, this.horario, this.punto);
}

enum _EstadoUbicacion { cargando, ok, servicioApagado, denegado, denegadoSiempre, error }

class MapaView extends StatefulWidget {
  const MapaView({super.key});

  @override
  State<MapaView> createState() => _MapaViewState();
}

class _MapaViewState extends State<MapaView> {
  final _mapa = MapController();
  _EstadoUbicacion _estado = _EstadoUbicacion.cargando;
  LatLng? _yo;
  double _velocidad = 0; // m/s
  List<_Sucursal> _sucursales = [];

  // Seguimiento en tiempo real
  StreamSubscription<Position>? _sub;
  final List<LatLng> _recorrido = [];
  double _distancia = 0; // metros
  DateTime? _inicio;
  Timer? _reloj;
  bool _mapaListo = false;

  static const _respaldo = LatLng(19.4326, -99.1332); // CDMX

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reloj?.cancel();
    super.dispose();
  }

  Future<bool> _verificarPermisos() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _estado = _EstadoUbicacion.servicioApagado);
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      setState(() => _estado = _EstadoUbicacion.denegadoSiempre);
      return false;
    }
    if (p == LocationPermission.denied) {
      setState(() => _estado = _EstadoUbicacion.denegado);
      return false;
    }
    return true;
  }

  Future<void> _obtenerUbicacion() async {
    if (_estado != _EstadoUbicacion.cargando) {
      setState(() => _estado = _EstadoUbicacion.cargando);
    }
    try {
      if (!await _verificarPermisos()) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (!mounted) return;
      final yo = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _yo = yo;
        _estado = _EstadoUbicacion.ok;
        _sucursales = _generarSucursales(yo);
      });
      if (_mapaListo) _mapa.move(yo, 15);
    } catch (e) {
      if (mounted) setState(() => _estado = _EstadoUbicacion.error);
    }
  }

  /// Sucursales de ejemplo alrededor del usuario, ordenadas por distancia.
  List<_Sucursal> _generarSucursales(LatLng centro) {
    const datos = [
      ('App Tienda Centro', 'L-D 9:00–21:00', 0.006, 0.004),
      ('App Tienda Norte', 'L-S 10:00–20:00', 0.018, -0.006),
      ('App Tienda Plaza', 'L-D 11:00–22:00', -0.011, 0.014),
      ('App Tienda Sur', 'L-V 9:00–19:00', -0.021, -0.012),
      ('App Tienda Express', '24 horas', 0.003, -0.017),
    ];
    final lista = [
      for (final d in datos)
        _Sucursal(d.$1, d.$2,
            LatLng(centro.latitude + d.$3, centro.longitude + d.$4)),
    ];
    for (final s in lista) {
      s.distancia = Geolocator.distanceBetween(centro.latitude,
          centro.longitude, s.punto.latitude, s.punto.longitude);
    }
    lista.sort((a, b) => a.distancia.compareTo(b.distancia));
    return lista;
  }

  Future<void> _alternarSeguimiento() async {
    if (_sub != null) {
      await _sub!.cancel();
      _reloj?.cancel();
      setState(() {
        _sub = null;
        _reloj = null;
      });
      if (mounted) {
        mostrarMensaje(context,
            'Recorrido terminado: ${_formatoDistancia(_distancia)} en ${_formatoTiempo()}');
      }
      return;
    }
    if (!await _verificarPermisos()) return;
    setState(() {
      _recorrido.clear();
      if (_yo != null) _recorrido.add(_yo!);
      _distancia = 0;
      _inicio = DateTime.now();
    });
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        if (_recorrido.isNotEmpty) {
          final u = _recorrido.last;
          _distancia += Geolocator.distanceBetween(
              u.latitude, u.longitude, p.latitude, p.longitude);
        }
        _recorrido.add(p);
        _yo = p;
        _velocidad = pos.speed < 0 ? 0 : pos.speed;
      });
      if (_mapaListo) _mapa.move(p, _mapa.camera.zoom);
    }, onError: (_) {
      if (mounted) mostrarMensaje(context, 'Se perdió la señal de ubicación', error: true);
    });
    setState(() {});
  }

  String _formatoDistancia(double m) =>
      m < 1000 ? '${m.toStringAsFixed(0)} m' : '${(m / 1000).toStringAsFixed(2)} km';

  String _formatoTiempo() {
    if (_inicio == null) return '00:00';
    final d = DateTime.now().difference(_inicio!);
    final h = d.inHours;
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Future<void> _comoLlegar(_Sucursal s) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${s.punto.latitude},${s.punto.longitude}&travelmode=walking');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      mostrarMensaje(context, 'No se pudo abrir Google Maps', error: true);
    }
  }

  Future<void> _compartirUbicacion() async {
    final yo = _yo;
    if (yo == null) return;
    final lat = yo.latitude.toStringAsFixed(6);
    final lng = yo.longitude.toStringAsFixed(6);
    await SharePlus.instance.share(ShareParams(
      subject: 'Mi ubicación',
      text: 'Estoy aquí 📍 https://www.google.com/maps?q=$lat,$lng\n— Enviado desde ${AppConfig.appName}',
    ));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geolocalización & Sucursales'),
        actions: accionesAppBar(context, extra: [
          IconButton(
            tooltip: 'Compartir mi ubicación',
            onPressed: _yo == null ? null : _compartirUbicacion,
            icon: const Icon(Icons.share_location_outlined),
          ),
        ]),
      ),
      body: switch (_estado) {
        _EstadoUbicacion.cargando when _yo == null => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Obteniendo tu ubicación…'),
            ]),
          ),
        _EstadoUbicacion.servicioApagado => _aviso(
            Icons.location_off_outlined,
            'La ubicación está apagada',
            'Activa el GPS para ver tu posición y las sucursales cercanas.',
            'Abrir ajustes de ubicación',
            () async {
              await Geolocator.openLocationSettings();
            },
          ),
        _EstadoUbicacion.denegado => _aviso(
            Icons.location_disabled_outlined,
            'Permiso de ubicación denegado',
            'Necesitamos tu ubicación para mostrarte las sucursales más cercanas.',
            'Volver a pedir permiso',
            _obtenerUbicacion,
          ),
        _EstadoUbicacion.denegadoSiempre => _aviso(
            Icons.block,
            'Permiso denegado permanentemente',
            'Habilita la ubicación para esta app desde Ajustes > Permisos.',
            'Abrir Ajustes',
            () async {
              await Geolocator.openAppSettings();
            },
          ),
        _EstadoUbicacion.error => _aviso(
            Icons.error_outline,
            'No pudimos obtener tu ubicación',
            'Revisa que el GPS tenga señal e inténtalo de nuevo.',
            'Reintentar',
            _obtenerUbicacion,
          ),
        _ => _contenidoMapa(),
      },
    );
  }

  Widget _aviso(IconData icono, String titulo, String texto, String boton,
      Future<void> Function() accion) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 14),
          Text(titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          FilledButton(onPressed: accion, child: Text(boton)),
          TextButton(onPressed: _obtenerUbicacion, child: const Text('Reintentar')),
        ]),
      ),
    );
  }

  Widget _contenidoMapa() {
    final yo = _yo ?? _respaldo;
    final siguiendo = _sub != null;
    return Column(children: [
      Expanded(
        child: Stack(children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: yo,
              initialZoom: 15,
              onMapReady: () => _mapaListo = true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pruebas',
                maxZoom: 19,
              ),
              if (_recorrido.length > 1)
                PolylineLayer(polylines: [
                  Polyline(
                    points: List.of(_recorrido),
                    strokeWidth: 5,
                    color: AppTheme.acento,
                  ),
                ]),
              MarkerLayer(markers: [
                for (final s in _sucursales)
                  Marker(
                    point: s.punto,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _detalleSucursal(s),
                      child: Icon(Icons.storefront, color: AppTheme.acento, size: 34),
                    ),
                  ),
                if (_yo != null)
                  Marker(
                    point: _yo!,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x551E88E5), blurRadius: 10, spreadRadius: 6),
                        ],
                      ),
                    ),
                  ),
              ]),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap',
                    onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(children: [
              FloatingActionButton.small(
                heroTag: 'centrar',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.acento,
                tooltip: 'Centrar en mí',
                onPressed: () {
                  if (_yo != null) {
                    _mapa.move(_yo!, 16);
                  } else {
                    _obtenerUbicacion();
                  }
                },
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'seguir',
                backgroundColor: siguiendo ? AppTheme.error : AppTheme.acento,
                foregroundColor: Colors.white,
                tooltip: siguiendo ? 'Detener recorrido' : 'Seguir mi recorrido',
                onPressed: _alternarSeguimiento,
                child: Icon(siguiendo ? Icons.stop : Icons.directions_walk),
              ),
            ]),
          ),
          if (siguiendo)
            Positioned(
              left: 12,
              right: 70,
              top: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metrica(Icons.straighten, _formatoDistancia(_distancia), 'Distancia'),
                      _metrica(Icons.timer_outlined, _formatoTiempo(), 'Tiempo'),
                      _metrica(Icons.speed, '${(_velocidad * 3.6).toStringAsFixed(1)} km/h', 'Velocidad'),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      ),
      SizedBox(
        height: 190,
        child: _sucursales.isEmpty
            ? const Center(child: Text('Sin sucursales cercanas'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: _sucursales.length,
                itemBuilder: (_, i) {
                  final s = _sucursales[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.storefront,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(s.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${_formatoDistancia(s.distancia)} · ${s.horario}'),
                      trailing: TextButton(
                        onPressed: () => _comoLlegar(s),
                        child: const Text('Cómo llegar'),
                      ),
                      onTap: () => _mapa.move(s.punto, 16),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _metrica(IconData icono, String valor, String etiqueta) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: AppTheme.acento),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  void _detalleSucursal(_Sucursal s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${_formatoDistancia(s.distancia)} de ti · ${s.horario}'),
          Text('Aprox. ${math.max(1, (s.distancia / 80).round())} min caminando',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                _comoLlegar(s);
              },
              icon: const Icon(Icons.directions),
              label: const Text('Cómo llegar'),
            ),
          ),
        ]),
      ),
    );
  }
}
