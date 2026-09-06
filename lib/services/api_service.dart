import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown by [ApiService.login] when the account exists and the password is
/// correct but the email address hasn't been verified yet. Carries the
/// address so the caller can send the user straight to the code-entry
/// screen.
class EmailNotVerifiedException implements Exception {
  EmailNotVerifiedException(this.email);

  final String email;

  @override
  String toString() => 'Please verify your email address before signing in.';
}

/// Result of an endpoint that emails a 6-digit code (register / resend /
/// forgot password). [devCode] is only populated when the backend is in
/// mail dev mode (no SMTP configured) — it lets the app show the code
/// during development instead of digging through `csdo_api/_mail_outbox/`.
class AuthCodeResult {
  AuthCodeResult({required this.message, this.devCode});

  final String message;
  final String? devCode;

  factory AuthCodeResult.fromBody(Map<String, dynamic> body, String fallback) =>
      AuthCodeResult(
        message: (body['message'] as String?) ?? fallback,
        devCode: body['dev_code'] as String?,
      );
}

/// Talks to the csdo_api PHP backend.
///
/// Base URL notes:
/// - Android emulator: localhost on your PC is reachable at 10.0.2.2
/// - iOS simulator: localhost works as-is
/// - Physical phone on the same WiFi: use your PC's LAN IP, e.g. 192.168.1.x
/// - Flutter web/desktop (run from the same machine): localhost works as-is
class ApiService {
  // Set at build/run time with --dart-define, so you don't have to hand-edit
  // this file every time you switch devices. Falls back to the Android
  // emulator address (10.0.2.2) if nothing is passed.
  //
  // Examples:
  //   Android emulator (default, no flag needed):
  //     flutter run
  //   Windows/macOS/Linux desktop, or Flutter web on your PC:
  //     flutter run -d windows --dart-define=API_HOST=localhost
  //   Physical phone / iOS simulator on your LAN:
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

  // Without a timeout, a request to an unreachable/wrong host (e.g. the
  // 10.0.2.2 default used from a desktop build instead of an Android
  // emulator) just hangs forever with no error and no visible feedback —
  // it looks exactly like a dead button. Bounding every request means a
  // bad host/server always surfaces as a clear, catchable error instead.
  static const _timeout = Duration(seconds: 12);

  static Never _timeoutError() => throw Exception(
        'Could not reach the server at $baseUrl (timed out after '
        '${_timeout.inSeconds}s). Check that XAMPP\'s Apache/MySQL are '
        'running, that csdo_api/ was copied to htdocs, and that API_HOST '
        'is set correctly for how you\'re running the app.',
      );

  /// Logs in with an email address *or* employee ID, plus password.
  /// Returns the user map on success.
  ///
  /// Throws [EmailNotVerifiedException] if the credentials are valid but the
  /// email still needs verifying, and a plain [Exception] for anything else.
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    }
    if (response.statusCode == 403 && body['code'] == 'email_not_verified') {
      throw EmailNotVerifiedException(
        (body['email'] as String?) ?? identifier,
      );
    }
    throw Exception(body['error'] ?? 'Login failed');
  }

  /// Registers a new account. The backend creates it unverified and emails a
  /// 6-digit verification code; the returned [AuthCodeResult] carries the
  /// address the code went to.
  static Future<AuthCodeResult> register({
    required String employeeId,
    required String fullName,
    required String email,
    required String department,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/register.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'employee_id': employeeId,
            'full_name': fullName,
            'email': email,
            'department': department,
            'password': password,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Registration failed');
    }
    return AuthCodeResult.fromBody(body, 'Account created. Check your email.');
  }

  /// Confirms an email-verification code. Returns the now-active user map
  /// (same shape as [login]), so the caller can sign the user straight in.
  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/verify_email.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? 'Verification failed');
  }

  /// Asks the backend to email a fresh code. [purpose] is `'verify'` or
  /// `'reset'`.
  static Future<AuthCodeResult> resendCode({
    required String email,
    String purpose = 'verify',
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/resend_code.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'purpose': purpose}),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Could not send a new code');
    }
    return AuthCodeResult.fromBody(body, 'A new code has been sent.');
  }

  /// Starts a password reset — the backend emails a 6-digit reset code.
  static Future<AuthCodeResult> requestPasswordReset({
    required String email,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/forgot_password.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Could not start the password reset');
    }
    return AuthCodeResult.fromBody(body, 'If that email has an account, a code has been sent.');
  }

  /// Updates the signed-in admin's own profile (name, department, email).
  /// The account is identified by its unchanged [employeeId]. Returns the
  /// refreshed user map (same shape as [login]).
  static Future<Map<String, dynamic>> updateProfile({
    required String employeeId,
    required String fullName,
    required String department,
    required String email,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/update_profile.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'employee_id': employeeId,
            'full_name': fullName,
            'department': department,
            'email': email,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? 'Could not update the profile');
  }

  /// Completes a password reset with the emailed code and a new password.
  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/reset_password.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'code': code,
            'new_password': newPassword,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Could not reset the password');
    }
  }

  /// Fetches all assets from the inventory.
  static Future<List<Map<String, dynamic>>> fetchAssets() async {
    final response = await http
        .get(Uri.parse('$baseUrl/assets.php'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load assets');
    }
  }

  /// Adds a new asset to the inventory. [asset] should be built via
  /// [AssetItem.toJson] (with `category_id` filled in, since the model
  /// itself only knows the category's string value).
  static Future<int> addAsset(Map<String, dynamic> asset) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/assets.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(asset),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Failed to add asset');
    }
    return body['id'] as int;
  }

  /// Updates an existing asset's status (e.g. flagging it under
  /// maintenance, or marking it available again).
  static Future<void> updateAssetStatus({
    required String tagId,
    required String status,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/assets.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'tag_id': tagId, 'status': status}),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to update asset');
    }
  }

  /// Removes an asset from the inventory.
  static Future<void> deleteAsset(String tagId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/assets.php?tag_id=${Uri.encodeQueryComponent(tagId)}'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to delete asset');
    }
  }

  /// Fetches all asset categories.
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await http
        .get(Uri.parse('$baseUrl/categories.php'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  /// Adds a new category. Returns the new category's database id.
  static Future<int> addCategory(Map<String, dynamic> category) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/categories.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(category),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Failed to add category');
    }
    return body['id'] as int;
  }

  /// Removes a category (only valid once no asset still references it).
  static Future<void> deleteCategory(String value) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/categories.php?value=${Uri.encodeQueryComponent(value)}'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to delete category');
    }
  }

  /// Fetches all asset requests, each with its nested logistics/equipment
  /// items.
  static Future<List<Map<String, dynamic>>> fetchRequests() async {
    final response = await http
        .get(Uri.parse('$baseUrl/requests.php'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load requests');
    }
  }

  /// Submits a new asset request. [request] should be built via
  /// [AssetRequest.toJson]. Returns the new request's database id.
  static Future<int> addRequest(Map<String, dynamic> request) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/requests.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Failed to submit request');
    }
    return body['id'] as int;
  }

  /// Updates a request's status (pending/approved/rejected).
  static Future<void> updateRequestStatus({
    required int id,
    required String status,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/requests.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id, 'status': status}),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to update request');
    }
  }
}
