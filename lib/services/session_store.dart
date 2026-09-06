import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the signed-in user across app launches ("stay logged in").
///
/// There is no auth token in this build — [ApiService] endpoints are
/// unauthenticated — so all this keeps is the `user` map that
/// `csdo_api/login.php` (or `verify_email.php`) returns: `employee_id`,
/// `full_name`, `email`, `department`, `email_verified`. That's enough for
/// [AppShell]/[ProfileScreen] to render and to prefill new requests.
/// Cleared on explicit log out.
class SessionStore {
  SessionStore._();

  static const _key = 'session_user';

  /// Saves [user] so the next launch can skip the login screen.
  static Future<void> save(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user));
  }

  /// The stored user, or null if nobody is signed in (or the stored blob is
  /// somehow unreadable — treated the same as "signed out").
  static Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Forgets the current session (log out).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
