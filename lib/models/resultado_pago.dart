/// Lo que devuelve PagoView al carrito.
class ResultadoPago {
  /// tarjeta | paypal | spei | efectivo
  final String metodo;

  /// Texto legible, p. ej. "Visa •••• 4242 · 3 MSI".
  final String descripcion;

  /// Referencia / id de transacción simulado.
  final String referencia;

  /// aprobado | pendiente
  final String estado;

  const ResultadoPago({
    required this.metodo,
    required this.descripcion,
    required this.referencia,
    required this.estado,
  });

  bool get pendiente => estado == 'pendiente';

  String get nombreMetodo {
    switch (metodo) {
      case 'tarjeta':
        return 'Tarjeta';
      case 'paypal':
        return 'PayPal';
      case 'spei':
        return 'Transferencia SPEI';
      case 'efectivo':
        return 'Efectivo en tienda';
      default:
        return metodo;
    }
  }
}
