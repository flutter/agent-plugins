import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  String srcDir = '../src_repo';
  String destDir = 'skills';

  if (args.length >= 2) {
    srcDir = args[0];
    destDir = args[1];
  } else if (args.isNotEmpty) {
    srcDir = args[0];
  }

  print('📌 Source Directory: $srcDir');
  print('📌 Destination Directory: $destDir');

  final hashFile =
      Platform.environment['SKILLS_HASH_FILE_PATH'] ??
      'tool/.dart_skills_githash';
  const pluginFile = '.claude-plugin/plugin.json';

  // Verify source directory exists
  if (!await Directory(srcDir).exists()) {
    print('❌ Error: Source directory "$srcDir" does not exist.');
    exit(1);
  }

  // 1. Get the latest commit hash from the source repository
  final currentHashResult = await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: srcDir);

  if (currentHashResult.exitCode != 0) {
    print('❌ Error getting current Git hash from source.');
    exit(1);
  }

  final currentHash = (currentHashResult.stdout as String).trim();
  print('📌 Current Dart Repo Git Hash: $currentHash');

  // Create destination directory if it doesn\'t exist
  await Directory(destDir).create(recursive: true);

  // 2. Check if a previously synced hash exists
  final hashFileObj = File(hashFile);
  String? prevHash;

  if (await hashFileObj.exists()) {
    prevHash = (await hashFileObj.readAsString()).trim();
    print('📌 Previously Synced Git Hash: $prevHash');

    if (prevHash == currentHash) {
      print('✅ No changes detected in the source repository (hashes match).');
      print('🚀 Exiting early to save workflow execution time.');
      // Exit code 10 signals to the workflow that no changes were made (and it should not make a PR)
      exit(10);
    }
  }

  bool changesDetected = false;

  // 3. Sync changes using Git Diff
  if (prevHash != null) {
    // Check if the previous hash is still an ancestor (valid in history)
    final isAncestorResult = await Process.run('git', [
      'merge-base',
      '--is-ancestor',
      prevHash,
      currentHash,
    ], workingDirectory: srcDir);

    if (isAncestorResult.exitCode == 0) {
      print(
        '🔄 Fetching incremental diff between $prevHash and $currentHash...',
      );

      // Find files added, modified, or deleted inside skills/
      final diffResult = await Process.run('git', [
        'diff',
        '--name-status',
        '--no-renames',
        prevHash,
        currentHash,
        '--',
        'skills/',
      ], workingDirectory: srcDir);

      if (diffResult.exitCode != 0) {
        print('❌ Error running git diff inside source: ${diffResult.stderr}');
        exit(1);
      }

      final lines = (diffResult.stdout as String).trim().split('\n');
      for (final line in lines) {
        if (line.isEmpty) continue;

        // git diff --name-status returns values like: "M\tskills/some-skill/file.md"
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 2) continue;

        final status = parts[0];
        final srcPath = parts[1];

        // Strip the "skills/" prefix to copy/delete relatively
        final relPath = srcPath.replaceFirst('skills/', '');
        final finalDestPath = '$destDir/$relPath';

        if (status == 'D') {
          print('🗑️ Deleting removed Dart file/folder: $relPath');
          final fileToDelete = File(finalDestPath);
          if (await fileToDelete.exists()) {
            await fileToDelete.delete(recursive: true);
          } else {
            final dirToDelete = Directory(finalDestPath);
            if (await dirToDelete.exists()) {
              await dirToDelete.delete(recursive: true);
            }
          }
          changesDetected = true;
        } else {
          print('📂 Copying added/modified Dart file: $relPath');
          final sourceFile = File('$srcDir/$srcPath');

          if (await sourceFile.exists()) {
            await File(finalDestPath).create(recursive: true);
            await sourceFile.copy(finalDestPath);
            changesDetected = true;
          }
        }
      }
    } else {
      print(
        '⚠️ Previous hash was not found in history. Performing fallback full sync.',
      );
      final success = await _fullSync(srcDir, destDir);
      if (!success) {
        print('❌ Error: Fallback full sync failed.');
        exit(1);
      }
      changesDetected = true;
    }
  } else {
    print(
      '🆕 No previous hash tracked. Performing a clean sync of current Dart skills.',
    );
    final success = await _fullSync(srcDir, destDir);
    if (!success) {
      print('❌ Error: Clean sync failed.');
      exit(1);
    }
    changesDetected = true;
  }

  // 4. Update `.claude-plugin/plugin.json` version if changes were detected
  if (changesDetected) {
    final pluginFileObj = File(pluginFile);
    if (await pluginFileObj.exists()) {
      print('📈 Bumping patch version in $pluginFile...');
      try {
        final content = await pluginFileObj.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        final versionStr = data['version'] as String? ?? '1.0.0';
        final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(versionStr);
        if (match != null) {
          final major = match.group(1)!;
          final minor = match.group(2)!;
          final patch = int.parse(match.group(3)!) + 1;
          data['version'] = '$major.$minor.$patch';

          // Re-write back to json format with clean indentation and trailing newline
          final encoder = const JsonEncoder.withIndent('  ');
          await pluginFileObj.writeAsString('${encoder.convert(data)}\n');
          print('✅ Version bumped successfully to: ${data['version']}');
        }
      } catch (e) {
        print('⚠️ Failed parsing or writing plugin version: $e');
      }
    } else {
      print('⚠️ Warning: $pluginFile not found! Version was not bumped.');
    }
  }

  // 5. Save the new hash to the tracker
  await hashFileObj.writeAsString('$currentHash\n');
  print('✅ Saved commit hash $currentHash to tracker.');
  exit(0);
}

// Fallback Helper to perform complete directory replication
Future<bool> _fullSync(String srcDir, String destDir) async {
  final sourceSkillsDir = Directory('$srcDir/skills');
  if (!await sourceSkillsDir.exists()) {
    print('❌ Error: Source skills/ folder not found.');
    return false;
  }

  // Clean/delete existing sync-managed folders in destDir (skip native flutter-* folders)
  final destSkillsDir = Directory(destDir);
  if (await destSkillsDir.exists()) {
    await for (final entity in destSkillsDir.list()) {
      if (entity is Directory) {
        final dirName = entity.path.split(RegExp(r'[/\\]')).last;
        if (!dirName.startsWith('flutter-')) {
          print('🗑️ Cleaning sync-managed folder: $dirName');
          await entity.delete(recursive: true);
        }
      }
    }
  }

  await for (final entity in sourceSkillsDir.list(recursive: true)) {
    if (entity is File) {
      final relPath = entity.path.replaceFirst('$srcDir/skills/', '');
      final destPath = '$destDir/$relPath';

      await File(destPath).create(recursive: true);
      await entity.copy(destPath);
    }
  }
  return true;
}
