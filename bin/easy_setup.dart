// easy_setup CLI 진입점
//
// Flutter 프로젝트의 flavor(빌드 변형) 설정을 자동으로 구성하는 CLI 도구입니다.
// Android(build.gradle)와 iOS(xcconfig, pbxproj, scheme, Info.plist, Podfile)를
// 한 번의 명령으로 모두 설정합니다.
//
// 사용법:
//   easy_setup [options]
//
// 옵션:
//   -h, --help          도움말 표시
//   -n, --dry-run       실제 파일 변경 없이 미리보기만 수행
//   -p, --project-root  Flutter 프로젝트 루트 경로 지정 (기본: 자동 탐지)
import 'dart:io';

import 'package:args/args.dart';
import 'package:easy_setup/src/commands/flavor_command.dart';
import 'package:easy_setup/src/exceptions.dart';

void main(List<String> arguments) {
  // CLI 옵션 파서 설정
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

  // 인자 파싱 — 잘못된 형식이면 사용법을 출력하고 종료
  ArgResults args;
  try {
    args = parser.parse(arguments);
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

  // flavor 설정 파이프라인 실행
  try {
    FlavorCommand.run(dryRun: dryRun, projectRoot: projectRoot);
  } on SetupException catch (e) {
    // 예상된 오류 (파일 미발견, 파싱 실패 등)
    stderr.writeln('\n✗ ${e.message}');
    exit(1);
  } catch (e, st) {
    // 예상치 못한 오류 — 스택 트레이스 포함 출력
    stderr.writeln('\n✗ Unexpected error: $e');
    stderr.writeln(st);
    exit(1);
  }
}

/// CLI 사용법과 easy_setup.yaml 예시를 출력합니다.
void _printUsage(ArgParser parser) {
  print('easy_setup — Configure Flutter flavor setup for Android & iOS\n');
  print('Usage: easy_setup [options]\n');
  print(parser.usage);
  print('');
  print('Reads easy_setup.yaml in the Flutter project root.');
  print('Example easy_setup.yaml:');
  print('');
  print('  flavors:');
  print('    dev:');
  print('      bundle_id: com.example.app.dev');
  print('      name: MyApp Dev');
  print('    prod:');
  print('      bundle_id: com.example.app');
  print('      name: MyApp');
}
