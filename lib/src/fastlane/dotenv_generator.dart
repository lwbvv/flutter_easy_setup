import 'dart:io';

import 'package:path/path.dart' as p;

/// A class that generates a .env file for Fastlane.
///
/// Fastlane automatically loads .env files from the fastlane/ directory.
/// The generated .env file contains TODO placeholders that
/// the user must fill in with actual values.
class DotenvGenerator {
  /// Generates a .env file in [outputDir].
  ///
  /// Does not overwrite if the file already exists (to protect user-filled values).
  static void generate(String outputDir, {bool dryRun = false}) {
    final path = p.join(outputDir, '.env');

    if (File(path).existsSync()) {
      print('  Skipped (already exists): $path');
      return;
    }

    const content = '# Fastlane environment variables\n'
        '# Replace the values below with your actual values.\n'
        '\n'
        '# Apple Developer Team ID\n'
        'TEAM_ID=YOUR_TEAM_ID\n'
        '\n'
        '# App Store Connect Team ID\n'
        'ITC_TEAM_ID=YOUR_ITC_TEAM_ID\n'
        '\n'
        '# App Store Connect API Key\n'
        'API_KEY_ID=YOUR_KEY_ID\n'
        'API_KEY_ISSUER_ID=YOUR_ISSUER_ID\n'
        '\n'
        '# Git repository URL for certificate storage (e.g., https://github.com/your-org/certs.git)\n'
        'CERTS_REPO_URL=YOUR_CERTS_REPO_URL\n'
        '\n'
        '# Apple ID (e.g., your@email.com)\n'
        'APPLE_ID=YOUR_APPLE_ID\n';

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
