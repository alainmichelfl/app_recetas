import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MiembroHogar {
  final String userId;
  final String email;
  final String rol;
  final DateTime? unidoEn;

  const MiembroHogar({
    required this.userId,
    required this.email,
    this.rol = 'miembro',
    this.unidoEn,
  });

  String get aliasCorto {
    if (email.isEmpty) return 'Familiar';
    final partes = email.split('@');
    return partes.first;
  }

  factory MiembroHogar.fromMap(Map<String, dynamic> map) {
    return MiembroHogar(
      userId: map['user_id']?.toString() ?? '',
      email: map['email']?.toString() ?? 'Miembro familiar',
      rol: map['rol']?.toString() ?? 'miembro',
      unidoEn: map['unido_en'] != null
          ? DateTime.tryParse(map['unido_en'].toString())
          : null,
    );
  }
}

class InfoHogarFamiliar {
  final String id;
  final String codigo;
  final String nombre;
  final String? creadorId;
  final List<MiembroHogar> miembros;
  final bool esLocalFallback;

  const InfoHogarFamiliar({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.creadorId,
    this.miembros = const [],
    this.esLocalFallback = false,
  });
}

class ServicioHogar {
  ServicioHogar._();

  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _keyHogarCodigoLocal = 'hogar_familiar_codigo_v1';
  static const String _keyHogarNombreLocal = 'hogar_familiar_nombre_v1';
  static const String _keyHogarIdLocal = 'hogar_familiar_id_v1';

  static InfoHogarFamiliar? _cacheHogar;
  static InfoHogarFamiliar? get cacheHogar => _cacheHogar;

