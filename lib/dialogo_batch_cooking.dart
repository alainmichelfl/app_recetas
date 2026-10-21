import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servicio_batch_cooking.dart';
import 'servicio_carrito_offline.dart';

/// Modal interactivo para ejecutar la sesión de Batch Cooking dominical
class DialogoBatchCooking extends StatefulWidget {
  final List<dynamic> planSemanal;
  final String objetivoNutricional;

  const DialogoBatchCooking({
    super.key,
    required this.planSemanal,
    this.objetivoNutricional = 'Mantenimiento',
  });

  /// Muestra el modal con la guía de Batch Cooking
  static Future<void> mostrar(
    BuildContext context, {
    required List<dynamic> planSemanal,
    String objetivoNutricional = 'Mantenimiento',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DialogoBatchCooking(
        planSemanal: planSemanal,
        objetivoNutricional: objetivoNutricional,
      ),
    );
  }

  @override
  State<DialogoBatchCooking> createState() => _DialogoBatchCookingState();
}

class _DialogoBatchCookingState extends State<DialogoBatchCooking> {
  late GuiaBatchCookingSemanal _guia;
  final Set<String> _tareasCompletadas = {};
  bool _generandoIA = false;

  // Temporizador para bloque activo (30 minutos = 1800 segundos)
  Timer? _timer;
  int _segundosRestantes = 1800;
  bool _timerCorriendo = false;
  int _bloqueTimerActivo = 1;

