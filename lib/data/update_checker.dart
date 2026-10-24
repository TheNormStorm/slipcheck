import 'dart:convert';
import 'dart:io';

import '../core/update.dart';

/// Asks GitHub for Slipcheck's latest release. The one network call the app
/// makes, and only when the user taps "Check for updates": it sends nothing
/// but the request itself (no receipts, no ids).
class UpdateChecker {
  const UpdateChecker({this.repo = 'TheNormStorm/slipcheck'});

  /// owner/name of the public GitHub repository releases are published to.
  final String repo;

  Future<ReleaseInfo?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.https('api.github.com', '/repos/$repo/releases/latest'));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Slipcheck');
      final response = await request.close().timeout(const Duration(seconds: 15));
      // 404: the repository has no releases yet (or does not exist).
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub answered ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      return releaseFromGitHub(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }
}
