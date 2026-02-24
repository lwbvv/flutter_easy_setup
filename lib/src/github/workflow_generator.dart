import 'dart:io';

import 'package:path/path.dart' as p;

/// .github/workflows/ios-deploy.yml을 생성하는 클래스입니다.
class WorkflowGenerator {
  /// [projectRoot]의 .github/workflows/ios-deploy.yml을 생성합니다.
  ///
  /// [flavorNames]: workflow_dispatch의 choice 옵션으로 들어갈 flavor 목록
  static void generate(
    String projectRoot,
    List<String> flavorNames, {
    bool dryRun = false,
  }) {
    final path = p.join(projectRoot, '.github', 'workflows', 'ios-deploy.yml');

    final defaultFlavor =
        flavorNames.contains('prod') ? 'prod' : flavorNames.first;
    final optionsYaml =
        flavorNames.map((f) => '          - $f').join('\n');

    final content = 'name: iOS Deploy\n'
        '\n'
        'on:\n'
        '  workflow_dispatch:\n'
        '    inputs:\n'
        '      flavor:\n'
        '        description: "Flavor to build and deploy"\n'
        '        required: true\n'
        '        default: "$defaultFlavor"\n'
        '        type: choice\n'
        '        options:\n'
        '$optionsYaml\n'
        '\n'
        'jobs:\n'
        '  deploy:\n'
        '    runs-on: macos-latest\n'
        '    timeout-minutes: 30\n'
        '\n'
        '    steps:\n'
        '      - name: Checkout\n'
        '        uses: actions/checkout@v4\n'
        '\n'
        '      - name: Setup Flutter\n'
        '        uses: subosito/flutter-action@v2\n'
        '        with:\n'
        '          channel: stable\n'
        '\n'
        '      - name: Setup Ruby\n'
        '        uses: ruby/setup-ruby@v1\n'
        '        with:\n'
        '          ruby-version: "3.2"\n'
        '          bundler-cache: true\n'
        '          working-directory: fastlane/ios\n'
        '\n'
        '      - name: Flutter dependencies\n'
        '        run: flutter pub get\n'
        '\n'
        '      - name: Decode API Key\n'
        '        env:\n'
        '          API_KEY_BASE64: \${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}\n'
        '        run: echo "\$API_KEY_BASE64" | base64 --decode > fastlane/ios/AuthKey.p8\n'
        '\n'
        '      - name: Match — sync certificates\n'
        '        env:\n'
        '          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}\n'
        '          MATCH_GIT_BASIC_AUTHORIZATION: \${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}\n'
        '        run: |\n'
        '          cd fastlane/ios\n'
        '          bundle exec fastlane certificates\n'
        '\n'
        '      - name: Build & Deploy to TestFlight\n'
        '        env:\n'
        '          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}\n'
        '          MATCH_GIT_BASIC_AUTHORIZATION: \${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}\n'
        '        run: |\n'
        '          cd fastlane/ios\n'
        '          bundle exec fastlane beta flavor:\${{ inputs.flavor }}\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  static void _writeFile(String path, String content, {required bool dryRun}) {
    if (dryRun) {
      print('  [dry-run] Would create: $path');
      return;
    }
    final file = File(path);
    if (file.existsSync()) {
      print('  Already exists: $path, skipping.');
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Created: $path');
  }
}
