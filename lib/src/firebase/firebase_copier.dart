import 'dart:io';

import 'package:path/path.dart' as p;

/// Firebase 설정 파일을 flavor별 디렉터리로 복사하는 클래스입니다.
///
/// Android: google-services.json → android/app/src/{flavor}/google-services.json
/// iOS: GoogleService-Info.plist → ios/Runner/Firebase/{flavor}/GoogleService-Info.plist
class FirebaseCopier {
  /// Android Firebase 설정 파일을 복사합니다.
  ///
  /// [sourcePath]의 파일을 android/app/src/{flavor}/google-services.json으로 복사합니다.
  /// 소스 파일이 없으면 경고 후 건너뜁니다.
  /// 대상 파일이 이미 존재하면 건너뜁니다 (멱등성 보장).
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

  /// iOS Firebase 설정 파일을 복사합니다.
  ///
  /// [sourcePath]의 파일을 ios/Runner/Firebase/{flavor}/GoogleService-Info.plist로 복사합니다.
  /// 소스 파일이 없으면 경고 후 건너뜁니다.
  /// 대상 파일이 이미 존재하면 건너뜁니다 (멱등성 보장).
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
