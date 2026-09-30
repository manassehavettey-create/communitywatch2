import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/common.dart';
import 'request_budget.dart';

/// Thin HTTP client for API-Football v3. Validates the `errors` envelope
/// (the API returns HTTP 200 with errors) and records quota headers.
class ApiFootballClient {
  ApiFootballClient({required this.apiKey, required this.budget, http.Client? client, this.baseUrl = 'https://v3.football.api-sports.io'}) : _http = client ?? http.Client();

  final String apiKey;
  final RequestBudget budget;
  final String baseUrl;
  final http.Client _http;

  Future<String> get(String path, Map<String, String> query) async {
    if (apiKey.isEmpty) throw const DataException(DataErrorKind.auth, 'No API-Football key configured.');
    if (budget.exhausted) throw const DataException(DataErrorKind.rateLimited, 'Daily API request limit reached. It resets at 00:00 UTC.');
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query.isEmpty ? null : query);
    http.Response res;
    try {
      res = await _http.get(uri, headers: {'x-apisports-key': apiKey}).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const DataException(DataErrorKind.network, 'The connection timed out.');
    } catch (_) {
      throw const DataException(DataErrorKind.network, 'No connection to the data provider.');
    }

    int? h(String k) => int.tryParse(res.headers[k] ?? '');
    budget.update(
      dailyLimit: h('x-ratelimit-requests-limit'),
      remaining: h('x-ratelimit-requests-remaining'),
      minuteRemaining: h('x-ratelimit-remaining'),
    );

    if (res.statusCode == 429) throw const DataException(DataErrorKind.rateLimited, 'Too many requests. Updates will resume shortly.');
    if (res.statusCode == 401 || res.statusCode == 403) throw const DataException(DataErrorKind.auth, 'The API key was rejected.');
    if (res.statusCode >= 500) throw DataException(DataErrorKind.server, 'Provider error (${res.statusCode}).');
    if (res.statusCode != 200) throw DataException(DataErrorKind.unknown, 'Unexpected response (${res.statusCode}).');

    final body = utf8.decode(res.bodyBytes);
    checkErrors(body);
    return body;
  }

  /// Throws a typed [DataException] if the envelope carries errors.
  static void checkErrors(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const DataException(DataErrorKind.server, 'Malformed provider response.');
    }
    if (decoded is! Map) throw const DataException(DataErrorKind.server, 'Malformed provider response.');
    final errors = decoded['errors'];
    final Map<String, dynamic> map = switch (errors) {
      Map m when m.isNotEmpty => m.map((k, v) => MapEntry('$k', v)),
      List l when l.isNotEmpty => {for (var i = 0; i < l.length; i++) '$i': l[i]},
      _ => const {},
    };
    if (map.isEmpty) return;
    final key = map.keys.first.toLowerCase();
    final msg = '${map.values.first}';
    if (key.contains('token') || key.contains('key') || msg.toLowerCase().contains('api key')) {
      throw DataException(DataErrorKind.auth, msg);
    }
    if (key.contains('ratelimit') || key.contains('requests') || msg.toLowerCase().contains('request limit')) {
      throw DataException(DataErrorKind.rateLimited, msg);
    }
    if (key.contains('plan') || msg.toLowerCase().contains('plan')) {
      throw DataException(DataErrorKind.plan, msg);
    }
    throw DataException(DataErrorKind.unknown, msg);
  }
}
