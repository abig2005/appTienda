import 'package:xml/xml.dart';
import 'producto.dart';
import 'respuesta_api.dart';

class ResultadoParseo {
  final RespuestaApi mensaje;
  final List<Producto> productos;

  ResultadoParseo({required this.mensaje, required this.productos});
}

ResultadoParseo parsearRespuestaXml(String xml) {
  final document = XmlDocument.parse(xml);
  final root = document.rootElement;

  final mensajeXml = root.getElement('MENSAJE');

  if (mensajeXml == null) {
    throw FormatException('La respuesta no contiene MENSAJE');
  }

  final mensaje = RespuestaApi(
    codigo: mensajeXml.getElement('CODIGO')?.innerText.trim() ?? '',
    texto: mensajeXml.getElement('TEXTO')?.innerText.trim() ?? '',
  );

  final productosXml = root.getElement('PRODUCTOS');

  final productos =
      productosXml
          ?.findElements('producto')
          .map((element) => Producto.fromXml(element))
          .toList() ??
      <Producto>[];

  return ResultadoParseo(mensaje: mensaje, productos: productos);
}
