import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio centralizado de permisos y control de acceso administrativo.
/// Protege funciones críticas de mantenimiento en base de datos, saneamiento y costos de IA.
class ServicioAdmin {
  ServicioAdmin._();

  /// Lista autorizada de correos con rol de Administrador
  static const Set<String> _correosAdmin = {
    'alainmichel.fl@gmail.com',
  };

  /// Determina si el usuario autenticado (o el [usuario] indicado) tiene permisos de Administrador.
  static bool esAdmin([User? usuario]) {
    final user = usuario ?? Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final email = user.email?.trim().toLowerCase();
    if (email != null && _correosAdmin.contains(email)) {
      return true;
    }

    // También admite asignación de rol 'admin' en metadata de Supabase Auth
    final role = user.appMetadata['role'] ?? user.userMetadata?['role'];
    if (role == 'admin') return true;

    return false;
  }
}