  /// Devuelve el alias corto del usuario actual (ej. "alainmichel.fl")
  static String? obtenerAliasUsuarioActual() {
    final email = _supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) return null;
    return email.split('@').first;
  }

  /// Genera un código corto fácil de dictar o enviar por WhatsApp (ej. CASA-4829)
  static String _generarCodigoUnico() {
    final random = Random.secure();
    final numero = 1000 + random.nextInt(9000);
    return 'CASA-$numero';
  }

  /// Obtiene la información del hogar familiar actual del usuario en sesión
  static Future<InfoHogarFamiliar?> obtenerHogarActual({
    bool forzarRecarga = false,
  }) async {
    if (!forzarRecarga && _cacheHogar != null) {
      return _cacheHogar;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _cacheHogar = null;
      return null;
    }

    try {
      // 1. Buscar membresía en Supabase
      final List<dynamic> memData = await _supabase
          .from('miembros_hogar')
          .select('hogar_id, rol')
          .eq('user_id', user.id)
          .limit(1);

      if (memData.isNotEmpty) {
        final String hogarId = memData.first['hogar_id'].toString();

        // 2. Obtener detalles del hogar
        final List<dynamic> hogarData = await _supabase
            .from('hogares')
            .select()
            .eq('id', hogarId)
            .limit(1);

        if (hogarData.isNotEmpty) {
          final mapHogar = Map<String, dynamic>.from(hogarData.first as Map);

          // 3. Obtener todos los miembros del mismo hogar
          final List<dynamic> listaMiembrosRaw = await _supabase
              .from('miembros_hogar')
              .select('user_id, email, rol, unido_en')
              .eq('hogar_id', hogarId)
              .order('unido_en', ascending: true);

          final miembros = listaMiembrosRaw
              .map((m) => MiembroHogar.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();

          final info = InfoHogarFamiliar(
            id: hogarId,
            codigo: mapHogar['codigo']?.toString() ?? '',
            nombre: mapHogar['nombre']?.toString() ?? 'Mi Hogar Familiar',
            creadorId: mapHogar['creador_id']?.toString(),
            miembros: miembros,
          );

          _cacheHogar = info;
          await _guardarCacheLocal(info);
          return info;
        }
      } else {
        // Si la consulta a Supabase tuvo éxito pero no hay membresía, limpiar cache local
        await _limpiarCacheLocal();
        _cacheHogar = null;
        return null;
      }
    } catch (e) {
      debugPrint('ℹ️ Consulta de hogar en modo respaldo local: $e');
      // Respaldo local si aún no se ha corrido el script SQL en Supabase
      return await _leerCacheLocal(user);
    }

    return null;
  }

  /// Crea un nuevo hogar familiar y registra al usuario actual como administrador
  static Future<InfoHogarFamiliar> crearHogar(String nombreHogar) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para crear un Hogar Familiar.');
    }

    final nombreLimpio = nombreHogar.trim().isEmpty
        ? 'Familia ${obtenerAliasUsuarioActual() ?? ''}'.trim()
        : nombreHogar.trim();
    final codigo = _generarCodigoUnico();

    try {
      // 1. Si ya estaba en otro hogar, remover membresía previa
      await _supabase.from('miembros_hogar').delete().eq('user_id', user.id);

      // 2. Insertar el nuevo hogar
      final nuevoHogar = await _supabase
          .from('hogares')
          .insert({
            'codigo': codigo,
            'nombre': nombreLimpio,
            'creador_id': user.id,
          })
          .select()
          .single();

      final String hogarId = nuevoHogar['id'].toString();

      // 3. Registrar al creador como miembro admin
      await _supabase.from('miembros_hogar').insert({
        'hogar_id': hogarId,
        'user_id': user.id,
        'email': user.email ?? 'Administrador',
        'rol': 'admin',
      });

      final info = InfoHogarFamiliar(
        id: hogarId,
        codigo: codigo,
        nombre: nombreLimpio,
        creadorId: user.id,
        miembros: [
          MiembroHogar(
            userId: user.id,
            email: user.email ?? 'Administrador',
            rol: 'admin',
            unidoEn: DateTime.now(),
          ),
        ],
      );

      _cacheHogar = info;
      await _guardarCacheLocal(info);
      return info;
    } catch (e) {
      debugPrint('⚠️ Creando hogar en respaldo local (SQL pendiente): $e');
      final infoLocal = InfoHogarFamiliar(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        codigo: codigo,
        nombre: nombreLimpio,
        creadorId: user.id,
        esLocalFallback: true,
        miembros: [
          MiembroHogar(
            userId: user.id,
            email: user.email ?? 'Administrador',
            rol: 'admin',
            unidoEn: DateTime.now(),
          ),
        ],
      );
      _cacheHogar = infoLocal;
      await _guardarCacheLocal(infoLocal);
      return infoLocal;
    }
  }

  /// Une al usuario en sesión a un hogar existente mediante su código (ej. CASA-4829)
  static Future<InfoHogarFamiliar> unirseAHogar(String codigoInput) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para unirte a un Hogar Familiar.');
    }

    final codigoLimpio = codigoInput.trim().toUpperCase();
    if (codigoLimpio.isEmpty) {
      throw Exception('Ingresa un código de hogar válido (ej. CASA-1234).');
    }

    try {
      // 1. Buscar el hogar por código
      final List<dynamic> hogaresData = await _supabase
          .from('hogares')
          .select()
          .ilike('codigo', codigoLimpio)
          .limit(1);

      if (hogaresData.isEmpty) {
        throw Exception(
          'No encontramos ningún hogar con el código "$codigoLimpio". Verifica que esté bien escrito.',
        );
      }

      final mapHogar = Map<String, dynamic>.from(hogaresData.first as Map);
      final String hogarId = mapHogar['id'].toString();

      // 2. Actualizar o insertar membresía del usuario
      await _supabase.from('miembros_hogar').upsert(
        {
          'hogar_id': hogarId,
          'user_id': user.id,
          'email': user.email ?? 'Miembro familiar',
          'rol': 'miembro',
        },
        onConflict: 'user_id',
      );

      final info = await obtenerHogarActual(forzarRecarga: true);
      if (info != null) return info;

      throw Exception('No se pudo cargar la información del hogar.');
    } catch (e) {
      if (e.toString().contains('No encontramos ningún hogar')) {
        rethrow;
      }
      if (e.toString().contains('relation') ||
          e.toString().contains('does not exist') ||
          e.toString().contains('schema') ||
          e.toString().contains('42P01')) {
        // Respaldo local si aún no se ejecuta el SQL
        final infoLocal = InfoHogarFamiliar(
          id: 'local_join_${codigoLimpio.hashCode}',
          codigo: codigoLimpio,
          nombre: 'Hogar Familiar ($codigoLimpio)',
          esLocalFallback: true,
          miembros: [
            MiembroHogar(
              userId: user.id,
              email: user.email ?? 'Miembro familiar',
              rol: 'miembro',
              unidoEn: DateTime.now(),
            ),
          ],
        );
        _cacheHogar = infoLocal;
        await _guardarCacheLocal(infoLocal);
        return infoLocal;
      }
      rethrow;
    }
  }

  /// Sale del hogar familiar actual y vuelve al modo individual
  static Future<void> salirDeHogar() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('miembros_hogar').delete().eq('user_id', user.id);
      } catch (e) {
        debugPrint('Aviso al salir de hogar en Supabase: $e');
      }
    }
    _cacheHogar = null;
    await _limpiarCacheLocal();
  }

  /// Comparte la invitación con el código por WhatsApp o selector nativo
  static Future<void> compartirInvitacion(InfoHogarFamiliar hogar) async {
    final mensaje =
        '🏠👨‍👩‍👧‍👦 ¡Únete a nuestro Hogar Familiar *"${hogar.nombre}"* en *Jitomate y Cebolla* 🍅🧅!\n\n'
        'Así compartiremos en tiempo real la misma Despensa, Lista del Súper y Planeador Semanal.\n\n'
        '1️⃣ Entra a: https://www.jitomateycebolla.com/\n'
        '2️⃣ Abre *"Mi Despensa"* o el menú lateral y toca *"Hogar Familiar"*.\n'
        '3️⃣ Elige *"Unirme con un código"* y escribe:\n'
        '👉 *${hogar.codigo}*';

    await SharePlus.instance.share(ShareParams(text: mensaje));
  }

  static Future<void> _guardarCacheLocal(InfoHogarFamiliar info) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_keyHogarIdLocal, info.id);
      await sp.setString(_keyHogarCodigoLocal, info.codigo);
      await sp.setString(_keyHogarNombreLocal, info.nombre);
    } catch (_) {}
  }

  static Future<void> _limpiarCacheLocal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_keyHogarIdLocal);
      await sp.remove(_keyHogarCodigoLocal);
      await sp.remove(_keyHogarNombreLocal);
    } catch (_) {}
  }

  static Future<InfoHogarFamiliar?> _leerCacheLocal(User user) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final codigo = sp.getString(_keyHogarCodigoLocal);
      final nombre = sp.getString(_keyHogarNombreLocal);
      final id = sp.getString(_keyHogarIdLocal);
      if (codigo != null && codigo.isNotEmpty) {
        _cacheHogar = InfoHogarFamiliar(
          id: id ?? 'local',
          codigo: codigo,
          nombre: nombre ?? 'Mi Hogar Familiar',
          esLocalFallback: true,
          miembros: [
            MiembroHogar(
              userId: user.id,
              email: user.email ?? 'Miembro',
              rol: 'admin',
            ),
          ],
        );
        return _cacheHogar;
      }
    } catch (_) {}
    return null;
  }
}

