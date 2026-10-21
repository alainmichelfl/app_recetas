import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Representa una acción de modificación en la lista de compras que ocurrió offline
class AccionPendienteCarrito {
  final int idItem;
  final String tipo; // 'update_comprado' | 'delete'
  final bool? valorComprado;
  final DateTime timestamp;

  const AccionPendienteCarrito({
    required this.idItem,
    required this.tipo,
    this.valorComprado,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id_item': idItem,
        'tipo': tipo,
        'valor_comprado': valorComprado,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AccionPendienteCarrito.fromMap(Map<String, dynamic> map) =>
      AccionPendienteCarrito(
        idItem: int.tryParse(map['id_item']?.toString() ?? '0') ?? 0,
        tipo: map['tipo']?.toString() ?? 'update_comprado',
        valorComprado: map['valor_comprado'] as bool?,
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Servicio de Resiliencia Offline y Sincronización Diferida (Prioridad R3)
/// Permite tachar productos, ajustar cantidades y operar en sótanos de supermercados
/// sin cobertura de red, garantizando cero pérdida de información y sincronización automática.
class ServicioCarritoOffline {
  ServicioCarritoOffline._();

  static const String _keyCache = 'cache_local_lista_compras_v1';
  static const String _keyCola = 'cola_sincronizacion_carrito_v1';

  /// Notificador reactivo de cambios pendientes para actualizar la UI en vivo
  static final ValueNotifier<int> pendientesNotifier = ValueNotifier<int>(0);

  static List<Map<String, dynamic>>? _memoriaCache;

  /// Guarda en almacenamiento local la lista de compras más reciente
  static Future<void> guardarCacheLocal(List<Map<String, dynamic>> items) async {
    try {
      _memoriaCache = items.map((i) => Map<String, dynamic>.from(i)).toList();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items);
      await prefs.setString(_keyCache, jsonStr);
    } catch (e) {
      debugPrint('⚠️ Error al guardar caché local de lista de compras: $e');
    }
  }

  /// Recupera la lista de compras almacenada en caché local
  static Future<List<Map<String, dynamic>>> obtenerCacheLocal() async {
    if (_memoriaCache != null && _memoriaCache!.isNotEmpty) {
      return _memoriaCache!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCache);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _memoriaCache = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return _memoriaCache!;
      }
    } catch (e) {
      debugPrint('⚠️ Error al leer caché local de lista de compras: $e');
    }
    return [];
  }

  /// Invalida la memoria caché para forzar recarga fresca desde Supabase
  static Future<void> invalidarCache() async {
    _memoriaCache = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCache);
    } catch (_) {}
  }

  /// Actualiza de forma optimista el estado 'comprado' de un producto:
  /// 1. Lo refleja de inmediato en caché local.
  /// 2. Intenta persistir en Supabase con timeout de 2.5s.
  /// 3. Si no hay conexión o falla, lo encola para sincronización diferida.
  static Future<bool> actualizarEstadoComprado({
    required int idItem,
    required bool comprado,
    SupabaseClient? supabaseClient,
  }) async {
    // 1. Actualización optimista en memoria y caché local
    await _actualizarItemEnCache(idItem, (map) {
      map['comprado'] = comprado;
    });

    final client = supabaseClient ?? Supabase.instance.client;

    // 2. Intentar guardar en Supabase con timeout seguro
    try {
      await client
          .from('lista_compras')
          .update({'comprado': comprado})
          .eq('id', idItem)
          .timeout(const Duration(milliseconds: 2500));

      // Si tuvo éxito, retiramos cualquier acción pendiente previa para este item
      await _eliminarAccionDeCola(idItem, 'update_comprado');
      return true;
    } catch (e) {
      debugPrint('📶 Sin conexión en supermercado. Guardando cambio en cola local: $e');
      // 3. Encolar acción para sincronización diferida
      await _encolarAccion(
        AccionPendienteCarrito(
          idItem: idItem,
          tipo: 'update_comprado',
          valorComprado: comprado,
          timestamp: DateTime.now(),
        ),
      );
      return false;
    }
  }

  /// Elimina un artículo con resiliencia offline
  static Future<bool> eliminarItem({
    required int idItem,
    SupabaseClient? supabaseClient,
  }) async {
    // 1. Retirar inmediatamente de la caché local
    await _removerItemDeCache(idItem);

    final client = supabaseClient ?? Supabase.instance.client;

    try {
      await client
          .from('lista_compras')
          .delete()
          .eq('id', idItem)
          .timeout(const Duration(milliseconds: 2500));

      await _eliminarAccionDeCola(idItem, 'delete');
      return true;
    } catch (e) {
      debugPrint('📶 Eliminación encolada para cuando haya red: $e');
      await _encolarAccion(
        AccionPendienteCarrito(
          idItem: idItem,
          tipo: 'delete',
          timestamp: DateTime.now(),
        ),
      );
      return false;
    }
  }

  /// Sincroniza todas las acciones pendientes acumuladas cuando se restablece la conexión
  static Future<int> sincronizarPendientes(SupabaseClient supabaseClient) async {
    final cola = await _obtenerCola();
    if (cola.isEmpty) {
      pendientesNotifier.value = 0;
      return 0;
    }

    int sincronizados = 0;
    final List<AccionPendienteCarrito> fallidos = [];

    for (final accion in cola) {
      try {
        if (accion.tipo == 'update_comprado') {
          await supabaseClient
              .from('lista_compras')
              .update({'comprado': accion.valorComprado ?? false})
              .eq('id', accion.idItem)
              .timeout(const Duration(milliseconds: 3000));
          sincronizados++;
        } else if (accion.tipo == 'delete') {
          await supabaseClient
              .from('lista_compras')
              .delete()
              .eq('id', accion.idItem)
              .timeout(const Duration(milliseconds: 3000));
          sincronizados++;
        }
      } catch (e) {
        debugPrint('⚠️ Error sincronizando acción ${accion.idItem}: $e');
        fallidos.add(accion);
      }
    }

    await _guardarCola(fallidos);
    pendientesNotifier.value = fallidos.length;
    return sincronizados;
  }

  /// Consulta cuántas acciones están esperando conectividad
  static Future<int> obtenerConteoPendientes() async {
    final cola = await _obtenerCola();
    pendientesNotifier.value = cola.length;
    return cola.length;
  }

  // --- MÉTODOS AUXILIARES PRIVADOS ---

  static Future<List<AccionPendienteCarrito>> _obtenerCola() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyCola);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded
            .map((e) => AccionPendienteCarrito.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error al leer cola de sincronización: $e');
    }
    return [];
  }

  static Future<void> _guardarCola(List<AccionPendienteCarrito> cola) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(cola.map((e) => e.toMap()).toList());
      await prefs.setString(_keyCola, str);
      pendientesNotifier.value = cola.length;
    } catch (e) {
      debugPrint('Error al guardar cola de sincronización: $e');
    }
  }

  static Future<void> _encolarAccion(AccionPendienteCarrito accion) async {
    final cola = await _obtenerCola();
    // Reemplazar acción previa del mismo item si existe para evitar operaciones redundantes
    cola.removeWhere((a) => a.idItem == accion.idItem && a.tipo == accion.tipo);
    cola.add(accion);
    await _guardarCola(cola);
  }

  static Future<void> _eliminarAccionDeCola(int idItem, String tipo) async {
    final cola = await _obtenerCola();
    final lenAntes = cola.length;
    cola.removeWhere((a) => a.idItem == idItem && a.tipo == tipo);
    if (cola.length != lenAntes) {
      await _guardarCola(cola);
    }
  }

  static Future<void> _actualizarItemEnCache(
    int idItem,
    void Function(Map<String, dynamic>) actualizador,
  ) async {
    final items = await obtenerCacheLocal();
    for (var item in items) {
      if (item['id'] == idItem) {
        actualizador(item);
        break;
      }
    }
    await guardarCacheLocal(items);
  }

  static Future<void> _removerItemDeCache(int idItem) async {
    final items = await obtenerCacheLocal();
    items.removeWhere((i) => i['id'] == idItem);
    await guardarCacheLocal(items);
  }
}
