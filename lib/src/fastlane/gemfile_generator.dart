import 'dart:io';

import 'package:path/path.dart' as p;

/// A class that generates the Gemfile.
class GemfileGenerator {
  /// Generates a Gemfile in [outputDir].
  ///
  /// Does not overwrite if the file already exists (idempotency).
  static void generate(String outputDir, {bool dryRun = false}) {
    final path = p.join(outputDir, 'Gemfile');

    const content = 'source "https://rubygems.org"\n'
        '\n'
        'gem "fastlane"\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  static void _writeFile(String path, String content, {required bool dryRun}) {
    if (dryRun) {
      print('  [dry-run] Would write: $path');
      return;
    }
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Wrote: $path');
  }
}
