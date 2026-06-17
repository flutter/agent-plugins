// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

/// A dummy SHA256 checksum that represents an invalid/corrupted release file hash.
const _corruptedHash = '0000000000000000000000000000000000000000000000000000000000000000';

/// A mock implementation of the `curl` command line utility.
///
/// Simulates downloading a release artifact by copying the source file from
/// `MOCK_RELEASE_DIR` to the target output path specified by `-o`.
///
/// It ignores other standard `curl` flags.
const _mockCurlScript = r'''
#!/bin/bash
set -eu
outfile=""
url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) outfile="$2"; shift ;;
    --retry) shift ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
filename="$(basename "$url")"
src_file="${MOCK_RELEASE_DIR}/$filename"
if [ -f "$src_file" ]; then
  cp "$src_file" "$outfile"
else
  echo "mock curl: error: source file $src_file not found ($url)" >&2
  exit 1
fi
''';

/// A mock implementation of the `uname` command line utility.
///
/// Outputs the mocked OS (`MOCK_UNAME_S`) or CPU architecture (`MOCK_UNAME_M`)
/// depending on whether it is executed with `-s` or `-m` flags.
const _mockUnameScript = r'''
#!/bin/bash
if [ "$1" = "-s" ]; then
  echo "${MOCK_UNAME_S:-Darwin}"
elif [ "$1" = "-m" ]; then
  echo "${MOCK_UNAME_M:-arm64}"
fi
''';

