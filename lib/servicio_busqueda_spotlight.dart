import 'package:flutter/material.dart';
import 'conversor_unidades.dart';
import 'servicio_sommelier.dart';
import 'servicio_zonas_despensa.dart';
import 'utensilios_cocina.dart';

/// Tipo de entidad retornada en la búsqueda universal
enum TipoResultadoSpotlight {
  receta,
  despensa,
  cava,
  utensilio;

  String get etiqueta {
    switch (this) {
      case TipoResultadoSpotlight.receta:
        return 'Receta';
      case TipoResultadoSpotlight.despensa:
        return 'Despensa';
      case TipoResultadoSpotlight.cava:
        return 'Cava & Bar';
      case TipoResultadoSpotlight.utensilio:
        return 'Utensilio';
    }
  }

  IconData get iconoPorDefecto {
    switch (this) {
      case TipoResultadoSpotlight.receta:
        return Icons.restaurant_menu_rounded;
      case TipoResultadoSpotlight.despensa:
        return Icons.inventory_2_outlined;
      case TipoResultadoSpotlight.cava:
        return Icons.wine_bar_rounded;
      case TipoResultadoSpotlight.utensilio:
        return Icons.kitchen_rounded;
    }
  }

  Color get colorPorDefecto {
    switch (this) {
      case TipoResultadoSpotlight.receta:
        return const Color(0xFFE65100);
      case TipoResultadoSpotlight.despensa:
        return const Color(0xFF2E7D32);
      case TipoResultadoSpotlight.cava:
        return const Color(0xFF6A1B9A);
      case TipoResultadoSpotlight.utensilio:
        return const Color(0xFF00838F);
    }
  }
}

/// Modelo de un resultado indexado en la búsqueda Spotlight
class ResultadoSpotlight {
  final String id;
  final String titulo;
  final String subtitulo;
  final TipoResultadoSpotlight tipo;
  final IconData icono;
  final Color color;
  final String? ubicacion;
  final Map<String, dynamic> metadata;

  const ResultadoSpotlight({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.tipo,
    required this.icono,
    required this.color,
    this.ubicacion,
    this.metadata = const {},
  });
}

/// Motor de indexación y búsqueda transversal instantánea (Spotlight)
class ServicioBusquedaSpotlight {
  /// Ejecuta una búsqueda unificada sobre recetas, despensa física, cava y utensilios
  static List<ResultadoSpotlight> buscar({
    required String query,
    List<Map<String, dynamic>> recetas = const [],
    List<Map<String, dynamic>> despensa = const [],
    List<UtensilioItem>? catalogoUtensilios,
    Map<String, String> zonaOverrides = const {},
  }) {
    final q = ConversorUnidades.sinAcentos(query).trim().toLowerCase();
    if (q.length < 2) return const [];

    final List<ResultadoSpotlight> resultados = [];

    // 1. Indexar y buscar en Recetas
    for (var r in recetas) {
      final titulo = (r['titulo'] ?? '').toString();
      final desc = (r['descripcion'] ?? '').toString();
      final cat = (r['categoria'] ?? r['tipo_comida'] ?? '').toString();

      final fullTexto =
          ConversorUnidades.sinAcentos('$titulo $desc $cat').toLowerCase();
      if (fullTexto.contains(q)) {
        resultados.add(
          ResultadoSpotlight(
            id: 'receta_${r['id'] ?? r['id_receta'] ?? titulo}',
            titulo: titulo.isNotEmpty ? titulo : 'Receta sin título',
            subtitulo: cat.isNotEmpty ? 'Categoría: $cat' : 'Receta de Cocina',
            tipo: TipoResultadoSpotlight.receta,
            icono: Icons.restaurant_menu_rounded,
            color: const Color(0xFFE65100),
            ubicacion: 'Libro de Recetas',
            metadata: r,
          ),
        );
      }
    }

    // 2. Indexar y buscar en Despensa y Cava
    for (var d in despensa) {
      final nombre = (d['nombre'] ?? '').toString();
      final cant = d['cantidad'];
      final unidad = d['unidad_medida'] ?? '';
      final fullNombre = ConversorUnidades.sinAcentos(nombre).toLowerCase();

      if (fullNombre.contains(q)) {
        final bool esCava = ServicioSommelier.esItemDeCava(nombre);
        final zona = ServicioZonasDespensa.resolverZona(
          d,
          zonaOverrides,
        );

        final String cantStr =
            (cant != null || unidad.toString().isNotEmpty)
                ? ' • ${cant ?? ''} $unidad'.trim()
                : '';

        if (esCava) {
          resultados.add(
            ResultadoSpotlight(
              id: 'cava_${d['id_item'] ?? nombre}',
              titulo: nombre,
              subtitulo: '${zona.emoji} ${zona.nombre}$cantStr • Cava & Bar',
              tipo: TipoResultadoSpotlight.cava,
              icono: Icons.wine_bar_rounded,
              color: const Color(0xFF6A1B9A),
              ubicacion: '${zona.emoji} ${zona.nombre}',
              metadata: d,
            ),
          );
        } else {
          resultados.add(
            ResultadoSpotlight(
              id: 'despensa_${d['id_item'] ?? nombre}',
              titulo: nombre,
              subtitulo: '${zona.emoji} ${zona.nombre}$cantStr',
              tipo: TipoResultadoSpotlight.despensa,
              icono: zona.icono,
              color: const Color(0xFF2E7D32),
              ubicacion: '${zona.emoji} ${zona.nombre}',
              metadata: d,
            ),
          );
        }
      }
    }

    // 3. Indexar y buscar en Utensilios y Electrodomésticos de cocina
    final utensilios = catalogoUtensilios ?? UtensiliosCocina.catalogo;
    for (var u in utensilios) {
      final nombre = u.nombre;
      final desc = u.descripcion;
      final palabras = u.palabrasClave.join(' ');
      final fullTexto =
          ConversorUnidades.sinAcentos('$nombre $desc $palabras').toLowerCase();

      if (fullTexto.contains(q)) {
        resultados.add(
          ResultadoSpotlight(
            id: 'utensilio_${u.id}',
            titulo: '${u.icono} ${u.nombre}',
            subtitulo: u.descripcion,
            tipo: TipoResultadoSpotlight.utensilio,
            icono: Icons.kitchen_rounded,
            color: const Color(0xFF00838F),
            ubicacion: 'Mi Cocina & Equipo',
            metadata: {
              'id_utensilio': u.id,
              'icono': u.icono,
              'descripcion': u.descripcion,
              'nombre': u.nombre,
            },
          ),
        );
      }
    }

    return resultados;
  }
}
