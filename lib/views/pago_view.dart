import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../controllers/sesion_controller.dart';
import '../models/resultado_pago.dart';
import '../services/pago_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// Abre las formas de pago en una hoja que sube desde abajo, sin salir del carrito.
Future<ResultadoPago?> mostrarHojaPago(BuildContext context, double total) {
  return showModalBottomSheet<ResultadoPago>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag:
        false, // evita cerrarla por accidente mientras se escribe o procesa
    builder: (_) => PagoView(total: total),
  );
}

/// Gestiona los métodos de pago y devuelve su resultado.
class PagoView extends StatefulWidget {
  final double total;
  const PagoView({super.key, required this.total});

  @override
  State<PagoView> createState() => _PagoViewState();
}

class _PagoViewState extends State<PagoView> {
  String _metodo = 'tarjeta';
  bool _procesando = false;
  String? _error;

  // Tarjeta
  final _formTarjeta = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _titular = TextEditingController();
  final _vigencia = TextEditingController();
  final _cvv = TextEditingController();
  final _cvvFoco = FocusNode();
  int _msi = 1;

  bool _paypalAbierto = false;

  // SPEI / efectivo: referencias fijas durante la pantalla
  final _refSpei = PagoUtils.referencia('SPEI');
  final _refEfectivo = PagoUtils.referencia('EFE');
  late final DateTime _vigenciaEfectivo = DateTime.now().add(
    const Duration(hours: 72),
  );

  static const _clabe = '646180157000000004'; // ficticia
  static const _banco = 'Banco Demo (STP)';

