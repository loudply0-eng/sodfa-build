import 'dart:convert';

import 'package:flutter/services.dart';

class SodfaChangelogEntry {
  const SodfaChangelogEntry({
    required this.version,
    required this.date,
    required this.title,
    required this.changes,
  });

  final String version;
  final String date;
  final String title;
  final List<String> changes;

  factory SodfaChangelogEntry.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    if (json['version'] is! String ||
        json['title'] is! String ||
        rawChanges is! List) {
      throw const FormatException('Invalid SODFA changelog entry.');
    }

    return SodfaChangelogEntry(
      version: json['version'] as String,
      date: json['date'] as String? ?? '',
      title: json['title'] as String,
      changes: rawChanges.map((item) => item.toString()).toList(),
    );
  }
}

class SodfaChangelogService {
  static Future<List<SodfaChangelogEntry>> load() async {
    final source = await rootBundle.loadString('docs/CHANGELOG.json');
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['releases'] is! List) {
      throw const FormatException('Invalid SODFA changelog document.');
    }

    final rawEntries = decoded['releases'] as List<dynamic>;
    final entries = rawEntries
        .map(
          (entry) => SodfaChangelogEntry.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList(growable: false);

    return List.unmodifiable(entries);
  }
}
