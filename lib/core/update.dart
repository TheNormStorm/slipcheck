/// Comparing the app's version with GitHub's latest release, and picking
/// the APK to download from it. Pure, so it is tested without a network.
library;

/// "v0.10.2", "0.10.2" or "0.10.2+12" as (0, 10, 2); null if not a version.
(int, int, int)? parseVersion(String text) {
  final m = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(text.trim());
  if (m == null) return null;
  return (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3] ?? '0'));
}

/// Whether [candidate] is a later version than [current].
bool isNewer(String candidate, String current) {
  final a = parseVersion(candidate), b = parseVersion(current);
  if (a == null || b == null) return false;
  for (final (x, y) in [(a.$1, b.$1), (a.$2, b.$2), (a.$3, b.$3)]) {
    if (x != y) return x > y;
  }
  return false;
}

/// A published release.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.pageUrl, this.apkUrl, this.notes = ''});
  final String version;

  /// The release's page on GitHub.
  final String pageUrl;

  /// The APK to download, when the release has one.
  final String? apkUrl;
  final String notes;
}

/// Reads GitHub's "latest release" JSON. Prefers an APK built for 64-bit
/// ARM phones (arm64-v8a), else any APK. Null if it is not a release.
ReleaseInfo? releaseFromGitHub(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  final page = json['html_url'];
  if (tag is! String || page is! String || parseVersion(tag) == null) return null;
  final apks = [
    for (final a in (json['assets'] as List? ?? const []))
      if (a is Map && a['name'] is String && (a['name'] as String).toLowerCase().endsWith('.apk'))
        (a['name'] as String, a['browser_download_url'] as String?),
  ];
  final arm64 = apks.where((a) => a.$1.contains('arm64')).firstOrNull;
  return ReleaseInfo(
    version: tag.replaceFirst(RegExp(r'^v'), ''),
    pageUrl: page,
    apkUrl: (arm64 ?? apks.firstOrNull)?.$2,
    notes: (json['body'] as String? ?? '').trim(),
  );
}