  @override
  void initState() {
    super.initState();
    _cvvFoco.addListener(() => setState(() {}));
    for (final c in [_numero, _titular, _vigencia, _cvv]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_numero, _titular, _vigencia, _cvv]) {
      c.dispose();
    }
    _cvvFoco.dispose();
    super.dispose();
  }

  MarcaTarjeta get _marca => PagoUtils.marca(_numero.text);

  Uri? get _paypalMeUri {
    final base = Uri.tryParse(AppConfig.paypalMeUrl.trim());
    final segmentos = base?.pathSegments.where((s) => s.isNotEmpty).toList();
    if (base == null ||
        base.scheme != 'https' ||
        base.host != 'paypal.me' ||
        base.hasPort ||
        base.userInfo.isNotEmpty ||
        segmentos == null ||
        segmentos.length != 1 ||
        base.query.isNotEmpty ||
        base.fragment.isNotEmpty) {
      return null;
    }
    return base.replace(
      pathSegments: [...segmentos, '${widget.total.toStringAsFixed(2)}MXN'],
    );
  }

  Future<void> _abrirPaypalMe() async {
    final uri = _paypalMeUri;
    if (uri == null) {
      setState(() {
        _error =
            'Configura PAYPAL_ME_URL con tu enlace https://paypal.me/usuario.';
      });
      return;
    }
    try {
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      setState(() {
        _paypalAbierto = abierto;
        _error = abierto ? null : 'No se pudo abrir el enlace de PayPal.Me.';
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() => _error = 'Ocurrió un error al abrir PayPal.Me.');
    }
  }

  Future<void> _pagar() async {
    setState(() => _error = null);
    ResultadoPago? resultado;

    switch (_metodo) {
      case 'tarjeta':
        if (!_formTarjeta.currentState!.validate()) return;
        final n = PagoUtils.soloDigitos(_numero.text);
        await _simularProceso();
        if (!mounted) return;
        if (n == PagoUtils.tarjetaRechazada) {
          setState(() {
            _procesando = false;
            _error =
                'Pago rechazado: fondos insuficientes. Prueba con otra tarjeta.';
          });
          return;
        }
        final ultimos = n.substring(n.length - 4);
        resultado = ResultadoPago(
          metodo: 'tarjeta',
          descripcion:
              '${PagoUtils.nombreMarca(_marca)} •••• $ultimos'
              '${_msi > 1 ? ' · $_msi MSI' : ' · una sola exhibición'}',
          referencia: PagoUtils.referencia('TXN'),
          estado: 'aprobado',
        );
      case 'paypal':
        if (_paypalMeUri == null) {
          setState(
            () =>
                _error =
                    'Configura PAYPAL_ME_URL con tu enlace https://paypal.me/usuario.',
          );
          return;
        }
        if (!_paypalAbierto) {
          setState(
            () => _error = 'Abre PayPal.Me antes de registrar el pedido.',
          );
          return;
        }
        resultado = ResultadoPago(
          metodo: 'paypal',
          descripcion: 'PayPal.Me · ${dinero(widget.total)} · por confirmar',
          referencia: PagoUtils.referencia('PP'),
          estado: 'pendiente',
        );
      case 'spei':
        await _simularProceso();
        resultado = ResultadoPago(
          metodo: 'spei',
          descripcion: 'Transferencia SPEI a CLABE ${_clabe.substring(14)}',
          referencia: _refSpei,
          estado: 'pendiente',
        );
      default:
        await _simularProceso();
        resultado = ResultadoPago(
          metodo: 'efectivo',
          descripcion:
              'Efectivo en tienda (vence ${_vigenciaEfectivo.day.toString().padLeft(2, '0')}/${_vigenciaEfectivo.month.toString().padLeft(2, '0')})',
          referencia: _refEfectivo,
          estado: 'pendiente',
        );
    }
    if (!mounted) return;
    Navigator.of(context).pop(resultado);
  }

  Future<void> _simularProceso() async {
    setState(() => _procesando = true);
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  void _copiar(String valor, String que) {
    Clipboard.setData(ClipboardData(text: valor));
    mostrarMensaje(context, '$que copiado');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esReferencia = _metodo == 'spei' || _metodo == 'efectivo';
    return PopScope(
      canPop: !_procesando,
      child: Padding(
        // Sube la hoja cuando aparece el teclado.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Stack(
            children: [
              Column(
                children: [
                  // Encabezado de la hoja
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                    child: Column(
                      children: [
                        const AsaHoja(),
                        Row(
                          children: [
                            Icon(Icons.payments_rounded, color: cs.primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Elige cómo pagar',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed:
                                  _procesando
                                      ? null
                                      : () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: cs.onPrimaryContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _metodo == 'paypal'
                                      ? 'PayPal.Me es manual: el pedido quedará pendiente hasta verificar el pago en tu cuenta.'
                                      : 'Modo simulación: no se procesa ningún cargo real.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.3,
                          children: [
                            _opcion('tarjeta', 'Tarjeta', Icons.credit_card),
                            _opcion(
                              'paypal',
                              'PayPal',
                              Icons.account_balance_wallet_outlined,
                            ),
                            _opcion(
                              'spei',
                              'Transferencia SPEI',
                              Icons.account_balance_outlined,
                            ),
                            _opcion(
                              'efectivo',
                              'Efectivo en tienda',
                              Icons.storefront_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: switch (_metodo) {
                            'tarjeta' => _formularioTarjeta(),
                            'paypal' => _formularioPaypal(),
                            'spei' => _datosSpei(),
                            _ => _datosEfectivo(),
                          },
                        ),
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cancel_outlined,
                                  color: AppTheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Pie fijo con total y botón de pago
                  Material(
                    elevation: 10,
                    color: Theme.of(context).cardTheme.color ?? cs.surface,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total a pagar',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                const Spacer(),
                                Text(
                                  dinero(widget.total),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _procesando ? null : _pagar,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                icon: Icon(
                                  esReferencia || _metodo == 'paypal'
                                      ? Icons.receipt_long_outlined
                                      : Icons.lock_outline,
                                ),
                                label: Text(
                                  _metodo == 'paypal'
                                      ? 'Registrar pedido pendiente'
                                      : esReferencia
                                      ? 'Generar referencia y confirmar pedido'
                                      : 'Pagar ${dinero(widget.total)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_procesando)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                'Procesando pago…',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'No cierres esta pantalla',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcion(String id, String texto, IconData icono) {
    final sel = _metodo == id;
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: sel ? cs.primaryContainer : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sel ? cs.primary : cs.outlineVariant,
          width: sel ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap:
            _procesando
                ? null
                : () => setState(() {
                  _metodo = id;
                  _error = null;
                }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icono, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tarjeta
  // ---------------------------------------------------------------------------

  Widget _vistaPreviaTarjeta() {
    final marca = _marca;
    final colores = switch (marca) {
      MarcaTarjeta.visa => [const Color(0xFF1A237E), const Color(0xFF3949AB)],
      MarcaTarjeta.mastercard => [
        const Color(0xFF263238),
        const Color(0xFFEF6C00),
      ],
      MarcaTarjeta.amex => [const Color(0xFF006064), const Color(0xFF26A69A)],
      MarcaTarjeta.desconocida => [AppTheme.acento, AppTheme.acentoClaro],
    };
    final numero = _numero.text.isEmpty ? '•••• •••• •••• ••••' : _numero.text;
    final atras = _cvvFoco.hasFocus;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: atras ? 1 : 0),
      duration: const Duration(milliseconds: 400),
      builder: (_, v, _) {
        final mostrarAtras = v > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(v * 3.1416),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: colores),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child:
                mostrarAtras
                    ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.1416),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(height: 36, color: Colors.black87),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              color: Colors.white,
                              child: Text(
                                _cvv.text.isEmpty ? 'CVV' : _cvv.text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : DefaultTextStyle(
                      style: const TextStyle(color: Colors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.memory,
                                color: Colors.amberAccent,
                                size: 34,
                              ),
                              const Spacer(),
                              Text(
                                PagoUtils.nombreMarca(marca),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          FittedBox(
                            child: Text(
                              numero,
                              style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _titular.text.isEmpty
                                      ? 'NOMBRE DEL TITULAR'
                                      : _titular.text.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                _vigencia.text.isEmpty
                                    ? 'MM/AA'
                                    : _vigencia.text,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }

  Widget _formularioTarjeta() {
    final marca = _marca;
    return Form(
      key: _formTarjeta,
      child: Column(
        key: const ValueKey('tarjeta'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _vistaPreviaTarjeta(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _numero,
            keyboardType: TextInputType.number,
            inputFormatters: [FormatoNumeroTarjeta()],
            decoration: const InputDecoration(
              labelText: 'Número de tarjeta',
              prefixIcon: Icon(Icons.credit_card),
            ),
            validator: (v) {
              final n = PagoUtils.soloDigitos(v ?? '');
              if (n.length != PagoUtils.longitudNumero(PagoUtils.marca(n))) {
                return 'Número incompleto';
              }
              if (!PagoUtils.luhn(n)) return 'Número de tarjeta inválido';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titular,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Nombre del titular',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator:
                (v) => (v ?? '').trim().length < 3 ? 'Escribe el nombre' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vigencia,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FormatoVigencia()],
                  decoration: const InputDecoration(
                    labelText: 'Vigencia (MM/AA)',
                  ),
                  validator:
                      (v) =>
                          PagoUtils.vigenciaValida(v ?? '')
                              ? null
                              : 'Vencida o inválida',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvv,
                  focusNode: _cvvFoco,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      PagoUtils.longitudCvv(marca),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'CVV (${PagoUtils.longitudCvv(marca)} dígitos)',
                  ),
                  validator:
                      (v) =>
                          (v ?? '').length == PagoUtils.longitudCvv(marca)
                              ? null
                              : 'CVV inválido',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _msi,
            decoration: const InputDecoration(
              labelText: 'Meses sin intereses',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: [
              for (final m in const [1, 3, 6, 12])
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    m == 1
                        ? 'Una sola exhibición'
                        : '$m MSI de ${dinero(widget.total / m)}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _msi = v ?? 1),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tarjetas de prueba',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  _tarjetaPrueba('4242 4242 4242 4242', 'se aprueba'),
                  _tarjetaPrueba(
                    '4000 0000 0000 0002',
                    'se rechaza (fondos insuficientes)',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Solo guardamos la marca y los últimos 4 dígitos.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPrueba(String numero, String resultado) => InkWell(
    onTap:
        () => setState(() {
          _numero.text = numero;
          if (_titular.text.isEmpty) {
            _titular.text =
                context.read<SesionController>().usuario?.nombre ??
                'CLIENTE DEMO';
          }
          if (_vigencia.text.isEmpty) {
            final f = DateTime.now().add(const Duration(days: 730));
            _vigencia.text =
                '${f.month.toString().padLeft(2, '0')}/${(f.year % 100).toString().padLeft(2, '0')}';
          }
          if (_cvv.text.isEmpty) _cvv.text = '123';
        }),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: numero,
              style: TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.acento,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: ' → $resultado',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Otros métodos
  // ---------------------------------------------------------------------------

  Widget _formularioPaypal() => Column(
    key: const ValueKey('paypal'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: const Text('Pago con PayPal.Me'),
        subtitle: Text(
          _paypalMeUri?.toString() ??
              'Configura PAYPAL_ME_URL en config/env.json',
        ),
      ),
      Text('Monto: ${dinero(widget.total)} MXN'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _procesando ? null : _abrirPaypalMe,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Abrir PayPal.Me'),
      ),
      const SizedBox(height: 4),
      const Text(
        'Envía el monto exacto. Al volver, registra el pedido pendiente y confirma '
        'el pago en tu cuenta PayPal antes de preparar el pedido.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      if (_paypalAbierto)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'PayPal.Me se abrió. El pago aún no está verificado.',
            style: TextStyle(fontSize: 12, color: AppTheme.advertencia),
          ),
        ),
    ],
  );

  Widget _filaCopiable(String etiqueta, String valor) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(
      etiqueta,
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    subtitle: Text(
      valor,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    trailing: IconButton(
      tooltip: 'Copiar',
      icon: Icon(Icons.copy_rounded, color: AppTheme.acento),
      onPressed: () => _copiar(valor, etiqueta),
    ),
  );

  Widget _datosSpei() => Card(
    key: const ValueKey('spei'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          _filaCopiable('Banco', _banco),
          _filaCopiable('Beneficiario', '${AppConfig.appName} S.A. de C.V.'),
          _filaCopiable('CLABE (ficticia)', _clabe),
          _filaCopiable('Referencia', _refSpei),
          _filaCopiable('Monto', widget.total.toStringAsFixed(2)),
          const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 6),
            child: Text(
              'Tu pedido quedará pendiente hasta que se reciba la transferencia.',
              style: TextStyle(fontSize: 12, color: AppTheme.advertencia),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _datosEfectivo() {
    final f = _vigenciaEfectivo;
    final vence =
        '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
    return Card(
      key: const ValueKey('efectivo'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          children: [
            _filaCopiable('Referencia de pago', _refEfectivo),
            _filaCopiable('Monto', dinero(widget.total)),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: AppTheme.advertencia),
              title: Text('Vigencia: 72 h (hasta $vence)'),
              subtitle: const Text(
                'Paga en cualquier sucursal mostrando la referencia. Tu pedido quedará pendiente.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
