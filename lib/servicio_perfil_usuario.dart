import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de validación de disponibilidad de nombre de usuario
class ResultadoDisponibilidadNombre {
  final bool disponible;
  final String mensaje;
  final List<String> sugerencias;

  const ResultadoDisponibilidadNombre({
    required this.disponible,
    required this.mensaje,
    this.sugerencias = const [],
  });
}

/// Servicio centralizado para gestionar el nombre de usuario,
/// saludos dinámicos según el horario, disponibilidad y sugerencias si está ocupado.
class ServicioPerfilUsuario {
  static const String keyNombreUsuario = 'pref_nombre_usuario_v1';
  static String? _nombreEnMemoria;

  /// Extrae un nombre de pila legible y amigable a partir del correo electrónico
  static String extraerNombreDeEmail(String? email) {
    if (email == null || email.trim().isEmpty) return 'Chef';
    final raw = email.split('@').first.trim();
    if (raw.isEmpty) return 'Chef';

    // Dividir por puntos, guiones o guiones bajos
    final partes = raw.split(RegExp(r'[\._\-]')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return 'Chef';

    String primero = partes.first;
    // Si contiene números al final, removerlos para dejar el nombre limpio
    primero = primero.replaceAll(RegExp(r'\d+$'), '');
    if (primero.isEmpty) primero = partes.first;

    // Si es alainmichel o similar
    if (primero.toLowerCase() == 'alainmichel') return 'Alain Michel';

    // Si tiene más de una parte y ambas son nombres legibles (ej. alain.michel)
    if (partes.length >= 2 && partes[1].length > 1 && !RegExp(r'^\d+$').hasMatch(partes[1])) {
      final segundo = partes[1].replaceAll(RegExp(r'\d+$'), '');
      if (segundo.isNotEmpty && segundo.length > 2) {
        return '${primero[0].toUpperCase()}${primero.substring(1).toLowerCase()} ${segundo[0].toUpperCase()}${segundo.substring(1).toLowerCase()}';
      }
    }

    return primero[0].toUpperCase() + primero.substring(1).toLowerCase();
  }

  /// Obtiene de forma síncrona el nombre en memoria o inferido del usuario actual
  static String obtenerNombreSincrono() {
    if (_nombreEnMemoria != null && _nombreEnMemoria!.trim().isNotEmpty) {
      return _nombreEnMemoria!.trim();
    }
    final user = Supabase.instance.client.auth.currentUser;
    final metaName = user?.userMetadata?['nombre_usuario']?.toString() ??
        user?.userMetadata?['nombre']?.toString() ??
        user?.userMetadata?['displayName']?.toString();
    if (metaName != null && metaName.trim().isNotEmpty) {
      _nombreEnMemoria = metaName.trim();
      return _nombreEnMemoria!;
    }
    return extraerNombreDeEmail(user?.email);
  }

  /// Obtiene de forma asíncrona el nombre de usuario persistido (SharedPreferences / Supabase)
  static Future<String> obtenerNombreUsuario() async {
    if (_nombreEnMemoria != null && _nombreEnMemoria!.trim().isNotEmpty) {
      return _nombreEnMemoria!.trim();
    }

    try {
      final sp = await SharedPreferences.getInstance();
      final guardado = sp.getString(keyNombreUsuario);
      if (guardado != null && guardado.trim().isNotEmpty) {
        _nombreEnMemoria = guardado.trim();
        return _nombreEnMemoria!;
      }
    } catch (e) {
      debugPrint('Error leyendo nombre en SharedPreferences: $e');
    }

    final user = Supabase.instance.client.auth.currentUser;
    final metaName = user?.userMetadata?['nombre_usuario']?.toString() ??
        user?.userMetadata?['nombre']?.toString() ??
        user?.userMetadata?['displayName']?.toString();

    if (metaName != null && metaName.trim().isNotEmpty) {
      _nombreEnMemoria = metaName.trim();
      // Respaldar localmente
      try {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(keyNombreUsuario, _nombreEnMemoria!);
      } catch (_) {}
      return _nombreEnMemoria!;
    }

    final nombrePorEmail = extraerNombreDeEmail(user?.email);
    _nombreEnMemoria = nombrePorEmail;
    return nombrePorEmail;
  }

  /// Saludo dinámico y cálido de acuerdo con el momento del día
  static String obtenerSaludoHorario({String? nombre, DateTime? horaReferencia}) {
    final nom = (nombre != null && nombre.trim().isNotEmpty)
        ? nombre.trim()
        : obtenerNombreSincrono();
    final hora = (horaReferencia ?? DateTime.now()).hour;

    if (hora >= 5 && hora < 12) {
      return '¡Buenos días, $nom! ☀️';
    } else if (hora >= 12 && hora < 19) {
      return '¡Buenas tardes, $nom! 🍲';
    } else {
      return '¡Buenas noches, $nom! 🌙';
    }
  }

  /// Subtítulo motivacional acorde al horario culinario
  static String obtenerSubtituloHorario({DateTime? horaReferencia}) {
    final hora = (horaReferencia ?? DateTime.now()).hour;

    if (hora >= 5 && hora < 12) {
      return '¿Qué desayunamos hoy? Prepara algo fresco y lleno de energía.';
    } else if (hora >= 12 && hora < 19) {
      return '¿Listo para cocinar? Explora tus recetas o inventa con Chef IA.';
    } else {
      return '¿Listos para cenar? Prepara algo ligero, nutritivo y a descansar.';
    }
  }

  /// Verifica si un nombre de usuario está libre o si ya pertenece a otra persona
  static Future<ResultadoDisponibilidadNombre> verificarDisponibilidad(
    String nombrePropuesto,
  ) async {
    final limpio = nombrePropuesto.trim();

    if (limpio.isEmpty) {
      return const ResultadoDisponibilidadNombre(
        disponible: false,
        mensaje: 'Por favor escribe cómo te gustaría que te llamemos.',
        sugerencias: [],
      );
    }

    if (limpio.length < 2) {
      return const ResultadoDisponibilidadNombre(
        disponible: false,
        mensaje: 'El nombre debe tener al menos 2 caracteres.',
        sugerencias: [],
      );
    }

    if (limpio.length > 25) {
      return const ResultadoDisponibilidadNombre(
        disponible: false,
        mensaje: 'El nombre no puede tener más de 25 caracteres.',
        sugerencias: [],
      );
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUid = currentUser?.id;

    // Si coincide con su propio nombre ya en memoria o guardado, es válido
    if (_nombreEnMemoria != null &&
        limpio.toLowerCase() == _nombreEnMemoria!.toLowerCase()) {
      return const ResultadoDisponibilidadNombre(
        disponible: true,
        mensaje: '¡Es tu nombre actual!',
        sugerencias: [],
      );
    }

    // Consulta en Supabase a la tabla `nombres_usuario`
    try {
      final res = await Supabase.instance.client
          .from('nombres_usuario')
          .select('user_id, nombre_usuario')
          .ilike('nombre_usuario', limpio)
          .maybeSingle();

      if (res != null) {
        final ocupanteUid = res['user_id']?.toString();
        // Si el registro le pertenece al mismo usuario, está disponible para él
        if (ocupanteUid != null && ocupanteUid == currentUid) {
          return const ResultadoDisponibilidadNombre(
            disponible: true,
            mensaje: '¡Es tu nombre registrado!',
            sugerencias: [],
          );
        } else {
          // Asignado a otra persona -> Generar un par de sugerencias
          final sugerencias = await generarSugerencias(limpio);
          return ResultadoDisponibilidadNombre(
            disponible: false,
            mensaje: 'Este nombre ya está asignado a otra persona.',
            sugerencias: sugerencias,
          );
        }
      }
    } catch (e) {
      debugPrint('Nota al verificar nombres_usuario en Supabase: $e');
    }

    return const ResultadoDisponibilidadNombre(
      disponible: true,
      mensaje: '¡Nombre disponible!',
      sugerencias: [],
    );
  }

  /// Genera alternativas atractivas y libres si el nombre ya está ocupado
  static Future<List<String>> generarSugerencias(String base) async {
    final baseLimpia = base.trim().replaceAll(RegExp(r'\s+'), '');
    final int anio = DateTime.now().year % 100;

    final candidatos = <String>[
      'Chef$baseLimpia',
      '${baseLimpia}_$anio',
      '${baseLimpia}Cocina',
      '${baseLimpia}_Gourmet',
      '${baseLimpia}Express',
    ];

    try {
      final res = await Supabase.instance.client
          .from('nombres_usuario')
          .select('nombre_usuario')
          .inFilter('nombre_usuario', candidatos);

      final ocupados = (res as List)
          .map((r) => r['nombre_usuario']?.toString().toLowerCase())
          .whereType<String>()
          .toSet();

      final libres = candidatos
          .where((c) => !ocupados.contains(c.toLowerCase()))
          .take(3)
          .toList();

      if (libres.isNotEmpty) return libres;
    } catch (_) {}

    return candidatos.take(3).toList();
  }

  /// Guarda y actualiza el nombre del usuario en memoria local y en Supabase
  static Future<bool> guardarNombreUsuario(String nuevoNombre) async {
    final limpio = nuevoNombre.trim();
    if (limpio.isEmpty || limpio.length < 2) return false;

    _nombreEnMemoria = limpio;

    // 1. Guardar localmente en SharedPreferences para lectura instantánea (0ms)
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(keyNombreUsuario, limpio);
    } catch (e) {
      debugPrint('Error guardando nombre en SharedPreferences: $e');
    }

    // 2. Guardar en UserMetadata de Supabase Auth
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {
            'nombre_usuario': limpio,
            'nombre': limpio,
          }),
        );
      } catch (e) {
        debugPrint('Error actualizando metadata en Supabase: $e');
      }

      // 3. Upsert en tabla `nombres_usuario`
      try {
        await Supabase.instance.client.from('nombres_usuario').upsert({
          'nombre_usuario': limpio,
          'user_id': user.id,
          'actualizado_en': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Nota al registrar en nombres_usuario: $e');
      }
    }

    return true;
  }

  /// Despliega un diálogo elegante para cambiar o registrar el nombre de usuario
  static Future<void> mostrarDialogoEditarNombre(
    BuildContext context, {
    VoidCallback? alGuardar,
  }) async {
    final nombreActual = await obtenerNombreUsuario();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => _DialogoEditorNombre(
        nombreInicial: nombreActual,
        alGuardar: alGuardar,
      ),
    );
  }
}

