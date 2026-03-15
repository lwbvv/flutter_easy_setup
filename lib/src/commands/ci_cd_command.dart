import 'package:path/path.dart' as p;

import '../exceptions.dart';
import '../fastlane/appfile_generator.dart';
import '../fastlane/dotenv_generator.dart';
import '../fastlane/fastfile_generator.dart';
import '../fastlane/gemfile_generator.dart';
import '../fastlane/matchfile_generator.dart';
import '../fastlane/metadata_generator.dart';
import '../github/workflow_generator.dart';
import '../models/flavor_config.dart';
import '../utils/fastlane_runner.dart';
import '../utils/project_finder.dart';

/// Command class that orchestrates the entire CI/CD pipeline setup.
///
/// Generates Fastlane files and GitHub Actions workflows in the following order:
///   1. Detect Flutter project root
///   2. Load easy_setup.yaml
///   3. Resolve target flavors and bundle_ids for CI/CD (from easy_setup.flavors)
///   4. Generate Fastlane files in ci_cd/ios/fastlane/ (.env, Gemfile, Matchfile, Appfile, Fastfile)
///   5. Run bundle install (in fastlane directory)
///   6. Add register lane to Fastfile
///   7. Generate metadata files + add update_metadata lane (optional)
///   8. Generate .github/workflows/ios-deploy.yml
class CiCdCommand {
  /// Runs the CI/CD setup pipeline.
  static Future<void> run({bool dryRun = false, String? projectRoot}) async {
    // 1. Verify Flutter project root
    final root = projectRoot ?? ProjectFinder.findFlutterRoot();
    if (root == null) {
      throw SetupException(
        'Could not find a Flutter project root.\n'
        'Run this command from inside a Flutter project directory.',
      );
    }
    print('Flutter project root: $root');

    // 2. Load easy_setup.yaml
    final configPath = ProjectFinder.configPath(root);
    print('Loading config from: $configPath');
    final config = EasySetupConfig.fromFile(configPath);

    // 3. Resolve target flavor, bundle_id, and name for CI/CD
    final resolvedFlavors = _resolveFlavors(config);
    final flavorNames = resolvedFlavors.keys.toList();
    final bundleIds =
        resolvedFlavors.values.map((f) => f.bundleId).toList();

    print('CI/CD flavors: ${flavorNames.join(', ')}');
    if (dryRun) print('\n[dry-run mode] No files will be written.');

    // 4. Generate Fastlane files — create all files in ci_cd/ios/fastlane/ directory
    print('\n--- Fastlane ---');
    final fastlaneDir = p.join(root, 'ci_cd', 'ios', 'fastlane');
    DotenvGenerator.generate(fastlaneDir, dryRun: dryRun);
    GemfileGenerator.generate(fastlaneDir, dryRun: dryRun);
    MatchfileGenerator.generate(fastlaneDir, bundleIds, dryRun: dryRun);
    AppfileGenerator.generate(fastlaneDir, dryRun: dryRun);
    final flavorBundleIds = resolvedFlavors.map(
      (key, info) => MapEntry(key, info.bundleId),
    );
    FastfileGenerator.generate(fastlaneDir, flavorBundleIds, dryRun: dryRun);

    // 5. Run bundle install (in fastlane directory)
    await FastlaneRunner.bundleInstall(fastlaneDir, dryRun: dryRun);

    // 6. Add register lane to Fastfile
    if (!dryRun) {
      print('\n--- Register Lane ---');
      final fastfilePath = p.join(fastlaneDir, 'Fastfile');
      final flavorRecords = resolvedFlavors.map(
        (key, info) => MapEntry(
          key,
          (bundleId: info.bundleId, name: info.name),
        ),
      );
      FastfileGenerator.addRegisterLane(
        fastfilePath: fastfilePath,
        flavors: flavorRecords,
      );
    }

    // 7. Generate metadata files + add update_metadata lane (optional)
    if (config.metadata != null && config.metadata!.isNotEmpty) {
      print('\n--- Metadata ---');
      MetadataGenerator.generate(fastlaneDir, config.metadata!, dryRun: dryRun);

      if (!dryRun) {
        final fastfilePath = p.join(fastlaneDir, 'Fastfile');
        FastfileGenerator.addMetadataLane(
          fastfilePath: fastfilePath,
        );
      }
    }

    // 8. Generate GitHub Actions workflow
    print('\n--- GitHub Actions ---');
    WorkflowGenerator.generate(root, flavorNames, dryRun: dryRun);

    // 9. Print completion summary
    final hasMetadata = config.metadata != null && config.metadata!.isNotEmpty;
    _printSummary(dryRun: dryRun, hasMetadata: hasMetadata);
  }

  /// Resolves the bundleId and name for CI/CD target flavors (from easy_setup.flavors).
  static Map<String, _FlavorInfo> _resolveFlavors(EasySetupConfig config) {
    if (config.flavors.isEmpty) {
      throw SetupException('No flavors defined in easy_setup.yaml');
    }

    final result = <String, _FlavorInfo>{};
    for (final entry in config.flavors.entries) {
      result[entry.key] = _FlavorInfo(
        bundleId: entry.value.bundleId,
        name: entry.value.name,
      );
    }
    return result;
  }

  static void _printSummary({
    required bool dryRun,
    required bool hasMetadata,
  }) {
    print('\n${dryRun ? "Preview" : "CI/CD setup"} complete!');
    if (!dryRun) {
      print('\nGenerated files:');
      print('  - ci_cd/ios/fastlane/.env');
      print('  - ci_cd/ios/fastlane/Gemfile');
      print('  - ci_cd/ios/fastlane/Matchfile');
      print('  - ci_cd/ios/fastlane/Appfile');
      print('  - ci_cd/ios/fastlane/Fastfile (with register lane)');
      if (hasMetadata) {
        print('  - ci_cd/ios/fastlane/metadata/{locale}/*.txt');
      }
      print('  - .github/workflows/ios-deploy.yml');
      print('\nConfiguration needed:');
      print('  1. Edit ci_cd/ios/fastlane/.env');
      print('     - TEAM_ID, ITC_TEAM_ID, API_KEY_ID, API_KEY_ISSUER_ID, CERTS_REPO_URL');
      print('\nRequired GitHub Secrets:');
      print('  MATCH_PASSWORD              — Match encryption password');
      print('  MATCH_GIT_BASIC_AUTHORIZATION — base64(username:PAT)');
      print('  APP_STORE_CONNECT_API_KEY_BASE64 — base64 of .p8 key file');
      print('\nNext steps:');
      print('  1. Complete the configuration above');
      print('  2. cd ci_cd/ios/fastlane && bundle install');
      print('  3. bundle exec fastlane match init  (first time only)');
      print('  4. Configure GitHub Secrets in your repository settings');
      var step = 5;
      print('  $step. cd ci_cd/ios/fastlane && bundle exec fastlane register');
      print('     (to create apps on App Store Connect — requires 2FA)');
      step++;
      if (hasMetadata) {
        print('  $step. cd ci_cd/ios/fastlane && bundle exec fastlane update_metadata');
        print('     (to upload metadata to App Store Connect)');
      }
    }
  }
}

/// Internal class that holds the bundleId and name for a single flavor.
class _FlavorInfo {
  final String bundleId;
  final String name;

  const _FlavorInfo({required this.bundleId, required this.name});
}
