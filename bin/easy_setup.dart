// easy_setup CLI 진입점
//
// Flutter 프로젝트 설정을 자동으로 구성하는 CLI 도구입니다.
//
// Commands:
//   flavor    Flutter flavor 환경 설정 (Android + iOS)  [default]
//   ci-cd     CI/CD 파이프라인 설정 생성 (Fastlane + GitHub Actions + Bundle ID 등록)
//
// Global Options:
//   -h, --help          도움말 표시
//   -n, --dry-run       실제 파일 변경 없이 미리보기만 수행
//   -p, --project-root  Flutter 프로젝트 루트 경로 지정 (기본: 자동 탐지)
import 'dart:io';

import 'package:args/args.dart';
import 'package:easy_setup/src/commands/ci_cd_command.dart';
import 'package:easy_setup/src/commands/flavor_command.dart';
import 'package:easy_setup/src/exceptions.dart';

Future<void> main(List<String> arguments) async {
  // 글로벌 옵션 파서 설정
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Preview changes without writing any files.',
    )
    ..addOption(
      'project-root',
      abbr: 'p',
      help: 'Path to Flutter project root (default: auto-detect).',
    );

  // 서브커맨드 결정: 첫 번째 인자가 알려진 커맨드인지 확인
  String command = 'flavor'; // 기본값 — 하위 호환성
  var commandArgs = arguments;

  if (arguments.isNotEmpty && !arguments.first.startsWith('-')) {
    final first = arguments.first;
    if (first == 'flavor' || first == 'ci-cd') {
      command = first;
      commandArgs = arguments.sublist(1);
    }
  }

  // 인자 파싱
  ArgResults args;
  try {
    args = parser.parse(commandArgs);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}\n');
    _printUsage(parser);
    exit(1);
  }

  // --help 플래그 처리
  if (args['help'] as bool) {
    _printUsage(parser);
    return;
  }

  final dryRun = args['dry-run'] as bool;
  final projectRoot = args['project-root'] as String?;

  // 서브커맨드 실행
  try {
    switch (command) {
      case 'flavor':
        FlavorCommand.run(dryRun: dryRun, projectRoot: projectRoot);
      case 'ci-cd':
        await CiCdCommand.run(dryRun: dryRun, projectRoot: projectRoot);
    }
  } on SetupException catch (e) {
    stderr.writeln('\n✗ ${e.message}');
    exit(1);
  } catch (e, st) {
    stderr.writeln('\n✗ Unexpected error: $e');
    stderr.writeln(st);
    exit(1);
  }
}

/// CLI 사용법과 easy_setup.yaml 예시를 출력합니다.
void _printUsage(ArgParser parser) {
  print('easy_setup — Configure Flutter project setup\n');
  print('Usage: easy_setup <command> [options]\n');
  print('Commands:');
  print('  flavor    Configure Flutter flavors for Android & iOS (default)');
  print('  ci-cd     Generate CI/CD pipeline files, register Bundle IDs,');
  print('            and create register lane (Fastlane + GitHub Actions)\n');
  print(parser.usage);
  print('');
  print('Reads easy_setup.yaml in the Flutter project root.');
  print('');
  print('Example easy_setup.yaml:');
  print('');
  print('  easy_setup:');
  print('    flavors:');
  print('      dev:');
  print('        bundle_id: com.example.app.dev');
  print('        name: MyApp Dev');
  print('      prod:');
  print('        bundle_id: com.example.app');
  print('        name: MyApp');
  print('');
  print('    ci_cd:');
  print('      ios:');
  print('        storage: https://github.com/user/certs.git');
  print('        team_id: XXXXXXXXXX');
  print('        itc_team_id: YYYYYYYYYY');
  print('        api_key:');
  print('          id: KEY_ID');
  print('          issuer_id: ISSUER_ID');
  print('          key_path: fastlane/AuthKey.p8');
}
