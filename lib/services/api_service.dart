import 'dart:convert';
import 'package:http/http.dart' as http;

/// Talks to the csdo_api PHP backend.
///
/// Base URL notes:
/// - Android emulator: localhost on your PC is reachable at 10.0.2.2
/// - iOS simulator: localhost works as-is
/// - Physical phone on the same WiFi: use your PC's LAN IP, e.g. 192.168.1.x
/// - Flutter web (run from the same machine): localhost works as-is
class ApiService {
  // Set at build/run time with --dart-define, so you don't have to hand-edit
  // this file every time you switch devices. Falls back to the Android
  // emulator address (10.0.2.2) if nothing is passed.
  //
  // Examples:
  //   Android emulator (default, no flag needed):
  //     flutter run
  //   Physical phone / iOS simulator / Flutter web on your LAN:
  //     flutter run --dart-define=API_HOST=192.168.1.23
  //   Using ngrok or a real domain:
  //     flutter run --dart-define=API_HOST=https://a1b2c3.ngrok-free.app --dart-define=API_SCHEME=
  static const String _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.0.2.2',
  );

  // Lets a full https:// URL (ngrok, real domain) be passed via API_HOST
  // without doubling up the scheme. Leave API_SCHEME as-is for plain LAN IPs.
  static const String _scheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'http://',
  );

  static String get baseUrl =>
      _host.startsWith('http') ? '$_host/csdo_api' : '$_scheme$_host/csdo_api';

  /// Logs in with employee ID + password.
  /// Returns the user map on success, throws on failure.
  static Future<Map<String, dynamic>> login({
    required String employeeId,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employee_id': employeeId,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    } else {
      throw Exception(body['error'] ?? 'Login failed');
    }
  }

  /// Registers a new account.
  static Future<void> register({
    required String employeeId,
    required String fullName,
    required String email,
    required String department,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employee_id': employeeId,
        'full_name': fullName,
        'email': email,
        'department': department,
        'password': password,
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Registration failed');
    }
  }

  /// Fetches all assets from the inventory.
  static Future<List<Map<String, dynamic>>> fetchAssets() async {
    final response = await http.get(Uri.parse('$baseUrl/assets.php'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load assets');
    }
  }

  /// Adds a new asset to the inventory.
  static Future<void> addAsset({
    required String tagId,
    required String name,
    required int categoryId,
    required String description,
    required String status,
    required String purchaseDate, // format: YYYY-MM-DD
    String? imagePath,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assets.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tag_id': tagId,
        'name': name,
        'category_id': categoryId,
        'description': description,
        'status': status,
        'purchase_date': purchaseDate,
        'image_path': imagePath,
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to add asset');
    }
  }
}