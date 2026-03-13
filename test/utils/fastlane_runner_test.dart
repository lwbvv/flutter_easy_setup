import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

void main() {
  group('FastlaneRunner.bundleInstall', () {
    test('dry-run does not run bundle install', () async {
      // Should not throw — just prints dry-run message
      await FastlaneRunner.bundleInstall('/tmp', dryRun: true);
    });
  });
}