void main() {
  group('install.sh integration', () {
    late Directory tempDir;
    late Directory mockBinDir;
    late Directory mockReleaseDir;
    late Directory installDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('install_sh_test.');
      mockBinDir = await Directory(p.join(tempDir.path, 'bin')).create();
      mockReleaseDir = await Directory(p.join(tempDir.path, 'mock_release')).create();
      installDir = await Directory(p.join(tempDir.path, 'install')).create();

      // Write mock uname script
      final unameFile = File(p.join(mockBinDir.path, 'uname'));
      await unameFile.writeAsString(_mockUnameScript);
      final ProcessResult chmodUnameResult = await Process.run('chmod', ['+x', unameFile.path]);
      expect(
        chmodUnameResult.exitCode,
        0,
        reason: 'chmod failed for uname mock: ${chmodUnameResult.stderr}',
      );

      // Write mock curl script
      final curlFile = File(p.join(mockBinDir.path, 'curl'));
      await curlFile.writeAsString(_mockCurlScript);
      final ProcessResult chmodCurlResult = await Process.run('chmod', ['+x', curlFile.path]);
      expect(
        chmodCurlResult.exitCode,
        0,
        reason: 'chmod failed for curl mock: ${chmodCurlResult.stderr}',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Simulates a packaged GitHub release asset by writing a dummy binary,
    /// compressing it to a `.tar.gz` archive in the mock release directory,
    /// and generating the corresponding `SHA256SUMS` checksum file.
    ///
    /// If [shouldCorruptHash] is true, the `SHA256SUMS` file will be written with
    /// an invalid hash to test checksum verification failure paths.
    Future<void> createMockRelease({
      required String os,
      required String arch,
      required String binaryContent,
      bool shouldCorruptHash = false,
    }) async {
      final target = '$os-$arch';
      final binaryName = 'dart_skills_lint-$target';
      final archiveName = 'dart_skills_lint-$target.tar.gz';

      // Create dummy binary file
      final dummyBin = File(p.join(tempDir.path, binaryName));
      await dummyBin.writeAsString(binaryContent);
      final ProcessResult chmodBinResult = await Process.run('chmod', ['+x', dummyBin.path]);
      expect(
        chmodBinResult.exitCode,
        0,
        reason: 'chmod failed for dummy binary: ${chmodBinResult.stderr}',
      );

      // Package it into tar.gz
      final ProcessResult tarResult = await Process.run('tar', [
        '-czf',
        p.join(mockReleaseDir.path, archiveName),
        '-C',
        tempDir.path,
        binaryName,
      ]);
      expect(tarResult.exitCode, 0, reason: 'tar packaging failed: ${tarResult.stderr}');

      // Get SHA256 sum
      var hash = '';
      // TODO(reidbaker): Re-add CertUtil checksum verification for Windows hosts. https://github.com/flutter/skills/issues/164
      final ProcessResult shaProcess = await Process.run('shasum', [
        '-a',
        '256',
        p.join(mockReleaseDir.path, archiveName),
      ]);
      if (shaProcess.exitCode == 0) {
        hash = shaProcess.stdout.toString().trim().split(' ')[0];
      } else {
        final ProcessResult sha256Process = await Process.run('sha256sum', [
          p.join(mockReleaseDir.path, archiveName),
        ]);
        if (sha256Process.exitCode == 0) {
          hash = sha256Process.stdout.toString().trim().split(' ')[0];
        }
      }

      if (hash.isEmpty) {
        throw StateError('Could not calculate SHA256 hash using shasum or sha256sum.');
      }

      final String finalHash = shouldCorruptHash ? _corruptedHash : hash;

      final sha256sums = File(p.join(mockReleaseDir.path, 'SHA256SUMS'));
      await sha256sums.writeAsString('$finalHash  $archiveName\n');
    }

    Future<void> runInstallScriptTest({
      required String os,
      required String arch,
      required String mockUnameS,
      required String mockUnameM,
      required bool simulateLaunchFailure,
      required int expectedExitCode,
      required bool expectInstalled,
    }) async {
      const version = '0.4.0-test';
      final binaryContent = simulateLaunchFailure
          ? '#!/usr/bin/env bash\nexit 1\n'
          : '#!/usr/bin/env bash\necho "mock-cli-help"\n';

      await createMockRelease(os: os, arch: arch, binaryContent: binaryContent);

      // TODO(reidbaker): Use Windows path separator (;) when running on Windows hosts. https://github.com/flutter/skills/issues/164
      final newPath = '${mockBinDir.path}:${Platform.environment['PATH']}';
      final String packageRoot = _getPackageRoot();
      final String scriptPath = p.join(packageRoot, 'scripts', 'install.sh');

      final TestProcess process = await TestProcess.start(
        'bash',
        [scriptPath],
        environment: {
          'PATH': newPath,
          'MOCK_UNAME_S': mockUnameS,
          'MOCK_UNAME_M': mockUnameM,
          'MOCK_RELEASE_DIR': mockReleaseDir.path,
          'INSTALL_DIR': installDir.path,
          'VERSION': version,
        },
      );

      await process.shouldExit(expectedExitCode);

      final installedFile = File(p.join(installDir.path, 'dart_skills_lint'));
      expect(installedFile.existsSync(), equals(expectInstalled));

      if (expectInstalled && expectedExitCode == 0) {
        if (simulateLaunchFailure) {
          final List<String> stdout = await process.stdout.rest.toList();
          expect(
            stdout.any((line) => line.contains('launch check failed — likely Gatekeeper')),
            isTrue,
          );
        } else {
          final ProcessResult runResult = await Process.run(installedFile.path, ['--help']);
          expect(runResult.stdout.toString().trim(), equals('mock-cli-help'));
        }
      } else if (expectedExitCode == 1 && simulateLaunchFailure) {
        final List<String> stderr = await process.stderr.rest.toList();
        expect(stderr.any((line) => line.contains('failed to launch')), isTrue);
      }
    }

    test('successful installation on macos-arm64', () async {
      await runInstallScriptTest(
        os: 'macos',
        arch: 'arm64',
        mockUnameS: 'Darwin',
        mockUnameM: 'arm64',
        simulateLaunchFailure: false,
        expectedExitCode: 0,
        expectInstalled: true,
      );
    });

    test('successful installation on linux-x64', () async {
      await runInstallScriptTest(
        os: 'linux',
        arch: 'x64',
        mockUnameS: 'Linux',
        mockUnameM: 'x86_64',
        simulateLaunchFailure: false,
        expectedExitCode: 0,
        expectInstalled: true,
      );
    });

    test('fails on linux if installed binary fails launch check', () async {
      await runInstallScriptTest(
        os: 'linux',
        arch: 'x64',
        mockUnameS: 'Linux',
        mockUnameM: 'x86_64',
        simulateLaunchFailure: true,
        expectedExitCode: 1,
        expectInstalled: true,
      );
    });

    test('succeeds on macos even if installed binary fails launch check', () async {
      await runInstallScriptTest(
        os: 'macos',
        arch: 'arm64',
        mockUnameS: 'Darwin',
        mockUnameM: 'arm64',
        simulateLaunchFailure: true,
        expectedExitCode: 0,
        expectInstalled: true,
      );
    });

    test('fails if checksum mismatch', () async {
      const version = '0.4.0-test';
      await createMockRelease(
        os: 'macos',
        arch: 'arm64',
        binaryContent: 'dummy',
        shouldCorruptHash: true,
      );

      // TODO(reidbaker): Use Windows path separator (;) when running on Windows hosts. https://github.com/flutter/skills/issues/164
      final newPath = '${mockBinDir.path}:${Platform.environment['PATH']}';
      final String packageRoot = _getPackageRoot();
      final String scriptPath = p.join(packageRoot, 'scripts', 'install.sh');

      final TestProcess process = await TestProcess.start(
        'bash',
        [scriptPath],
        environment: {
          'PATH': newPath,
          'MOCK_UNAME_S': 'Darwin',
          'MOCK_UNAME_M': 'arm64',
          'MOCK_RELEASE_DIR': mockReleaseDir.path,
          'INSTALL_DIR': installDir.path,
          'VERSION': version,
        },
      );

      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.any((line) => line.contains('SHA256 mismatch')), isTrue);
      await process.shouldExit(1);
    });

    group('missing required tools', () {
      final requiredTools = <String>['curl', 'tar', 'awk'];

      for (var i = 0; i < requiredTools.length; i++) {
        final String missingTool = requiredTools[i];

        test('fails if required tool $missingTool is missing', () async {
          // Create a directory containing mock uname and all required tools before this one
          final Directory testBinDir = await Directory(
            p.join(tempDir.path, 'bin_$missingTool'),
          ).create();

          // Always copy mock uname
          final mockUnameFile = File(p.join(mockBinDir.path, 'uname'));
          await mockUnameFile.copy(p.join(testBinDir.path, 'uname'));
          final ProcessResult chmodUnameResult = await Process.run('chmod', [
            '+x',
            p.join(testBinDir.path, 'uname'),
          ]);
          expect(chmodUnameResult.exitCode, 0);

          // Copy all mock tools prior to this one in the dependency order
          for (var j = 0; j < i; j++) {
            final String toolToCopy = requiredTools[j];
            if (toolToCopy == 'curl') {
              final mockCurlFile = File(p.join(mockBinDir.path, 'curl'));
              await mockCurlFile.copy(p.join(testBinDir.path, 'curl'));
              final ProcessResult chmodCurlResult = await Process.run('chmod', [
                '+x',
                p.join(testBinDir.path, 'curl'),
              ]);
              expect(chmodCurlResult.exitCode, 0);
            } else {
              // Write a dummy script for other tools (like tar) so they pass command -v check
              final dummyFile = File(p.join(testBinDir.path, toolToCopy));
              await dummyFile.writeAsString('#!/bin/bash\nexit 0\n');
              final ProcessResult chmodDummyResult = await Process.run('chmod', [
                '+x',
                dummyFile.path,
              ]);
              expect(chmodDummyResult.exitCode, 0);
            }
          }

          final String packageRoot = _getPackageRoot();
          final String scriptPath = p.join(packageRoot, 'scripts', 'install.sh');

          final TestProcess process = await TestProcess.start(
            '/bin/bash',
            [scriptPath],
            environment: {
              'PATH': testBinDir.path,
              'MOCK_UNAME_S': 'Darwin',
              'MOCK_UNAME_M': 'arm64',
              'INSTALL_DIR': installDir.path,
            },
          );

          final List<String> stderr = await process.stderr.rest.toList();
          expect(
            stderr.any((line) => line.contains("required tool '$missingTool' not found on PATH")),
            isTrue,
          );
          await process.shouldExit(1);
        });
      }

      test('fails if both sha256sum and shasum are missing', () async {
        final Directory testBinDir = await Directory(p.join(tempDir.path, 'bin_no_hash')).create();

        // Copy mock uname, curl, and dummy tar, awk
        final mockUnameFile = File(p.join(mockBinDir.path, 'uname'));
        await mockUnameFile.copy(p.join(testBinDir.path, 'uname'));
        final ProcessResult chmodUname = await Process.run('chmod', [
          '+x',
          p.join(testBinDir.path, 'uname'),
        ]);
        expect(chmodUname.exitCode, 0);

        final mockCurlFile = File(p.join(mockBinDir.path, 'curl'));
        await mockCurlFile.copy(p.join(testBinDir.path, 'curl'));
        final ProcessResult chmodCurl = await Process.run('chmod', [
          '+x',
          p.join(testBinDir.path, 'curl'),
        ]);
        expect(chmodCurl.exitCode, 0);

        final dummyTar = File(p.join(testBinDir.path, 'tar'));
        await dummyTar.writeAsString('#!/bin/bash\nexit 0\n');
        final ProcessResult chmodTar = await Process.run('chmod', ['+x', dummyTar.path]);
        expect(chmodTar.exitCode, 0);

        final dummyAwk = File(p.join(testBinDir.path, 'awk'));
        await dummyAwk.writeAsString('#!/bin/bash\nexit 0\n');
        final ProcessResult chmodAwk = await Process.run('chmod', ['+x', dummyAwk.path]);
        expect(chmodAwk.exitCode, 0);

        final String packageRoot = _getPackageRoot();
        final String scriptPath = p.join(packageRoot, 'scripts', 'install.sh');

        final TestProcess process = await TestProcess.start(
          '/bin/bash',
          [scriptPath],
          environment: {
            'PATH': testBinDir.path,
            'MOCK_UNAME_S': 'Darwin',
            'MOCK_UNAME_M': 'arm64',
            'INSTALL_DIR': installDir.path,
          },
        );

        final List<String> stderr = await process.stderr.rest.toList();
        expect(
          stderr.any(
            (line) =>
                line.contains('sha256sum') && line.contains('shasum') && line.contains('not found'),
          ),
          isTrue,
        );
        await process.shouldExit(1);
      });
    });

    test('fails on unsupported architecture', () async {
      // TODO(reidbaker): Use Windows path separator (;) when running on Windows hosts. https://github.com/flutter/skills/issues/164
      final newPath = '${mockBinDir.path}:${Platform.environment['PATH']}';
      final String packageRoot = _getPackageRoot();
      final String scriptPath = p.join(packageRoot, 'scripts', 'install.sh');

      final TestProcess process = await TestProcess.start(
        'bash',
        [scriptPath],
        environment: {
          'PATH': newPath,
          'MOCK_UNAME_S': 'Linux',
          'MOCK_UNAME_M': 'i386',
          'INSTALL_DIR': installDir.path,
        },
      );

      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.any((line) => line.contains('unsupported architecture')), isTrue);
      await process.shouldExit(1);
    });
    // TODO(reidbaker): Support running install.sh tests on Windows hosts. https://github.com/flutter/skills/issues/164
  }, skip: Platform.isWindows ? 'install.sh is not supported on Windows' : null);
}

String _getPackageRoot() {
  final String currentPath = Directory.current.path;
  Directory dir = Directory(currentPath);
  while (dir.path != '/' && dir.path.isNotEmpty) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() && pubspec.readAsStringSync().contains('name: dart_skills_lint')) {
      return dir.path;
    }
    dir = dir.parent;
  }
  // Fallback to searching subdirectories
  final subdir = Directory(p.join(currentPath, 'tool', 'dart_skills_lint'));
  if (subdir.existsSync()) {
    return subdir.path;
  }
  return currentPath;
}
