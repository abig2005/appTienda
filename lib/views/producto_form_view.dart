import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/notificacion.dart';
import '../models/producto.dart';
import '../repository/producto_repository.dart';
import '../services/catalogo_service.dart';
import '../services/notification_service.dart';
import '../widgets/comunes.dart';

/// Alta de producto (admin y editor).
class ProductoFormView extends StatefulWidget {
  const ProductoFormView({super.key});

  @override
  State<ProductoFormView> createState() => _ProductoFormViewState();
}

class _ProductoFormViewState extends State<ProductoFormView> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _stock = TextEditingController(text: '10');
  final _descripcion = TextEditingController();
  String _categoria = 'General';
  String _imagen = '';
  bool _guardando = false;

  static const _categorias = [
    'General',
    'Electrónica',
    'Joyería',
    'Ropa de hombre',
    'Ropa de mujer',
    'Hogar',
    'Papelería',
    'Alimentos',
  ];

  static const _muestras = [
    'https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_.jpg',
    'https://fakestoreapi.com/img/71-3HjGNDUL._AC_SY879._SX._UX._SY._UY_.jpg',
    'https://fakestoreapi.com/img/71li-ujtlUL._AC_UX679_.jpg',
    'https://fakestoreapi.com/img/61sbMiUnoGL._AC_UL640_QL65_ML3_.jpg',
    'https://fakestoreapi.com/img/61IBBVJvSDL._AC_SY879_.jpg',
    'https://fakestoreapi.com/img/81QpkIctqPL._AC_SX679_.jpg',
  ];

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _stock, _descripcion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: fuente, maxWidth: 1200, imageQuality: 80);
      if (x == null) return;
      // Copiamos a una carpeta propia para que no se borre con la caché.
      final dir = Directory(p.join(await getDatabasesPath(), 'imagenes'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final destino = p.join(
          dir.path, 'prod_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path)}');
      await File(x.path).copy(destino);
      if (mounted) setState(() => _imagen = destino);
    } catch (e) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo obtener la foto. Revisa los permisos.',
            error: true);
      }
    }
  }

  Future<void> _desdeUrl() async {
    final c = TextEditingController(text: _imagen.startsWith('http') ? _imagen : '');
    final url = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Imagen desde URL'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: const Text('Usar')),
        ],
      ),
    );
    if (url != null && url.startsWith('http')) setState(() => _imagen = url);
  }

  Future<void> _muestra() async {
    final url = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        shrinkWrap: true,
        children: [
          for (final m in _muestras)
            InkWell(
              onTap: () => Navigator.pop(c, m),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: ImagenProducto(ruta: m),
              ),
            ),
        ],
      ),
    );
    if (url != null) setState(() => _imagen = url);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final prod = Producto(
      nombre: _nombre.text.trim(),
      precio: double.parse(_precio.text.replaceAll(',', '.')),
      stock: int.tryParse(_stock.text) ?? 0,
      imagen: _imagen,
      categoria: _categoria,
      descripcion: _descripcion.text.trim(),
    );
    await ProductoRepository.instance.insertar(prod);
    CatalogoService.instance.cambios.value++;
    await NotificationService.instance.notificar(
      titulo: '🆕 Producto nuevo',
      cuerpo: '${prod.nombre} ya está disponible por ${dinero(prod.precio)}.',
      tipo: TipoNotificacion.promociones,
      general: true,
    );
    if (!mounted) return;
    mostrarMensaje(context, 'Producto agregado ✓');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Producto')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const BannerDegradado(
                icono: Icons.add_business_rounded,
                titulo: 'Nuevo producto',
                subtitulo: 'Se agregará al catálogo y se notificará a los compradores',
                compacto: true,
              ),
              const SizedBox(height: 18),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.all(10),
                child: ImagenProducto(ruta: _imagen),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                      avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Cámara'),
                      onPressed: () => _elegirFoto(ImageSource.camera)),
                  ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galería'),
                      onPressed: () => _elegirFoto(ImageSource.gallery)),
                  ActionChip(
                      avatar: const Icon(Icons.link, size: 18),
                      label: const Text('URL'),
                      onPressed: _desdeUrl),
                  ActionChip(
                      avatar: const Icon(Icons.collections_outlined, size: 18),
                      label: const Text('Muestras'),
                      onPressed: _muestra),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nombre', prefixIcon: Icon(Icons.label_outline)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe el nombre' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Precio', prefixText: '\$ '),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (n == null || n <= 0) ? 'Precio inválido' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Existencias'),
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Requerido' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(
                    labelText: 'Categoría', prefixIcon: Icon(Icons.category_outlined)),
                items: [
                  for (final c in _categorias)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _categoria = v ?? 'General'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Descripción', alignLabelWithHint: true),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                icon: _guardando ? const CargandoBoton() : const Icon(Icons.save_rounded),
                label: const Text('Guardar producto',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
