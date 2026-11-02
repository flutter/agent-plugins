import 'process.dart';

/// Prefix of the release tags, e.g. `codex-plugin-v1.0.8`.
const tagPrefix = 'codex-plugin-v';

/// The release tag for [version].
String tagFor(String version) => '$tagPrefix$version';

/// A `major.minor.patch` version, ignoring pre-release and build suffixes.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  ReleaseVersion(
    this.major,
    this.minor,
    this.patch, {
    this.isPreRelease = false,
  });

  /// Major version.
  final int major;

  /// Minor version.
  final int minor;

  /// Patch version.
  final int patch;

  /// Whether the version has a pre-release suffix such as `-rc1`.
  final bool isPreRelease;

  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(-[^+]+)?(\+.*)?$');

  /// Parses [text], returning null if it isn't a semantic version.
  static ReleaseVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    return ReleaseVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      isPreRelease: match[4] != null,
    );
  }

  @override
  int compareTo(ReleaseVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// Finds the most recent release tag before [version] that's reachable from
/// HEAD, ignoring pre-release tags such as `codex-plugin-v1.0.7-rc1`.
Future<String?> findPreviousTag(Git git, String version) async {
  final current = ReleaseVersion.tryParse(version);
  if (current == null) return null;
  final output = await git([
    'tag',
    '--list',
    '$tagPrefix*',
    '--merged',
    'HEAD',
  ]);
  String? best;
  ReleaseVersion? bestVersion;
  for (final tag in output.split('\n').map((t) => t.trim())) {
    if (!tag.startsWith(tagPrefix)) continue;
    final candidate = ReleaseVersion.tryParse(tag.substring(tagPrefix.length));
    if (candidate == null || candidate.isPreRelease) continue;
    if (candidate.compareTo(current) >= 0) continue;
    if (bestVersion == null || candidate.compareTo(bestVersion) > 0) {
      best = tag;
      bestVersion = candidate;
    }
  }
  return best;
}

/// Summarizes what changed since [previousTag] for the portal's release notes.
///
/// Lists skills added, updated, and removed, and notes manifest or asset
/// changes. If there's no previous tag, describes the skills included.
Future<String> generateReleaseNotes(Git git, {String? previousTag}) async {
  final current = await _skillDirectories(git, 'HEAD');
  if (previousTag == null) {
    return 'Dart and Flutter skills for Codex: ${current.length} skills '
        '(${current.join(', ')}).';
  }

  final previous = await _skillDirectories(git, previousTag);
  final changedPaths = (await git([
    'diff',
    '--name-only',
    previousTag,
    'HEAD',
    '--',
    'skills',
    '.codex-plugin',
    'assets',
  ])).split('\n').where((p) => p.isNotEmpty).toList();

  final changedSkills = {
    for (final path in changedPaths)
      if (path.startsWith('skills/') && path.split('/').length > 2)
        path.split('/')[1],
  };
  final added = current.where((s) => !previous.contains(s)).toList();
  final removed = previous.where((s) => !current.contains(s)).toList();
  final updated = current
      .where((s) => previous.contains(s) && changedSkills.contains(s))
      .toList();
  final metadataChanged = changedPaths.any(
    (p) => p.startsWith('.codex-plugin/') || p.startsWith('assets/'),
  );

  final lines = [
    if (added.isNotEmpty) 'Added skills: ${added.join(', ')}.',
    if (updated.isNotEmpty) 'Updated skills: ${updated.join(', ')}.',
    if (removed.isNotEmpty) 'Removed skills: ${removed.join(', ')}.',
    if (metadataChanged) 'Updated plugin listing details.',
  ];
  return lines.isEmpty ? 'Maintenance release.' : lines.join('\n');
}

Future<List<String>> _skillDirectories(Git git, String ref) async {
  final output = await git(['ls-tree', '-d', '--name-only', ref, 'skills/']);
  return output
      .split('\n')
      .where((p) => p.startsWith('skills/'))
      .map((p) => p.substring('skills/'.length))
      .toList()
    ..sort();
}