class _DialogoEditorNombre extends StatefulWidget {
  final String nombreInicial;
  final VoidCallback? alGuardar;

  const _DialogoEditorNombre({
    required this.nombreInicial,
    this.alGuardar,
  });

  @override
  State<_DialogoEditorNombre> createState() => _DialogoEditorNombreState();
}

class _DialogoEditorNombreState extends State<_DialogoEditorNombre> {
  late final TextEditingController _controller;
  ResultadoDisponibilidadNombre? _resultado;
  bool _validando = false;
  bool _guardando = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nombreInicial);
    _verificarNombre(widget.nombreInicial);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _verificarNombre(text);
    });
  }

  Future<void> _verificarNombre(String text) async {
    if (!mounted) return;
    setState(() => _validando = true);
    final res = await ServicioPerfilUsuario.verificarDisponibilidad(text);
    if (!mounted) return;
    setState(() {
      _resultado = res;
      _validando = false;
    });
  }

  Future<void> _guardar() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _guardando = true);
    final res = await ServicioPerfilUsuario.verificarDisponibilidad(text);

    if (!res.disponible) {
      if (mounted) {
        setState(() {
          _resultado = res;
          _guardando = false;
        });
      }
      return;
    }

    await ServicioPerfilUsuario.guardarNombreUsuario(text);
    if (!mounted) return;

    widget.alGuardar?.call();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Listo! Ahora te llamaremos $text 👨‍🍳✨'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esValido = _resultado?.disponible ?? false;

    return Dialog(
      backgroundColor: const Color(0xFF1E2022),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFFD32F2F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '¿Cómo te gustaría que te llamemos?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tu nombre o apodo nos permite saludarte con calidez al abrir la app y personalizar tus recetas.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Tu Nombre de Chef / Apodo',
                labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFD32F2F)),
                suffixIcon: _validando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                      )
                    : Icon(
                        esValido ? Icons.check_circle : Icons.error_outline,
                        color: esValido ? const Color(0xFF2E7D32) : Colors.amber,
                      ),
                filled: true,
                fillColor: const Color(0xFF282B30),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: esValido ? const Color(0xFF2E7D32) : Colors.white24,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Mensaje de estado
            if (_resultado != null)
              Row(
                children: [
                  Icon(
                    esValido ? Icons.check_circle : Icons.info_outline,
                    size: 14,
                    color: esValido ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _resultado!.mensaje,
                      style: TextStyle(
                        fontSize: 12,
                        color: esValido
                            ? const Color(0xFF81C784)
                            : const Color(0xFFFFB74D),
                      ),
                    ),
                  ),
                ],
              ),

            // Sugerencias si el nombre está ocupado
            if (_resultado != null && !_resultado!.disponible && _resultado!.sugerencias.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Sugerencias disponibles:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _resultado!.sugerencias.map((sug) {
                  return ActionChip(
                    label: Text(sug),
                    avatar: const Icon(Icons.add, size: 14, color: Colors.amber),
                    backgroundColor: const Color(0xFF2A2D35),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.amber, width: 0.8),
                    ),
                    onPressed: () {
                      _controller.text = sug;
                      _verificarNombre(sug);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_guardando || !esValido) ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar Nombre', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
