class Comercio {
  final String id;
  final String nombre;
  
  Comercio({
    required this.id,
    required this.nombre,
  });

  @override
  String toString() => 'Comercio(id: $id, nombre: $nombre)';
}