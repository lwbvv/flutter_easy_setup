import 'dart:io';

import 'package:path/path.dart' as p;

import '../exceptions.dart';

/// A class responsible for generating and managing Fastfile lanes.
///
/// - [generate]: Creates the base Fastfile skeleton + built-in lanes (api_key, certificates, beta)
/// - [addRegisterLane]: Adds the register lane (idempotent)
/// - [addLane]: Inserts arbitrary lane code into the Fastfile (idempotent)
class FastfileGenerator {
  /// Generates a Fastfile in [outputDir] (base skeleton + built-in lanes).
  ///
  /// [flavorBundleIds]: flavor name to bundle ID mapping
  static void generate(
    String outputDir,
    Map<String, String> flavorBundleIds, {
    bool dryRun = false,
  }) {
    final path = p.join(outputDir, 'Fastfile');
    final flavorNames = flavorBundleIds.keys.toList();

    final defaultFlavor = flavorNames.contains('prod')
        ? 'prod'
        : flavorNames.first;

    // sync_certs lane: generate per-flavor signing settings
    final syncCerts = StringBuffer();
    syncCerts.writeln(
        '    # readonly: true only fetches existing certificates without creating new ones.');
    syncCerts.writeln(
        '    match(type: "development", readonly: true, api_key: api_key)');
    syncCerts.writeln(
        '    match(type: "appstore", readonly: true, api_key: api_key)');
    syncCerts.writeln(
        '    match(type: "adhoc", readonly: true, api_key: api_key)');
    syncCerts.writeln();
    syncCerts.writeln(
        '    # Update Xcode project signing settings.');

    for (final entry in flavorBundleIds.entries) {
      final flavor = entry.key;
      final bundleId = entry.value;

      syncCerts.writeln();
      syncCerts.writeln('    bundle_id = "$bundleId"');

      for (final buildType in ['Debug', 'Release', 'Profile']) {
        final isDebug = buildType == 'Debug';
        final profileType = isDebug ? 'Development' : 'AppStore';
        final identity = isDebug ? 'Apple Development' : 'Apple Distribution';

        syncCerts.writeln();
        syncCerts.writeln('    update_code_signing_settings(');
        syncCerts.writeln('      use_automatic_signing: false,');
        syncCerts.writeln('      path: "../../ios/Runner.xcodeproj",');
        syncCerts.writeln('      bundle_identifier: bundle_id,');
        syncCerts.writeln('      build_configurations: "$buildType-$flavor",');
        syncCerts.writeln(
            '      profile_name: "match $profileType #{bundle_id}",');
        syncCerts.writeln('      code_sign_identity: "$identity"');
        syncCerts.writeln('    )');
      }
    }

    syncCerts.writeln();
    syncCerts.write(
        '    UI.success "Profile mapping to Xcode project is complete!"');

    final content = 'default_platform(:ios)\n'
        '\n'
        'platform :ios do\n'
        '  # ── API Key Configuration ──────────────────────────────────\n'
        '  api_key = app_store_connect_api_key(\n'
        '    key_id: ENV["API_KEY_ID"],\n'
        '    issuer_id: ENV["API_KEY_ISSUER_ID"],\n'
        '    key_filepath: "fastlane/AuthKey.p8", # TODO: path to .p8 key file\n'
        '    duration: 1200,\n'
        '    in_house: false\n'
        '  )\n'
        '\n'
        '  # ── Auto-increment Build Number ──────────────────────────\n'
        '  def increment_build_number_in_pubspec\n'
        '    pubspec_path = File.join(__dir__, "..", "..", "..", "pubspec.yaml")\n'
        '    content = File.read(pubspec_path)\n'
        '    unless content =~ /^(version:\\s*\\S+\\+)(\\d+)\$/m\n'
        '      UI.user_error!("Could not find version+build_number in pubspec.yaml")\n'
        '    end\n'
        '    old_build = \$2.to_i\n'
        '    new_build = old_build + 1\n'
        '    new_content = content.sub(/^(version:\\s*\\S+\\+)\\d+\$/m, "\\\\1#{new_build}")\n'
        '    File.write(pubspec_path, new_content)\n'
        '    UI.success("Build number: #{old_build} → #{new_build}")\n'
        '    new_build\n'
        '  end\n'
        '\n'
        '  # ── Sync Certificates + Xcode Signing Settings ──────────────────\n'
        '  desc "Sync certificates and update Xcode signing settings"\n'
        '  lane :sync_certs do\n'
        '${syncCerts.toString()}\n'
        '  end\n'
        '\n'
        '  # ── Refresh Profiles Only ─────────────────────────────────\n'
        '  desc "Regenerate provisioning profiles without touching certificates"\n'
        '  lane :refresh_profiles do\n'
        '    match(type: "development", force: true, api_key: api_key)\n'
        '    match(type: "appstore", force: true, api_key: api_key)\n'
        '    match(type: "adhoc", force: true, api_key: api_key)\n'
        '\n'
        '    UI.success "Provisioning profiles have been refreshed while keeping certificates intact!"\n'
        '  end\n'
        '\n'
        '  # ── Per-flavor Build + TestFlight Deploy ───────────────\n'
        '  desc "Build and upload to TestFlight"\n'
        '  lane :beta do |options|\n'
        '    flavor = options[:flavor] || "$defaultFlavor"\n'
        '\n'
        '    sync_certs\n'
        '\n'
        '    increment_build_number_in_pubspec\n'
        '\n'
        '    sh("cd ../../.. && flutter build ipa --flavor #{flavor} --release")\n'
        '\n'
        '    upload_to_testflight(\n'
        '      api_key: api_key,\n'
        '      skip_waiting_for_build_processing: true,\n'
        '    )\n'
        '  end\n'
        'end\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  /// Adds the register lane to the Fastfile (idempotent).
  ///
  /// [fastfilePath]: path to the Fastfile
  /// [flavors]: per-flavor bundleId + name map ({flavorName: {bundleId, name}})
  static void addRegisterLane({
    required String fastfilePath,
    required Map<String, ({String bundleId, String name})> flavors,
    bool dryRun = false,
  }) {
    final laneCode = StringBuffer();
    laneCode.writeln('  # ── Bundle ID + App Registration ──────────────────────');
    laneCode.writeln(
        '  desc "Register Bundle IDs and create apps on App Store Connect"');
    laneCode.writeln('  lane :register do');

    for (final entry in flavors.entries) {
      final info = entry.value;
      laneCode.writeln('    produce(');
      laneCode.writeln('      app_identifier: "${info.bundleId}",');
      laneCode.writeln('      app_name: "${info.name}",');
      laneCode.writeln('      sku: "${info.bundleId}",');
      laneCode.writeln('      team_id: ENV["TEAM_ID"],');
      laneCode.writeln('      itc_team_id: ENV["ITC_TEAM_ID"],');
      laneCode.writeln('      # username: "your@email.com",       # TODO: Apple ID (uncomment if needed)');
      laneCode.writeln('      enable_services: {                  # Game Center is on by default, so it must be explicitly disabled');
      laneCode.writeln('        game_center: "off"');
      laneCode.writeln('      },');
      laneCode.writeln('    )');
      laneCode.writeln('');
    }

    laneCode.writeln('    UI.success("All apps registered!")');
    laneCode.write('  end');

    addLane(
      fastfilePath: fastfilePath,
      marker: '  # ── Bundle ID + App Registration',
      laneKeyword: 'lane :register do',
      laneCode: laneCode.toString(),
      dryRun: dryRun,
    );
  }

  /// Adds the update_metadata lane to the Fastfile (idempotent).
  ///
  /// Uses `deliver` to upload metadata to App Store Connect.
  static void addMetadataLane({
    required String fastfilePath,
    bool dryRun = false,
  }) {
    final laneCode = StringBuffer();
    laneCode.writeln('  # ── Metadata Upload ─────────────────────────');
    laneCode.writeln(
        '  desc "Upload metadata to App Store Connect"');
    laneCode.writeln('  lane :update_metadata do');
    laneCode.writeln('    deliver(');
    laneCode.writeln('      api_key: api_key,');
    laneCode.writeln('      skip_binary_upload: true,');
    laneCode.writeln('      skip_screenshots: true,');
    laneCode.writeln('      force: true,');
    laneCode.writeln('      precheck_include_in_app_purchases: false,');
    laneCode.writeln('    )');
    laneCode.write('  end');

    addLane(
      fastfilePath: fastfilePath,
      marker: '  # ── Metadata Upload',
      laneKeyword: 'lane :update_metadata do',
      laneCode: laneCode.toString(),
      dryRun: dryRun,
    );
  }

  /// Adds lane code to the Fastfile (idempotent).
  ///
  /// If an existing block starting with [marker] is found, it is removed before reinserting.
  /// The lane code is inserted before the last `end` (platform block closure) in the Fastfile.
  ///
  /// [fastfilePath]: path to the Fastfile
  /// [marker]: comment marker for detecting existing blocks
  /// [laneKeyword]: lane start keyword (e.g., 'lane :register do')
  /// [laneCode]: full lane code to insert (marker + desc + lane block)
  static void addLane({
    required String fastfilePath,
    required String marker,
    required String laneKeyword,
    required String laneCode,
    bool dryRun = false,
  }) {
    final fastfile = File(fastfilePath);

    if (!fastfile.existsSync()) {
      throw SetupException(
        'Fastfile not found: $fastfilePath\n'
        'Run "easy_setup ci-cd" first to generate Fastlane files.',
      );
    }

    if (dryRun) {
      print('  [dry-run] Would add lane to: $fastfilePath');
      return;
    }

    var content = fastfile.readAsStringSync();

    // Remove existing block
    content = _stripLaneBlock(content, marker, laneKeyword);

    // Insert before the last 'end' (platform :ios do ... end)
    final lastEndIndex = content.lastIndexOf('end');
    if (lastEndIndex == -1) {
      throw SetupException('Invalid Fastfile format: missing closing "end"');
    }

    content = '${content.substring(0, lastEndIndex)}'
        '\n$laneCode\n'
        '${content.substring(lastEndIndex)}';

    fastfile.writeAsStringSync(content);
    print('  Added lane to: $fastfilePath');
  }

  /// Removes the lane block that starts with [marker] and contains [laneKeyword].
  static String _stripLaneBlock(
    String content,
    String marker,
    String laneKeyword,
  ) {
    final startIndex = content.indexOf(marker);
    if (startIndex == -1) return content;

    // Find lane start
    final laneStart = content.indexOf(laneKeyword, startIndex);
    if (laneStart == -1) return content;

    // Find the lane's end (matching indentation level)
    var depth = 0;
    var endIndex = laneStart;
    final lines = content.substring(laneStart).split('\n');
    var lineCount = 0;
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('lane ') || trimmed.startsWith('do')) {
        depth++;
      }
      if (trimmed == 'end') {
        depth--;
        if (depth <= 0) {
          endIndex = laneStart +
              lines.sublist(0, lineCount + 1).join('\n').length;
          break;
        }
      }
      lineCount++;
    }

    // Remove from the newline before the marker to the newline after end
    var removeStart = startIndex;
    if (removeStart > 0 && content[removeStart - 1] == '\n') {
      removeStart--;
    }
    var removeEnd = endIndex;
    if (removeEnd < content.length && content[removeEnd] == '\n') {
      removeEnd++;
    }

    return content.substring(0, removeStart) + content.substring(removeEnd);
  }

  static void _writeFile(String path, String content,
      {required bool dryRun}) {
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
