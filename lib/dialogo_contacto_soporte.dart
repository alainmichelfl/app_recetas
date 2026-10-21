import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal interactivo de Contacto y Soporte Oficial de Jitomate y Cebolla.
/// Muestra los correos corporativos oficiales (@jitomateycebolla.com)
/// con opciones para enviar correo directo o copiar al portapapeles.
class DialogoContactoSoporte extends StatelessWidget {
  const DialogoContactoSoporte({super.key});

  static Future<void> mostrar(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const DialogoContactoSoporte(),
    );
  }

  static const String emailHola = 'hola@jitomateycebolla.com';
  static const String emailContacto = 'contacto@jitomateycebolla.com';
  static const String emailAlain = 'alain@jitomateycebolla.com';
  static const String sitioWeb = 'https://www.jitomateycebolla.com';

  /// Abre un chat de WhatsApp con un mensaje precargado en 1 toque.
  /// Si WhatsApp no está disponible, comparte mediante el diálogo nativo o portapapeles.
  static Future<void> abrirWhatsAppFeedback(
    BuildContext context, {
    String? mensajePersonalizado,
  }) async {
    final mensaje = mensajePersonalizado ??
        '¡Hola Chef Alain! Estuve probando Jitomate y Cebolla (www.jitomateycebolla.com) y quiero compartirte mi experiencia / sugerencia: ';
    final urlWhatsApp = 'https://wa.me/?text=${Uri.encodeComponent(mensaje)}';
    final uri = Uri.parse(urlWhatsApp);

    try {
      final lanzado = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!lanzado && context.mounted) {
        await SharePlus.instance.share(ShareParams(text: mensaje));
      }
    } catch (_) {
      try {
        await SharePlus.instance.share(ShareParams(text: mensaje));
      } catch (_) {
        if (context.mounted) {
          _copiarAlPortapapeles(context, mensaje);
        }
      }
    }
  }

  static Future<void> _enviarCorreo(
    BuildContext context,
    String email, {
    String asunto = 'Consulta sobre Jitomate y Cebolla 🍅🧅',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': asunto,
      },
    );

    try {
      final lanzado = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!lanzado && context.mounted) {
        _copiarAlPortapapeles(context, email);
      }
    } catch (_) {
      if (context.mounted) {
        _copiarAlPortapapeles(context, email);
      }
    }
  }

  static void _copiarAlPortapapeles(BuildContext context, String email) {
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copiado al portapapeles: $email',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<void> _abrirSitioWeb(BuildContext context) async {
    final uri = Uri.parse(sitioWeb);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        _copiarAlPortapapeles(context, sitioWeb);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final esPantallaPequena = size.width < 400;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF16161A),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado con Isotipo
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE53935).withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon_3a_ruby_glow.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFE53935),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jitomate y Cebolla',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Canales Oficiales de Contacto',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD54F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                '¿Tienes dudas, sugerencias o quieres colaborar con nosotros? Elige el canal adecuado para escribirnos:',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Lista de Contactos
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _construirTarjetaWhatsApp(
                        context,
                        esPantallaPequena: esPantallaPequena,
                      ),
                      const SizedBox(height: 10),
                      _construirTarjetaCorreo(
                        context,
                        icono: Icons.waving_hand_rounded,
                        colorIcono: const Color(0xFF42A5F5),
                        titulo: 'Hola & Comunidad',
                        subtitulo: 'Dudas generales, bienvenida y sugerencias para la app.',
                        email: emailHola,
                        esPantallaPequena: esPantallaPequena,
                      ),
                      const SizedBox(height: 10),
                      _construirTarjetaCorreo(
                        context,
                        icono: Icons.support_agent_rounded,
                        colorIcono: const Color(0xFF66BB6A),
                        titulo: 'Soporte Técnico & Cuenta',
                        subtitulo: 'Reporte de fallas, sincronización o ayuda con tu usuario.',
                        email: emailContacto,
                        esPantallaPequena: esPantallaPequena,
                      ),
                      const SizedBox(height: 10),
                      _construirTarjetaCorreo(
                        context,
                        icono: Icons.verified_user_rounded,
                        colorIcono: const Color(0xFFFFA726),
                        titulo: 'Alain Michel (Fundador)',
                        subtitulo: 'Alianzas, negocios, nutrición B2B y feedback directo.',
                        email: emailAlain,
                        esPantallaPequena: esPantallaPequena,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // Pie de Diálogo con Sitio Web
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _abrirSitioWeb(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              size: 16,
                              color: Color(0xFF90CAF9),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'www.jitomateycebolla.com',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF90CAF9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'v1.0.0 • PWA',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirTarjetaWhatsApp(
    BuildContext context, {
    required bool esPantallaPequena,
  }) {
    const Color colorWa = Color(0xFF25D366);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2621),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorWa.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorWa.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: colorWa, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Danos tu Opinión por WhatsApp 💬',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorWa.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '1 Toque ⚡',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorWa,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Escríbenos directamente para compartir tu opinión, sugerir nuevas funciones o reportar cualquier error.',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorWa,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                'Abrir WhatsApp con mensaje listo 📱',
                style: GoogleFonts.poppins(
                  fontSize: esPantallaPequena ? 11.5 : 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                abrirWhatsAppFeedback(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaCorreo(
    BuildContext context, {
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String subtitulo,
    required String email,
    required bool esPantallaPequena,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222228),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorIcono.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorIcono, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            subtitulo,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    email,
                    style: GoogleFonts.firaCode(
                      color: const Color(0xFFFFD54F),
                      fontSize: esPantallaPequena ? 11.5 : 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: Colors.white70,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copiar correo',
                  onPressed: () => _copiarAlPortapapeles(context, email),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  color: colorIcono,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Enviar mensaje',
                  onPressed: () => _enviarCorreo(
                    context,
                    email,
                    asunto: 'Contacto desde App: $titulo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
