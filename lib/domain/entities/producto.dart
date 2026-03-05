import 'rubro.dart';

class Producto {
  final String codigoDeBarras;
  final String nombre;
  final Rubro? rubro;

  Producto({
    required this.codigoDeBarras,
    required this.nombre,
    required this.rubro,
  });

  @override
  String toString() {
    return 'Producto(codigoDeBarras: $codigoDeBarras, nombre: $nombre, rubro: ${rubro?.nombre ?? 'N/A'})';
  }
}