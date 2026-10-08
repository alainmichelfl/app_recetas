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

  Future<void> _iniciarSesion() async {
    setState(() => _cargando = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception:', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _registrarCuenta() async {
    setState(() => _cargando = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Por favor llena todos los campos.');
      }

      // Crear usuario nuevo en Supabase
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada! Ahora puedes iniciar sesión. 🎉'),
            backgroundColor: Colors.green,
          ),
        );
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
      setState(() => _cargando = false);
    }
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
                const SizedBox(height: 30),

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

                // 💡 NUEVO BOTÓN: Tutorial / Onboarding
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaInstrucciones(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, color: Colors.grey),
                  label: const Text(
                    '¿Cómo funciona la app?',
                    style: TextStyle(
                      color: Colors.grey,
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
