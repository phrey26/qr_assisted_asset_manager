import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/availability.dart';

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
  // this file every time you switch devices. When nothing is passed, the
  // default is chosen per-platform (see [_host]) so a plain `flutter run`
  // reaches this machine's localhost from wherever the app is running.
  //
  // Examples:
  //   Android emulator, Windows/macOS/Linux desktop, Flutter web, iOS
  //   simulator — all run from this PC (no flag needed):
  //     flutter run
  //   Physical phone on your LAN (only case that still needs the flag):
  //     flutter run --dart-define=API_HOST=192.168.1.23
  //   Using ngrok or a real domain:
  //     flutter run --dart-define=API_HOST=https://a1b2c3.ngrok-free.app --dart-define=API_SCHEME=
  static const bool _hostFromEnv = bool.hasEnvironment('API_HOST');
  static const String _hostEnv = String.fromEnvironment('API_HOST');

  /// The host to talk to. An explicit `--dart-define=API_HOST=` always wins;
  /// otherwise the Android emulator needs the `10.0.2.2` alias to reach the
  /// host loopback, while desktop, web and the iOS simulator can use
  /// `localhost` directly.
  static String get _host {
    if (_hostFromEnv && _hostEnv.isNotEmpty) return _hostEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  // Lets a full https:// URL (ngrok, real domain) be passed via API_HOST
  // without doubling up the scheme. Leave API_SCHEME as-is for plain LAN IPs.
  static const String _scheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'http://',
  );

  static String get baseUrl =>
      _host.startsWith('http') ? '$_host/csdo_api' : '$_scheme$_host/csdo_api';

  // Without a timeout, a request to an unreachable/wrong host (e.g.
  // localhost from a physical phone that isn't on this machine) just hangs
  // forever with no error and no visible feedback — it looks exactly like a
  // dead button. Bounding every request means a bad host/server always
  // surfaces as a clear, catchable error instead.
  static const _timeout = Duration(seconds: 12);

  static Never _timeoutError() => throw Exception(
    'Could not reach the server at $baseUrl (timed out after '
    '${_timeout.inSeconds}s). Check that XAMPP\'s Apache/MySQL are '
    'running and that csdo_api/ is in htdocs. On a physical phone, pass '
    '--dart-define=API_HOST=<your PC\'s LAN IP>.',
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
          body: jsonEncode({'identifier': identifier, 'password': password}),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['user'] as Map<String, dynamic>;
    }
    if (response.statusCode == 403 && body['code'] == 'email_not_verified') {
      throw EmailNotVerifiedException((body['email'] as String?) ?? identifier);
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
    return AuthCodeResult.fromBody(
      body,
      'If that email has an account, a code has been sent.',
    );
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
  ///
  /// Returns the new row's `id` and the `tag_id` the backend allocated for
  /// it — the tag is not chosen client-side, so the caller stamps the
  /// returned value onto its local [AssetItem].
  static Future<({int id, String tagId})> addAsset(
    Map<String, dynamic> asset,
  ) async {
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
    return (id: body['id'] as int, tagId: body['tag_id'] as String);
  }

  /// Edits an existing asset's details ([AssetItem.editJson], with
  /// `category_id` filled in). The backend records what changed on the
  /// asset's timeline. Never changes the tag ID, tracking mode or status.
  static Future<void> updateAsset(Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/assets.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to save the asset');
    }
  }

  /// Records that an admin just scanned an asset and, optionally, where they
  /// found it. Stamps `last_scanned_at` / `last_location` and adds a
  /// 'scanned' line to the timeline. Returns the server's `last_scanned_at`
  /// and the location it stored (null when none was given).
  static Future<({DateTime? at, String? location})> recordSighting({
    required String tagId,
    String? location,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/assets.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'sighting',
            'tag_id': tagId,
            if (location != null && location.isNotEmpty) 'location': location,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Failed to record the sighting');
    }
    return (
      at: DateTime.tryParse((body['last_scanned_at'] as String?) ?? '')?.toLocal(),
      location: (body['last_location'] as String?),
    );
  }

  /// Updates an existing asset's status (e.g. flagging it under
  /// maintenance, or moving it to stock). [reason], when given, is recorded
  /// on the asset's timeline as the change's detail.
  static Future<void> updateAssetStatus({
    required String tagId,
    required String status,
    String? reason,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/assets.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'tag_id': tagId,
            'status': status,
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to update asset');
    }
  }

  /// Permanently deletes an asset. The backend only allows this once the
  /// asset is a stock item, and requires [reason] — it's written to the
  /// `asset_removals` audit log before the row is removed.
  static Future<void> deleteAsset(
    String tagId, {
    required String reason,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/assets.php?tag_id=${Uri.encodeQueryComponent(tagId)}'
      '&reason=${Uri.encodeQueryComponent(reason)}',
    );
    final response = await http
        .delete(uri)
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to delete asset');
    }
  }

  /// Fetches an asset's timeline (newest event first), as returned by
  /// `asset_events.php`. Each map is `{id, event_type, detail, request_id,
  /// created_at}` — see [AssetEvent.fromJson].
  static Future<List<Map<String, dynamic>>> fetchAssetEvents(
    String tagId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/asset_events.php?tag_id=${Uri.encodeQueryComponent(tagId)}',
          ),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to load the asset timeline');
  }

  /// Fetches the permanent-removal audit log (`asset_removals.php`) —
  /// every asset deleted for good, newest first. Each map is `{id, tag_id,
  /// name, category, reason, removed_at}`.
  static Future<List<Map<String, dynamic>>> fetchAssetRemovals() async {
    final response = await http
        .get(Uri.parse('$baseUrl/asset_removals.php'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to load the removal log');
  }

  /// Fetches a bulk asset's stock state and history from `stock.php` — a
  /// `{summary, movements, purchases}` map (see [StockHistory.fromJson]).
  static Future<Map<String, dynamic>> fetchStockHistory(String tagId) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/stock.php?tag_id=${Uri.encodeQueryComponent(tagId)}',
          ),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to load the stock history');
  }

  /// Records a purchase ("Add stock") on a bulk asset — bumps its on-hand
  /// total and files the supplier/date paperwork. Returns the refreshed
  /// `summary` map.
  static Future<Map<String, dynamic>> addStock({
    required String tagId,
    required int quantity,
    String? supplier,
    String? note,
    String? purchasedAt,
  }) {
    return _postStock({
      'tag_id': tagId,
      'action': 'purchase',
      'quantity': quantity,
      if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
      if (note != null && note.isNotEmpty) 'note': note,
      if (purchasedAt != null && purchasedAt.isNotEmpty)
        'purchased_at': purchasedAt,
    });
  }

  /// Disposes of [quantity] units of a bulk asset (broken / used up / lost).
  /// [reason] is required and kept in the permanent `bulk_disposals` log.
  static Future<Map<String, dynamic>> disposeStock({
    required String tagId,
    required int quantity,
    required String reason,
  }) {
    return _postStock({
      'tag_id': tagId,
      'action': 'dispose',
      'quantity': quantity,
      'reason': reason,
    });
  }

  /// Moves [quantity] repaired units out of a bulk asset's "set aside
  /// damaged" holding bucket back into available stock.
  static Future<Map<String, dynamic>> restoreStock({
    required String tagId,
    required int quantity,
    String? note,
  }) {
    return _postStock({
      'tag_id': tagId,
      'action': 'restore',
      'quantity': quantity,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Corrects a bulk asset's on-hand total to [newTotal] (physical count
  /// mismatch). [reason] is required and logged on the stock ledger.
  static Future<Map<String, dynamic>> adjustStock({
    required String tagId,
    required int newTotal,
    required String reason,
  }) {
    return _postStock({
      'tag_id': tagId,
      'action': 'adjust',
      'new_total': newTotal,
      'reason': reason,
    });
  }

  static Future<Map<String, dynamic>> _postStock(
    Map<String, dynamic> payload,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/stock.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Stock update failed');
    }
    return (body['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  /// Fetches the permanent bulk-stock disposal log (`bulk_disposals.php`) —
  /// newest first. Each map is `{id, tag_id, name, category, quantity,
  /// reason, disposed_at}`.
  static Future<List<Map<String, dynamic>>> fetchBulkDisposals() async {
    final response = await http
        .get(Uri.parse('$baseUrl/bulk_disposals.php'))
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to load the disposal log');
  }

  /// Fetches an asset's condition & usage history from
  /// `asset_returns.php` — a `{summary, inspections}` map (see
  /// [AssetReturnHistory.fromJson]).
  static Future<Map<String, dynamic>> fetchAssetReturns(String tagId) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/asset_returns.php?tag_id=${Uri.encodeQueryComponent(tagId)}',
          ),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = jsonDecode(response.body);
    throw Exception(
      body['error'] ?? 'Failed to load the asset\'s usage history',
    );
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
        .delete(
          Uri.parse(
            '$baseUrl/categories.php?value=${Uri.encodeQueryComponent(value)}',
          ),
        )
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

  /// Fetches how much of each asset is free for the loan window [from]–[to]
  /// (both `YYYY-MM-DD`), from `availability.php`. [excludeRequest] is the
  /// request being (re)approved, so its own current assignment isn't counted
  /// against itself. Feeds the date-aware asset picker on approval.
  static Future<WindowAvailabilityReport> fetchAvailability({
    required String from,
    required String to,
    int? excludeRequest,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/availability.php?from=${Uri.encodeQueryComponent(from)}'
      '&to=${Uri.encodeQueryComponent(to)}'
      '${excludeRequest != null ? '&exclude_request=$excludeRequest' : ''}',
    );
    final response =
        await http.get(uri).timeout(_timeout, onTimeout: _timeoutError);

    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (body is Map ? body['error'] : null) ?? 'Failed to load availability',
      );
    }
    return WindowAvailabilityReport.fromJson((body as Map).cast<String, dynamic>());
  }

  /// Requester-safe feasibility check for the new-request form: given a
  /// category, a loan window and a quantity, returns only a coarse outlook —
  /// `'ok'`, `'partial'`, `'none'` or `'unknown'` — never asset names,
  /// counts or which requests hold what. See `csdo_api/request_feasibility.php`.
  static Future<String> fetchRequestFeasibility({
    required String category,
    required String from,
    required String to,
    required int quantity,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/request_feasibility.php'
      '?category=${Uri.encodeQueryComponent(category)}'
      '&from=${Uri.encodeQueryComponent(from)}'
      '&to=${Uri.encodeQueryComponent(to)}'
      '&quantity=$quantity',
    );
    final response =
        await http.get(uri).timeout(_timeout, onTimeout: _timeoutError);
    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (body is Map ? body['error'] : null) ?? 'Failed to check availability',
      );
    }
    return (body is Map ? body['outlook'] as String? : null) ?? 'unknown';
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

  /// Updates a request's status (pending/approved/rejected/returned).
  ///
  /// When [status] is `approved`, [assignments] must list what's being
  /// handed out as `{tag_id, quantity}` maps — quantity is 1 for an
  /// individual asset and N for a bulk pool line. The backend links them to
  /// the request, flips each individual asset to `in_use`, and decrements
  /// each bulk pool's available stock, all in one transaction. For any
  /// other status the backend releases whatever the request was holding, so
  /// [assignments] can be omitted.
  static Future<void> updateRequestStatus({
    required int id,
    required String status,
    List<Map<String, dynamic>>? assignments,
    Map<String, dynamic>? returnInspection,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/requests.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'status': status,
            if (assignments != null) 'assignments': assignments,
            if (returnInspection != null) 'return_inspection': returnInspection,
          }),
        )
        .timeout(_timeout, onTimeout: _timeoutError);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to update request');
    }
  }
}
