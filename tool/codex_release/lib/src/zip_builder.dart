import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'process.dart';
import 'release_manifest.dart';
import 'release_notes.dart';
import 'validator.dart' show manifestPath;

/// A fixed timestamp for every zip entry, so rebuilding the same commit
/// produces a byte-for-byte identical zip.
///
/// The archive package also writes each entry's date and time converted to
/// the build machine's local time zone, so zips are identical only when built
/// in the same time zone. CI always builds in UTC. The date is a day after the
/// zip format's 1980 epoch so it never displays as 1979 in any time zone.
final _fixedTimestamp = DateTime.utc(1980, 1, 2);

/// The interface fields that reference branding images.
const _assetFields = ['composerIcon', 'composerIconDark', 'logo', 'logoDark'];

/// The result of [buildZip].
class BuildResult {
  BuildResult(this.bytes, this.manifest, this.version);

  /// The zip contents.
  final Uint8List bytes;

  /// The release copy of the manifest written into the zip.
  final Map<String, Object?> manifest;

  /// The plugin version.
  final String version;

  /// The file name for the zip, e.g. `dart-flutter-codex-1.0.8.zip`.
  String get fileName => '${manifest['name']}-codex-$version.zip';
}

/// Thrown when the zip can't be built.
class BuildException implements Exception {
  BuildException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Builds the release zip from the repository at [git]'s root.
///
/// The zip contains the release copy of `.codex-plugin/plugin.json`, the
/// branding images it references, and every git-tracked file under `skills/`.
/// If [tag] is given, the manifest version must match it. [releaseNotes]
/// overrides the generated notes.
Future<BuildResult> buildZip(
  Git git, {
  String? tag,
  String? releaseNotes,
}) async {
  final root = git.root;
  final repoManifest = _readRepoManifest(root);
  final version = repoManifest['version'];
  if (version is! String) {
    throw BuildException('$manifestPath has no string "version".');
  }
  if (tag != null && tag != tagFor(version)) {
    throw BuildException(
      'Tag $tag does not match $manifestPath version $version '
      '(expected ${tagFor(version)}).',
    );
  }

  final notes =
      releaseNotes ??
      await generateReleaseNotes(
        git,
        previousTag: await findPreviousTag(git, version),
      );
  final manifest = createReleaseManifest(repoManifest, releaseNotes: notes);

  final files = <String, List<int>>{
    manifestPath: utf8.encode(encodeManifest(manifest)),
  };

  final interface = manifest['interface'];
  if (interface is Map<String, Object?>) {
    for (final field in _assetFields) {
      final value = interface[field];
      if (value is! String || !value.startsWith('./')) continue;
      final relative = value.substring(2);
      final file = File(p.joinAll([root, ...relative.split('/')]));
      if (!file.existsSync()) {
        throw BuildException(
          'interface.$field references $value, which does not exist.',
        );
      }
      files[relative] = file.readAsBytesSync();
    }
  }

  final skillFiles = await git.trackedFiles('skills');
  if (skillFiles.isEmpty) {
    throw BuildException('No tracked files under skills/.');
  }
  for (final path in skillFiles) {
    files[path] = File(p.joinAll([root, ...path.split('/')])).readAsBytesSync();
  }

  return BuildResult(_encode(files), manifest, version);
}

Map<String, Object?> _readRepoManifest(String root) {
  final file = File(p.join(root, '.codex-plugin', 'plugin.json'));
  if (!file.existsSync()) {
    throw BuildException('${file.path} does not exist.');
  }
  final json = jsonDecode(file.readAsStringSync());
  if (json is! Map<String, Object?>) {
    throw BuildException('$manifestPath must contain a JSON object.');
  }
  return json;
}

Uint8List _encode(Map<String, List<int>> files) {
  final archive = Archive();
  for (final path in files.keys.toList()..sort()) {
    archive.add(
      ArchiveFile.bytes(path, files[path]!)
        ..mode =
            0x1a4 // 0644
        ..lastModTime = _fixedTimestamp.millisecondsSinceEpoch ~/ 1000,
    );
  }
  return ZipEncoder().encodeBytes(archive, modified: _fixedTimestamp);
}
