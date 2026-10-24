import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/update.dart';

void main() {
  test('versions', () {
    expect(parseVersion('v0.10.2'), (0, 10, 2));
    expect(parseVersion('0.10.0+10'), (0, 10, 0));
    expect(parseVersion('1.2'), (1, 2, 0));
    expect(parseVersion('latest'), isNull);
  });

  test('newer means a later version, not a different one', () {
    expect(isNewer('v0.11.0', '0.10.0'), isTrue);
    expect(isNewer('v0.10.1', '0.10.0'), isTrue);
    expect(isNewer('v1.0.0', '0.99.9'), isTrue);
    expect(isNewer('v0.10.0', '0.10.0'), isFalse);
    expect(isNewer('v0.9.9', '0.10.0'), isFalse); // 10 > 9, not "0.9" > "0.1"
    expect(isNewer('nightly', '0.10.0'), isFalse);
  });

  test('reads a GitHub release and picks the arm64 APK', () {
    final r = releaseFromGitHub({
      'tag_name': 'v0.11.0',
      'html_url': 'https://github.com/o/slipcheck/releases/tag/v0.11.0',
      'body': ' Reads big amounts. ',
      'assets': [
        {'name': 'slipcheck-0.11.0-armeabi-v7a.apk', 'browser_download_url': 'https://x/v7a.apk'},
        {'name': 'slipcheck-0.11.0-arm64-v8a.apk', 'browser_download_url': 'https://x/arm64.apk'},
        {'name': 'notes.txt', 'browser_download_url': 'https://x/notes.txt'},
      ],
    })!;
    expect(r.version, '0.11.0');
    expect(r.apkUrl, 'https://x/arm64.apk');
    expect(r.notes, 'Reads big amounts.');
  });

  test('a release without an APK still links its page; junk is not a release', () {
    final r = releaseFromGitHub({'tag_name': 'v0.11.0', 'html_url': 'https://x/page'})!;
    expect(r.apkUrl, isNull);
    expect(releaseFromGitHub({'message': 'Not Found'}), isNull);
  });
}
