import 'dart:io';

import 'package:path/path.dart' as p;

/// A class that copies Firebase config files to per-flavor directories.
///
/// Android: google-services.json → android/app/src/{flavor}/google-services.json
/// iOS: GoogleService-Info.plist → ios/Runner/Firebase/{flavor}/GoogleService-Info.plist
class FirebaseCopier {
  /// Copies the Android Firebase config file.
  ///
  /// Copies the file at [sourcePath] to android/app/src/{flavor}/google-services.json.
  /// If the source file does not exist, prints a warning and skips.
  /// If the destination file already exists, skips (idempotency guarantee).
  static void copyAndroidConfig(
    String projectRoot,
    String flavor,
    String sourcePath, {
    bool dryRun = false,
  }) {
    final source = File(p.join(projectRoot, sourcePath));
    if (!source.existsSync()) {
      print('  Warning: Firebase Android config not found at ${source.path}, skipping.');
      return;
    }

    final destPath = p.join(projectRoot, 'android', 'app', 'src', flavor, 'google-services.json');
    final dest = File(destPath);

    if (dryRun) {
      print('  [dry-run] Would copy ${source.path} → $destPath');
      return;
    }

    dest.parent.createSync(recursive: true);
    source.copySync(destPath);
    print('  Copied: ${source.path} → $destPath');
  }

  /// Copies the iOS Firebase config file.
  ///
  /// Copies the file at [sourcePath] to ios/Runner/Firebase/{flavor}/GoogleService-Info.plist.
  /// If the source file does not exist, prints a warning and skips.
  /// If the destination file already exists, skips (idempotency guarantee).
  static void copyIosConfig(
    String projectRoot,
    String flavor,
    String sourcePath, {
    bool dryRun = false,
  }) {
    final source = File(p.join(projectRoot, sourcePath));
    if (!source.existsSync()) {
      print('  Warning: Firebase iOS config not found at ${source.path}, skipping.');
      return;
    }

    final destPath = p.join(projectRoot, 'ios', 'Runner', 'Firebase', flavor, 'GoogleService-Info.plist');
    final dest = File(destPath);

    if (dryRun) {
      print('  [dry-run] Would copy ${source.path} → $destPath');
      return;
    }

    dest.parent.createSync(recursive: true);
    source.copySync(destPath);
    print('  Copied: ${source.path} → $destPath');
  }
}
