import 'dart:convert';

/// `description` for the skills-only release, without the MCP server.
///
/// The repo manifest describes the full plugin, including the Dart MCP server.
/// The zip for the OpenAI portal leaves the server out, so these replace the
/// repo text. Update them if the repo descriptions change.
const releaseDescription =
    'Official Codex plugin for Dart and Flutter that installs Flutter/Dart '
    'Skills for building natively compiled, visually stunning applications '
    'for mobile, web, desktop, and embedded devices from a single codebase.';

/// `interface.longDescription` for the skills-only release.
const releaseLongDescription =
    'Use official Dart and Flutter skills to develop apps, run workflows, and '
    'manage code from Codex.';

/// Creates the release copy of the repo's `.codex-plugin/plugin.json`.
///
/// Removes every MCP reference, replaces the descriptions with
/// [releaseDescription] and [releaseLongDescription], and sets
/// `extensions.com.openai.publication.release_notes` to [releaseNotes]. Every
/// other field is copied unchanged. [repoManifest] isn't modified.
Map<String, Object?> createReleaseManifest(
  Map<String, Object?> repoManifest, {
  required String releaseNotes,
}) {
  // Deep copy so the caller's map is never changed.
  final manifest = jsonDecode(jsonEncode(repoManifest)) as Map<String, Object?>;

  manifest.remove('mcpServers');
  manifest['description'] = releaseDescription;

  final keywords = manifest['keywords'];
  if (keywords is List) {
    keywords.removeWhere((k) => k is String && k.toLowerCase() == 'mcp');
  }

  final interface = manifest['interface'];
  if (interface is Map<String, Object?>) {
    interface['longDescription'] = releaseLongDescription;
    final capabilities = interface['capabilities'];
    if (capabilities is List) {
      capabilities.removeWhere((c) => c is String && c.toLowerCase() == 'mcp');
    }
  }

  final extensions =
      (manifest['extensions'] ??= <String, Object?>{}) as Map<String, Object?>;
  final openai =
      (extensions['com.openai'] ??= <String, Object?>{})
          as Map<String, Object?>;
  final publication =
      (openai['publication'] ??= <String, Object?>{}) as Map<String, Object?>;
  publication['release_notes'] = releaseNotes;

  return manifest;
}

/// Encodes [manifest] the way it's written into the zip.
String encodeManifest(Map<String, Object?> manifest) =>
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
