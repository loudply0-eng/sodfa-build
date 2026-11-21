import 'package:flutter_test/flutter_test.dart';
import 'package:sodfa/services/sodfa_update_service.dart';

void main() {
  const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('parses the release title and per-version change list', () {
    final release = SodfaRelease.fromJson({
      'version': '0.1.8',
      'build_number': 9,
      'apk_url': 'https://example.com/sodfa.apk',
      'sha256': digest,
      'release_title': 'تأسيس الاتصال الآمن',
      'release_changes': [
        'إضافة ميزة جديدة.',
        'إصلاح مشكلة سابقة.',
      ],
      'force_update': false,
      'min_supported_build': 1,
    });

    expect(release.releaseTitle, 'تأسيس الاتصال الآمن');
    expect(release.releaseChanges, [
      'إضافة ميزة جديدة.',
      'إصلاح مشكلة سابقة.',
    ]);
  });

  test('keeps compatibility with older manifests without a change list', () {
    final release = SodfaRelease.fromJson({
      'version': '0.1.8',
      'build_number': 9,
      'apk_url': 'https://example.com/sodfa.apk',
      'sha256': digest,
      'release_notes': 'تحديث جديد',
      'force_update': false,
      'min_supported_build': 1,
    });

    expect(release.releaseTitle, isEmpty);
    expect(release.releaseChanges, isEmpty);
    expect(release.releaseNotes, 'تحديث جديد');
  });
}
