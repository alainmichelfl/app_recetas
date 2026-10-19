import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_planeador.dart';
// 💡 NUEVO: Importamos la pantalla de instrucciones
import 'pantalla_instrucciones.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;

  final Color colorPrincipal = const Color(
    0xFFE53935,
  ); // Un rojo tomate elegante

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarParametrosDeUrl();
    });
  }

  void _verificarParametrosDeUrl() {
    if (!kIsWeb) return;
    try {
      final fragment = Uri.base.fragment;
      final query = Uri.base.queryParameters;

      if (fragment.contains('error=') || query.containsKey('error')) {
        String desc = '';
        if (query.containsKey('error_description')) {
          desc = query['error_description']!;
        } else if (fragment.contains('error_description=')) {
          final match = RegExp(r'error_description=([^&]+)').firstMatch(fragment);
          if (match != null) {
            desc = Uri.decodeComponent(match.group(1)!.replaceAll('+', ' '));
          }
        }

        final lowerDesc = desc.toLowerCase();
        if (lowerDesc.contains('expired') || lowerDesc.contains('otp_expired')) {
          _mostrarDialogoErrorEnlace(
            'El enlace de verificación ha expirado.\n\n'
            'Por favor ingresa tu correo y solicita un nuevo enlace con el botón "Reenviar correo de verificación".',
          );
        } else if (lowerDesc.contains('invalid') || lowerDesc.contains('access_denied')) {
          _mostrarDialogoErrorEnlace(
            'El enlace de verificación es inválido o ya fue utilizado anteriormente.\n\n'
            'Si ya confirmaste tu cuenta, puedes iniciar sesión directamente con tu contraseña.',
          );
        } else if (desc.isNotEmpty) {
          _mostrarDialogoErrorEnlace('Aviso de autenticación: $desc');
        }
      } else if (fragment.contains('type=recovery') || query['type'] == 'recovery') {
        // Enlace de recuperación de contraseña: es procesado por ControladorSesion / PantallaRestablecerPassword
      } else if (fragment.contains('type=signup') || (fragment.contains('access_token') && !fragment.contains('type=recovery'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Muchas gracias por registrarte y autenticarte! Tu cuenta está lista 🎉🍅🧅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {}
  }

  void _mostrarDialogoErrorEnlace(String mensaje) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Verificación de correo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrincipal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _obtenerUrlRedireccion() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        final path = Uri.base.path.isEmpty ? '/' : Uri.base.path;
        return '$origin$path';
      }
      return 'https://www.jitomateycebolla.com/';
    }
    return 'https://www.jitomateycebolla.com/';
  }

  Future<void> _iniciarSesion() async {
    setState(() => _cargando = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Por favor llena todos los campos.');
      }

      // Autenticación con Supabase
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Si todo sale bien, lo mandamos al planeador
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PantallaPlaneador()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();

      if (errStr.contains('email not confirmed') || errStr.contains('email_not_confirmed')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.mail_lock_outlined, color: colorPrincipal, size: 28),
                const SizedBox(width: 10),
                const Text('Verifica tu correo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aún no has activado tu cuenta. Debes hacer clic en el enlace enviado a:',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 14.5),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    email,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '💡 Revisa también tu carpeta de Spam o Correo no deseado si no lo encuentras.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _reenviarCorreoConfirmacion(email);
                },
                child: const Text('Reenviar enlace'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrincipal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else if (errStr.contains('invalid login credentials') || errStr.contains('invalid_credentials')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo o contraseña incorrectos. Por favor verifica tus datos.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al iniciar sesión: ${e.toString().replaceAll('Exception:', '').replaceAll('AuthApiException', '').replaceAll('(', '').replaceAll(')', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _registrarCuenta() async {
    setState(() => _cargando = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Por favor llena todos los campos.');
      }

      if (password.length < 6) {
        throw Exception('La contraseña debe tener al menos 6 caracteres.');
      }

      // Crear usuario nuevo en Supabase con URL de redirección explícita
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _obtenerUrlRedireccion(),
      );

      if (!mounted) return;

      // Si Supabase no requiere confirmación de correo o auto-inició sesión
      if (res.session != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PantallaPlaneador()),
        );
      } else if (res.user != null) {
        if (res.user!.identities != null && res.user!.identities!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este correo ya está registrado. Inicia sesión o restablece tu contraseña.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          // Requiere confirmación por correo: mostrar modal explicativo claro
          _mostrarModalVerificacionPendiente(email);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al registrar: ${e.toString().replaceAll('Exception:', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _mostrarModalVerificacionPendiente(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mark_email_unread_outlined, size: 50, color: colorPrincipal),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Muchas gracias por registrarte! 🍅🧅',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nos alegra tenerte aquí. Para completar tu autenticación, hemos enviado un enlace de activación a:',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14.5),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                email,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Para poder iniciar sesión, primero debes hacer clic en el enlace de verificación que llegó a tu correo.',
                    style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si no lo ves en 1 o 2 minutos, revisa tu carpeta de Spam o Correo no deseado.',
                      style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reenviarCorreoConfirmacion(email);
            },
            child: const Text('Reenviar correo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrincipal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entendido / Iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _reenviarCorreoConfirmacion(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa tu correo para reenviar la confirmación.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _obtenerUrlRedireccion(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Correo de activación reenviado a $email! 📨 Revisa también Spam.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo reenviar: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _olvidePassword() async {
    final email = _emailController.text.trim();
    final ctrl = TextEditingController(text: email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Recuperar contraseña 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa tu correo y te enviaremos un enlace oficial para restablecer tu contraseña:\n\n'
              '💡 Nota: El enlace es de un solo uso. Si solicitas más de un correo, asegúrate de abrir únicamente el último recibido.',
              style: TextStyle(fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final em = ctrl.text.trim();
              if (em.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  em,
                  redirectTo: _obtenerUrlRedireccion(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Se envió un enlace para restablecer tu contraseña a $em. Revisa tu correo.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrincipal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Un ícono de cocina como logo
                Icon(Icons.restaurant_menu, size: 100, color: colorPrincipal),
                const SizedBox(height: 20),

                const Text(
                  'Bienvenido a',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Jitomate y Cebolla',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorPrincipal,
                  ),
                ),
                const SizedBox(height: 40),

                // Campo de Correo
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo de Contraseña
                TextField(
                  controller: _passwordController,
                  obscureText: true, // Oculta los caracteres
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Olvidé mi contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _cargando ? null : _olvidePassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón Principal
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _cargando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 15),

                // Botón Secundario (Registrarse)
                TextButton(
                  onPressed: _cargando ? null : _registrarCuenta,
                  child: Text(
                    '¿No tienes cuenta? Regístrate aquí',
                    style: TextStyle(color: colorPrincipal, fontSize: 16),
                  ),
                ),

                const SizedBox(height: 10),

                // 💡 BOTÓN: Guía Oficial y Pilares
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaInstrucciones(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFFFB300), size: 20),
                  label: const Text(
                    '¿Cómo funciona la app? Conoce los Pilares ✨',
                    style: TextStyle(
                      color: Color(0xFFFFB300),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
