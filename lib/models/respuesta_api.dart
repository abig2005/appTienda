class RespuestaApi {
  final String codigo;
  final String texto;

  RespuestaApi({required this.codigo, required this.texto});

  Map<String, Object?> toMap() {
    return {'codigo': codigo, 'texto': texto};
  }
}
