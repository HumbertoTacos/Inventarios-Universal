// ── AtributoCategoria ─────────────────────────────────────────────────────

/// Define un atributo que tendrá cada producto de esta categoría.
/// [esListaFija] = true  →  el usuario elige de [opciones] (combobox).
/// [esListaFija] = false →  el usuario escribe texto libre.
class AtributoCategoria {
  final String nombre;
  final bool esListaFija;
  final List<String> opciones; // relevante solo si esListaFija == true

  const AtributoCategoria({
    required this.nombre,
    required this.esListaFija,
    this.opciones = const [],
  });

  factory AtributoCategoria.fromMap(Map<String, dynamic> map) {
    return AtributoCategoria(
      nombre: map['nombre'] as String? ?? '',
      esListaFija: map['esListaFija'] as bool? ?? false,
      opciones: List<String>.from(map['opciones'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'esListaFija': esListaFija,
        'opciones': opciones,
      };

  @override
  String toString() =>
      'AtributoCategoria(nombre: $nombre, lista: $esListaFija, opciones: $opciones)';
}

// ── Categoria ─────────────────────────────────────────────────────────────

class Categoria {
  final String id;
  final String nombre;

  /// Lista de atributos que define esta categoría (Tamaño, Color, Material…).
  final List<AtributoCategoria> atributos;

  final int orden;

  const Categoria({
    required this.id,
    required this.nombre,
    required this.atributos,
    this.orden = 0,
  });

  factory Categoria.fromMap(Map<String, dynamic> map, String id) {
    // ── Migración desde modelo antiguo ──────────────────────────────────
    // Si el documento aún tiene 'tipoAtributo' + 'tamaños', los convertimos
    // al nuevo formato para que sigan funcionando sin re-escribir Firestore.
    List<AtributoCategoria> atributos;

    final rawAtributos = map['atributos'];
    if (rawAtributos != null && rawAtributos is List && rawAtributos.isNotEmpty) {
      atributos = rawAtributos
          .map((a) => AtributoCategoria.fromMap(a as Map<String, dynamic>))
          .toList();
    } else {
      // Documento viejo: construir atributos sintéticos
      final tipoAtributo = map['tipoAtributo'] as String? ?? 'color';
      final tamanos = List<String>.from(map['tamaños'] ?? []);

      atributos = [
        AtributoCategoria(
          nombre: 'Tamaño',
          esListaFija: tamanos.isNotEmpty,
          opciones: tamanos,
        ),
        AtributoCategoria(
          nombre: tipoAtributo == 'diseño' ? 'Diseño' : 'Color',
          esListaFija: false,
          opciones: [],
        ),
      ];
    }

    return Categoria(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      atributos: atributos,
      orden: (map['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'atributos': atributos.map((a) => a.toMap()).toList(),
        'orden': orden,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Categoria && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Categoria(id: $id, nombre: $nombre, atributos: $atributos)';
}