  @override
  void initState() {
    super.initState();
    _guia = ServicioBatchCooking.generarGuiaDesdePlan(widget.planSemanal);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarPausarTimer(int bloque) {
    if (_timerCorriendo && _bloqueTimerActivo == bloque) {
      _timer?.cancel();
      setState(() => _timerCorriendo = false);
    } else {
      if (_bloqueTimerActivo != bloque) {
        _timer?.cancel();
        _segundosRestantes = 1800; // Reinicia a 30 min para el nuevo bloque
        _bloqueTimerActivo = bloque;
      }
      _timerCorriendo = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_segundosRestantes > 0) {
          setState(() => _segundosRestantes--);
        } else {
          timer.cancel();
          setState(() => _timerCorriendo = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏰ ¡Bloque $_bloqueTimerActivo completado! Pasa al siguiente paso 👨‍🍳🔥'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      });
      setState(() {});
    }
  }

  void _reiniciarTimer() {
    _timer?.cancel();
    setState(() {
      _timerCorriendo = false;
      _segundosRestantes = 1800;
    });
  }

  String _formatearTiempo(int seg) {
    final m = (seg ~/ 60).toString().padLeft(2, '0');
    final s = (seg % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _regenerarConIA() async {
    setState(() => _generandoIA = true);
    try {
      final nuevaGuia = await ServicioBatchCooking.generarGuiaConIA(
        planSemanal: widget.planSemanal,
        objetivo: widget.objetivoNutricional,
      );
      if (mounted) {
        setState(() {
          _guia = nuevaGuia;
          _tareasCompletadas.clear();
          _generandoIA = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ ¡Guía de Batch Cooking optimizada con Chef IA! 👨‍🍳'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _generandoIA = false);
    }
  }

  Future<void> _compartirPorWhatsApp() async {
    final texto = _guia.formatearParaCompartir();
    await SharePlus.instance.share(ShareParams(text: texto));
  }

  void _mostrarModalCompraMayoreo() {
    final items = ServicioBatchCooking.generarListaMayoreo(_guia);
    final textoParaCompartir = ServicioBatchCooking.formatearListaMayoreoParaCompartir(items);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: Colors.indigo, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compra al Mayoreo & Club 🥫',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                          ),
                          Text(
                            'Costco, Sam\'s Club & Central • Ahorro estimado ~32%',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF242628)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.indigo.withValues(alpha: 0.18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  it.nombreIngrediente,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Ahorro ~${it.ahorroPorcentual.toInt()}%',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.storefront, size: 14, color: Colors.indigo),
                              const SizedBox(width: 4),
                              Text(it.tiendaRecomendada, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.indigo)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('🛒 Menudeo: ${it.presentacionMenudeo}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                          Text('📦 Mayoreo: ${it.presentacionMayoreo}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.tips_and_updates_outlined, size: 14, color: Colors.amber.shade900),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    it.tipConservacion,
                                    style: TextStyle(fontSize: 11, color: Colors.brown.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -3))],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF25D366),
                            side: const BorderSide(color: Color(0xFF25D366)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share, size: 17),
                          label: const Text('WhatsApp 📱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharePlus.instance.share(ShareParams(text: textoParaCompartir));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 17),
                          label: const Text('Al Carrito 🛒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              final user = Supabase.instance.client.auth.currentUser;
                              for (var it in items) {
                                await Supabase.instance.client.from('lista_compras').insert({
                                  'nombre': '${it.presentacionMayoreo} (${it.nombreIngrediente})',
                                  'cantidad': 1,
                                  'comprado': false,
                                  'user_id': user?.id,
                                });
                              }
                              await ServicioCarritoOffline.invalidarCache();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('¡Productos de mayoreo agregados a tu Lista de Compras! 🛒✨'),
                                  backgroundColor: Colors.indigo,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              Clipboard.setData(ClipboardData(text: textoParaCompartir));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lista de mayoreo copiada al portapapeles 📋'),
                                  backgroundColor: Colors.blueGrey,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalTareas = _guia.etapas.fold<int>(0, (acc, e) => acc + e.tareas.length);
    final int completadas = _tareasCompletadas.length;
    final double progreso = totalTareas > 0 ? (completadas / totalTareas) : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Asa superior de arrastre
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Encabezado principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.soup_kitchen, color: Colors.deepOrange, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Batch Cooking Dominical 🍱',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Guía de 2 Horas • ${_guia.totalPlatillos} comidas agendadas',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Contenido con scroll
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                children: [
                  // Barra de progreso interactiva
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9), // Verde muy claro
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.checklist_rtl_rounded, color: Colors.green.shade800, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Progreso de Preparación',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$completadas de $totalTareas tareas (${(progreso * 100).toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progreso,
                            minHeight: 8,
                            backgroundColor: Colors.green.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Temporizador flotante de bloque
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2022),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 22),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cronómetro Bloque $_bloqueTimerActivo',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                Text(
                                  _formatearTiempo(_segundosRestantes),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay, color: Colors.white70, size: 20),
                              tooltip: 'Reiniciar a 30m',
                              onPressed: _reiniciarTimer,
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _timerCorriendo ? Colors.orange : Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(_timerCorriendo ? Icons.pause : Icons.play_arrow, size: 18),
                              label: Text(_timerCorriendo ? 'Pausar' : 'Iniciar 30m'),
                              onPressed: () => _iniciarPausarTimer(_bloqueTimerActivo),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Los 4 bloques de 30 minutos
                  ..._guia.etapas.map((etapa) => _construirTarjetaEtapa(etapa)),

                  const SizedBox(height: 10),

                  // Reglas de conservación
                  _construirSeccionReglasConservacion(),

                  const SizedBox(height: 20),

                  // Botones de acción inferiores
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: const Text(
                          'Mayoreo & Club (Costco / Central) 🥫',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _mostrarModalCompraMayoreo,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'Compartir por WhatsApp 📱',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _compartirPorWhatsApp,
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(color: Colors.deepOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _generandoIA
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(_generandoIA ? 'Optimizando...' : 'Personalizar con Chef IA ✨'),
                        onPressed: _generandoIA ? null : _regenerarConIA,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaEtapa(EtapaBatchCooking etapa) {
    final bool esBloqueActivo = _bloqueTimerActivo == etapa.bloqueNumero;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esBloqueActivo ? etapa.color : Colors.grey.withValues(alpha: 0.25),
          width: esBloqueActivo ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: etapa.bloqueNumero == 1,
          leading: CircleAvatar(
            backgroundColor: etapa.color.withValues(alpha: 0.15),
            foregroundColor: etapa.color,
            child: Icon(etapa.icono, size: 22),
          ),
          title: Text(
            '${etapa.tiempoEstimado} • ${etapa.titulo}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            etapa.subtitulo,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: IconButton(
            icon: Icon(
              esBloqueActivo && _timerCorriendo ? Icons.pause_circle_filled : Icons.play_circle_outline,
              color: etapa.color,
            ),
            tooltip: 'Medir este bloque',
            onPressed: () => _iniciarPausarTimer(etapa.bloqueNumero),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  ...etapa.tareas.map((tarea) {
                    final bool hecha = _tareasCompletadas.contains(tarea);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (hecha) {
                            _tareasCompletadas.remove(tarea);
                          } else {
                            _tareasCompletadas.add(tarea);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              hecha ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 20,
                              color: hecha ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tarea,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  decoration: hecha ? TextDecoration.lineThrough : null,
                                  color: hecha ? Colors.grey : Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (etapa.tips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              etapa.tips.first,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.brown.shade900,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSeccionReglasConservacion() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Azul suave
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ac_unit, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'Reglas de Oro de Conservación ❄️',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._guia.reglasConservacion.map(
            (regla) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  Expanded(
                    child: Text(
                      regla,
                      style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