/// Banner compacto reutilizable para mostrar en PantallaDespensa y PantallaCarrito
class BannerHogarFamiliar extends StatefulWidget {
  final VoidCallback? onHogarActualizado;

  const BannerHogarFamiliar({
    super.key,
    this.onHogarActualizado,
  });

  @override
  State<BannerHogarFamiliar> createState() => _BannerHogarFamiliarState();
}

class _BannerHogarFamiliarState extends State<BannerHogarFamiliar> {
  InfoHogarFamiliar? _hogar;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool forzar = false}) async {
    final h = await ServicioHogar.obtenerHogarActual(forzarRecarga: forzar);
    if (mounted) {
      setState(() {
        _hogar = h;
        _cargando = false;
      });
    }
  }

  void _abrirModal() async {
    await ModalHogarFamiliar.mostrar(
      context,
      onHogarCambiado: () {
        _cargar(forzar: true);
        widget.onHogarActualizado?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();

    if (_hogar == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.green.shade50],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _abrirModal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Compras y cocinas en familia? 👨‍👩‍👧‍👦',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      Text(
                        'Crea o únete a un Hogar para compartir despensa y lista del súper en vivo.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Vincular',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final numMiembros = _hogar!.miembros.isEmpty ? 1 : _hogar!.miembros.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _abrirModal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _hogar!.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _hogar!.codigo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$numMiembros integrante${numMiembros == 1 ? '' : 's'} • Despensa y Carrito sincronizados en vivo',
                      style: TextStyle(
                        color: Colors.teal.shade50,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                tooltip: 'Invitar familiar por WhatsApp',
                onPressed: () => ServicioHogar.compartirInvitacion(_hogar!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal interactivo completo para crear, unirse o gestionar el Hogar Familiar
class ModalHogarFamiliar {
  static Future<void> mostrar(
    BuildContext context, {
    VoidCallback? onHogarCambiado,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContenidoModalHogar(
        onHogarCambiado: onHogarCambiado,
      ),
    );
  }
}

class _ContenidoModalHogar extends StatefulWidget {
  final VoidCallback? onHogarCambiado;

  const _ContenidoModalHogar({this.onHogarCambiado});

  @override
  State<_ContenidoModalHogar> createState() => _ContenidoModalHogarState();
}

class _ContenidoModalHogarState extends State<_ContenidoModalHogar> {
  InfoHogarFamiliar? _hogar;
  bool _cargando = true;
  bool _procesando = false;

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _codigoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarHogar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarHogar() async {
    setState(() => _cargando = true);
    final h = await ServicioHogar.obtenerHogarActual(forzarRecarga: true);
    if (mounted) {
      setState(() {
        _hogar = h;
        _cargando = false;
      });
    }
  }

  Future<void> _crearHogar() async {
    setState(() => _procesando = true);
    try {
      final info = await ServicioHogar.crearHogar(_nombreCtrl.text);
      if (!mounted) return;
      setState(() {
        _hogar = info;
        _procesando = false;
      });
      widget.onHogarCambiado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Hogar "${info.nombre}" creado con éxito! Código: ${info.codigo} 🎉'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _unirseConCodigo() async {
    final cod = _codigoCtrl.text.trim();
    if (cod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe el código de invitación (ej. CASA-4829).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _procesando = true);
    try {
      final info = await ServicioHogar.unirseAHogar(cod);
      if (!mounted) return;
      setState(() {
        _hogar = info;
        _procesando = false;
      });
      widget.onHogarCambiado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Te uniste al hogar "${info.nombre}"! 🏠👨‍👩‍👧‍👦'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _salirDelHogar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Salir del Hogar Familiar?'),
        content: const Text(
          'Volverás a ver únicamente tu despensa y lista de compras individual. Puedes volver a unirte con el código cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir del hogar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    await ServicioHogar.salirDeHogar();
    if (!mounted) return;
    setState(() {
      _hogar = null;
      _procesando = false;
    });
    widget.onHogarCambiado?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Has vuelto al modo de despensa individual.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: _cargando
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.family_restroom_rounded,
                            color: Colors.teal.shade800,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Despensa Familiar Compartida',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Sincroniza refri, compras y comidas en tiempo real',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_hogar == null)
                      _construirVistaSinHogar()
                    else
                      _construirVistaHogarActivo(_hogar!),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _construirVistaSinHogar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta 1: Unirme con código existente
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.shade50.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.vpn_key_rounded, color: Colors.teal.shade800, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '¿Alguien de tu familia ya creó el Hogar?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Ingresa el código que te compartieron (ej. CASA-4829) para ver y editar la misma despensa y carrito:',
                style: TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codigoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Ej. CASA-4829',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _procesando ? null : _unirseConCodigo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text(
                      'Unirme',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'O CREA UNO NUEVO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        // Tarjeta 2: Crear nuevo hogar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.add_home_work_rounded, color: Colors.red.shade800, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Crear un Nuevo Hogar Familiar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Ponle un nombre a tu hogar y obtén un código único para invitar a tu pareja o familia por WhatsApp.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  hintText: 'Nombre del hogar (ej. Familia Flores / Nuestro Hogar)',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _procesando ? null : _crearHogar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text(
                  'Crear Hogar y Generar Código 🏠',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirVistaHogarActivo(InfoHogarFamiliar hogar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta Principal con Código
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade800, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                hogar.nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Comparte este código con tu familia para vincular sus cuentas:',
                style: TextStyle(
                  color: Colors.teal.shade50,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hogar.codigo,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.copy_rounded, color: Colors.teal.shade800),
                      tooltip: 'Copiar código',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: hogar.codigo));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Código ${hogar.codigo} copiado al portapapeles 📋'),
                            backgroundColor: Colors.teal.shade800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => ServicioHogar.compartirInvitacion(hogar),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Enviar Invitación por WhatsApp 📲',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Lista de miembros conectados
        Text(
          'Integrantes del Hogar (${hogar.miembros.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        ...hogar.miembros.map((m) {
          final esAdmin = m.rol == 'admin';
          return Card(
            elevation: 0,
            color: Colors.grey.shade100,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: esAdmin ? Colors.teal.shade700 : Colors.blueGrey,
                child: Text(
                  m.aliasCorto.isNotEmpty ? m.aliasCorto[0].toUpperCase() : 'F',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                m.email,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esAdmin ? Colors.teal.shade100 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  esAdmin ? 'Creador' : 'Familiar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: esAdmin ? Colors.teal.shade900 : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.sync_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cualquier producto que agregues, escanees en un ticket o taches en el súper se actualiza al instante para todos los miembros.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: _procesando ? null : _salirDelHogar,
          icon: Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 18),
          label: Text(
            'Desvincularme de este Hogar Familiar',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
