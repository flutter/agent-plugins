import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'finding.dart';
import 'image_size.dart';

/// Path of the Codex compatibility manifest inside the zip.
const manifestPath = '.codex-plugin/plugin.json';

/// Categories accepted by the OpenAI plugin directory.
const allowedCategories = {
  'Productivity',
  'Creativity',
  'Developer Tools',
  'Business & Operations',
  'Data & Analytics',
  'Communication',
  'Education & Research',
  'Security',
  'Finance',
  'Healthcare',
  'Travel',
  'Entertainment',
  'Other',
};

const _maxZipBytes = 100 * 1000 * 1000;
const _maxEntries = 5000;
const _maxUncompressedBytes = 512 * 1024 * 1024;
const _maxEntryBytes = 100 * 1024 * 1024;
const _maxPathSegments = 20;
const _maxImageBytes = 5 * 1024 * 1024;
const _minImagePixels = 48;
const _maxRasterPixels = 4096;

final _semver = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
  r'(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
  r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
);
final _pluginName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');
final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');
final _mcpWord = RegExp(r'\bMCP\b', caseSensitive: false);
final _mention = RegExp(r'@\w');
// Control characters, DEL, and Unicode line/paragraph separators.
final _unsupportedChars = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u2028\u2029]',
);
final _lineBreak = RegExp('[\r\n]');

/// Validates a Codex plugin zip against OpenAI's documented package rules.
///
/// Uses the final directory submission limits where they're stricter than the
/// upload limits, and the skills-only submission path. If [expectedVersion] is
/// given, the manifest `version` must match it (e.g. the release tag).
///
/// Returns every problem found; an empty list means the zip passed.
List<Finding> validateZip(Uint8List zipBytes, {String? expectedVersion}) {
  final findings = <Finding>[];
  if (zipBytes.length > _maxZipBytes) {
    findings.add(
      Finding(
        'archive_too_large',
        'Compressed ZIP is ${zipBytes.length} bytes; the limit is 100 MB.',
      ),
    );
  }

  // ZipDecoder returns an empty archive for non-zip input instead of
  // throwing, so check for a local file header or end-of-central-directory
  // signature first.
  final isZip =
      zipBytes.length >= 4 &&
      zipBytes[0] == 0x50 &&
      zipBytes[1] == 0x4B &&
      ((zipBytes[2] == 0x03 && zipBytes[3] == 0x04) ||
          (zipBytes[2] == 0x05 && zipBytes[3] == 0x06));
  if (!isZip) {
    return findings..add(
      const Finding(
        'archive_format_not_zip',
        'Archive must be a valid ZIP file.',
      ),
    );
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (e) {
    return findings
      ..add(Finding('archive_format_not_zip', 'Not a valid ZIP file: $e'));
  }

  final package = _Package.fromArchive(archive, findings);
  if (package == null) return findings;

  final manifest = _readManifest(package, findings);
  if (manifest != null) {
    _ManifestValidator(manifest, package, findings, expectedVersion).validate();
  }
  _validateSkills(package, findings);
  _validateExcludedFiles(package, findings);
  return findings;
}

/// The files in a zip, keyed by normalized path.
class _Package {
  _Package(this.files, this.directories);

  final Map<String, Uint8List> files;
  final Set<String> directories;

  static _Package? fromArchive(Archive archive, List<Finding> findings) {
    if (archive.isEmpty) {
      findings.add(
        const Finding('archive_empty', 'Archive must not be empty.'),
      );
      return null;
    }
    if (archive.length > _maxEntries) {
      findings.add(
        Finding(
          'archive_too_many_entries',
          'Archive has ${archive.length} entries; the limit is 5,000.',
        ),
      );
    }

    final files = <String, Uint8List>{};
    final directories = <String>{};
    final normalized = <String, String>{};
    var totalBytes = 0;

    for (final entry in archive) {
      final rawName = entry.name;
      final name = entry.isFile
          ? rawName
          : rawName.replaceFirst(RegExp(r'/$'), '');
      if (!_checkEntryPath(rawName, name, findings)) continue;

      if (entry.isSymbolicLink) {
        findings.add(
          Finding(
            'archive_member_type_unsupported',
            'Archive entries must be regular files or directories.',
            path: name,
          ),
        );
        continue;
      }
      if (files.containsKey(name) || directories.contains(name)) {
        findings.add(
          Finding(
            'archive_member_path_duplicate',
            'Archive entry path must be unique.',
            path: name,
          ),
        );
        continue;
      }
      final key = name.toLowerCase();
      final existing = normalized[key];
      if (existing != null) {
        findings.add(
          Finding(
            'archive_member_path_normalization_collision',
            'Paths must stay unique after case normalization (collides with $existing).',
            path: name,
          ),
        );
      }
      normalized[key] = name;

      if (entry.isFile) {
        final bytes = entry.readBytes() ?? Uint8List(0);
        if (bytes.length > _maxEntryBytes) {
          findings.add(
            Finding(
              'archive_member_too_large',
              'Archive entry must not exceed 100 MiB.',
              path: name,
            ),
          );
        }
        totalBytes += bytes.length;
        files[name] = bytes;
      } else {
        directories.add(name);
      }
    }

    if (totalBytes > _maxUncompressedBytes) {
      findings.add(
        const Finding(
          'archive_uncompressed_too_large',
          'Extracted archive must not exceed 512 MiB.',
        ),
      );
    }

    // Implicit parent directories, and file paths that are also directories.
    for (final path in files.keys) {
      final segments = path.split('/');
      for (var i = 1; i < segments.length; i++) {
        final parent = segments.sublist(0, i).join('/');
        if (files.containsKey(parent)) {
          findings.add(
            Finding(
              'archive_member_path_type_conflict',
              'A file path cannot also be a directory.',
              path: parent,
            ),
          );
        }
        directories.add(parent);
      }
    }

    // This repo builds the plugin root at the archive root.
    if (!files.containsKey(manifestPath)) {
      final topLevel = {
        ...files.keys,
        ...directories,
      }.map((p) => p.split('/').first).toSet();
      final wrapped =
          topLevel.length == 1 &&
          files.containsKey('${topLevel.single}/$manifestPath');
      findings.add(
        Finding(
          'plugin_manifest_missing',
          wrapped
              ? 'The plugin is inside a top-level "${topLevel.single}/" directory; the release zip must have the plugin root at the archive root.'
              : 'ZIP must contain $manifestPath at the archive root.',
        ),
      );
      return null;
    }
    return _Package(files, directories);
  }

  /// Names of entries directly inside [directory].
  Iterable<String> childrenOf(String directory) sync* {
    final prefix = '$directory/';
    final seen = <String>{};
    for (final path in [...files.keys, ...directories]) {
      if (!path.startsWith(prefix)) continue;
      final child = path.substring(prefix.length).split('/').first;
      if (child.isNotEmpty && seen.add(child)) yield child;
    }
  }
}

bool _checkEntryPath(String rawName, String name, List<Finding> findings) {
  void add(String code, String message) =>
      findings.add(Finding(code, message, path: rawName));

  if (name.isEmpty) {
    add('archive_member_path_empty', 'Archive entry path must not be empty.');
    return false;
  }
  if (name.trim() != name) {
    add(
      'archive_member_path_has_outer_whitespace',
      'Archive entry path must not begin or end with whitespace.',
    );
  }
  if (name.contains(r'\')) {
    add(
      'archive_member_path_has_backslash',
      'Archive entry path must use "/", not backslashes.',
    );
    return false;
  }
  if (name.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(name)) {
    add(
      'archive_member_path_absolute',
      'Archive entry path must be relative to the archive root.',
    );
    return false;
  }
  final segments = name.split('/');
  if (segments.contains('')) {
    add(
      'archive_member_path_has_empty_segment',
      'Archive entry path must not contain empty segments.',
    );
    return false;
  }
  if (segments.contains('..')) {
    add(
      'archive_member_path_has_parent_segment',
      'Archive entry path must not contain ".." segments.',
    );
    return false;
  }
  if (segments.length > _maxPathSegments) {
    add(
      'archive_member_path_too_deep',
      'Archive entry path must contain at most 20 segments.',
    );
  }
  return true;
}

Map<String, Object?>? _readManifest(_Package package, List<Finding> findings) {
  final String text;
  try {
    text = utf8.decode(package.files[manifestPath]!);
  } on FormatException {
    findings.add(
      const Finding(
        'plugin_manifest_unreadable',
        'Plugin manifest must be readable UTF-8 text.',
        path: manifestPath,
      ),
    );
    return null;
  }
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    findings.add(
      Finding(
        'plugin_manifest_json_malformed',
        'Plugin manifest must contain valid JSON: ${e.message}',
        path: manifestPath,
      ),
    );
    return null;
  }
  if (json is! Map<String, Object?>) {
    findings.add(
      const Finding(
        'plugin_manifest_root_not_object',
        'Plugin manifest must contain a JSON object at the top level.',
        path: manifestPath,
      ),
    );
    return null;
  }
  return json;
}

class _ManifestValidator {
  _ManifestValidator(
    this.manifest,
    this.package,
    this.findings,
    this.expectedVersion,
  );

  final Map<String, Object?> manifest;
  final _Package package;
  final List<Finding> findings;
  final String? expectedVersion;

  void add(String code, String message, String field) =>
      findings.add(Finding(code, message, path: field));

  void validate() {
    _identity();
    _author();
    _url(manifest, 'homepage', 'plugin_homepage', maxLength: 2048);
    _skillsPath();
    _excludedFields();

    final interface = manifest['interface'];
    if (interface == null) {
      add(
        'plugin_interface_wrong_type',
        'interface is required in the Codex format.',
        'interface',
      );
    } else if (interface is! Map<String, Object?>) {
      add(
        'plugin_interface_wrong_type',
        'interface must be a JSON object.',
        'interface',
      );
    } else {
      _listing(interface);
      _assets(interface);
    }
    _releaseNotes();
  }

  void _identity() {
    final name = _requiredString('name', 'plugin_name');
    if (name != null) {
      if (name.length > 64) {
        add(
          'plugin_name_too_long',
          'name must be 64 characters or fewer.',
          'name',
        );
      }
      if (!_pluginName.hasMatch(name)) {
        add(
          'plugin_name_format',
          'name must start with an ASCII letter or digit and use only letters, digits, "_", or "-".',
          'name',
        );
      }
    }

    final version = _requiredString('version', 'plugin_version');
    if (version != null) {
      if (version.length > 64) {
        add(
          'plugin_version_too_long',
          'version must be 64 characters or fewer.',
          'version',
        );
      }
      if (!_semver.hasMatch(version)) {
        add(
          'plugin_version_not_semver',
          'version must be a semantic version, such as 1.0.0.',
          'version',
        );
      }
      if (expectedVersion != null && version != expectedVersion) {
        add(
          'release_version_mismatch',
          'version is $version, but the release tag is for $expectedVersion.',
          'version',
        );
      }
    }

    final description = _requiredString('description', 'plugin_description');
    if (description != null) {
      if (description.length > 1024) {
        add(
          'plugin_description_too_long',
          'description must be 1,024 characters or fewer.',
          'description',
        );
      }
      _text(
        description,
        'plugin_description',
        'description',
        singleLine: false,
      );
    }
  }

  void _author() {
    final author = manifest['author'];
    if (author == null) {
      add('plugin_developer_missing', 'author.name is required.', 'author');
      return;
    }
    if (author is! Map<String, Object?>) {
      add('plugin_author_wrong_type', 'author must be an object.', 'author');
      return;
    }
    final name = author['name'];
    if (name == null) {
      add(
        'plugin_developer_missing',
        'author.name is required.',
        'author.name',
      );
    } else if (name is! String) {
      add(
        'plugin_author_name_wrong_type',
        'author.name must be a string.',
        'author.name',
      );
    } else if (name.trim().isEmpty) {
      add(
        'plugin_author_name_empty',
        'author.name must be non-empty.',
        'author.name',
      );
    } else {
      if (name.length > 120) {
        add(
          'plugin_author_name_too_long',
          'author.name must be 120 characters or fewer.',
          'author.name',
        );
      }
      _text(name, 'plugin_author_name', 'author.name');
    }
    final email = author['email'];
    if (email != null) {
      if (email is! String) {
        add(
          'plugin_author_email_wrong_type',
          'author.email must be a string.',
          'author.email',
        );
      } else if (email.trim().isEmpty) {
        add(
          'plugin_author_email_empty',
          'author.email must be non-empty when provided.',
          'author.email',
        );
      } else if (email.length > 320) {
        add(
          'plugin_author_email_too_long',
          'author.email must be 320 characters or fewer.',
          'author.email',
        );
      }
    }
    _url(
      author,
      'url',
      'plugin_author_url',
      maxLength: 2048,
      fieldPrefix: 'author.',
    );
  }

  void _skillsPath() {
    final skills = manifest['skills'];
    if (skills == null) return;
    if (skills is! String) {
      add(
        'plugin_skills_path_wrong_type',
        'skills must be a string path for the root skills/ directory.',
        'skills',
      );
    } else if (skills.trim().isEmpty) {
      add(
        'plugin_skills_path_empty',
        'skills must be a non-empty path.',
        'skills',
      );
    } else if (skills != './skills/' && skills != './skills') {
      add(
        'plugin_skills_path_unsupported',
        'skills must resolve to the root skills/ directory.',
        'skills',
      );
    } else if (!package.directories.contains('skills')) {
      add(
        'plugin_skills_directory_missing',
        'The declared skills/ directory must exist.',
        'skills',
      );
    }
  }

  void _excludedFields() {
    if (manifest.containsKey('mcpServers')) {
      add(
        'mcp_configuration_excluded',
        'The release zip must not declare MCP servers; local MCP is only accepted from allowlisted partners.',
        'mcpServers',
      );
    }
    if (manifest.containsKey('apps')) {
      add(
        'app_configuration_excluded',
        'ZIP uploads must not include apps.',
        'apps',
      );
    }
    if (manifest.containsKey('hooks')) {
      add(
        'release_hooks_excluded',
        'Packages with lifecycle hooks cannot be submitted to the public directory.',
        'hooks',
      );
    }
    final openai = _openAiExtension();
    if (openai != null) {
      if (openai.containsKey('hooks')) {
        add(
          'release_hooks_excluded',
          'Packages with lifecycle hooks cannot be submitted to the public directory.',
          'extensions.com.openai.hooks',
        );
      }
      if (openai.containsKey('apps')) {
        add(
          'app_configuration_excluded',
          'ZIP uploads must not include apps.',
          'extensions.com.openai.apps',
        );
      }
      final review = openai['review'];
      if (review is Map) {
        for (final key in const ['test_credentials', 'reviewer_instructions']) {
          if (review.containsKey(key)) {
            add(
              'release_review_field_rejected',
              'ZIP metadata rejects $key; enter it in the portal instead.',
              'extensions.com.openai.review.$key',
            );
          }
        }
      }
    }

    final keywords = manifest['keywords'];
    if (keywords is List &&
        keywords.any((k) => k is String && k.toLowerCase() == 'mcp')) {
      add(
        'release_mcp_reference',
        'keywords must not include "mcp" in the skills-only release.',
        'keywords',
      );
    }
    final description = manifest['description'];
    if (description is String && _mcpWord.hasMatch(description)) {
      add(
        'release_mcp_reference',
        'description must not mention MCP in the skills-only release.',
        'description',
      );
    }
  }

  void _listing(Map<String, Object?> interface) {
    String? required(
      String field,
      String codePrefix,
      int maxLength, {
      bool singleLine = true,
    }) {
      final path = 'interface.$field';
      final value = interface[field];
      if (value == null) {
        add('${codePrefix}_empty', '$path is required.', path);
        return null;
      }
      if (value is! String) {
        add('${codePrefix}_wrong_type', '$path must be a string.', path);
        return null;
      }
      if (value.trim().isEmpty) {
        add('${codePrefix}_empty', '$path must be non-empty.', path);
        return null;
      }
      if (value.length > maxLength) {
        add(
          '${codePrefix}_too_long',
          '$path must be $maxLength characters or fewer (it is ${value.length}).',
          path,
        );
      }
      _text(value, codePrefix, path, singleLine: singleLine);
      return value;
    }

    required('displayName', 'plugin_display_name', 30);
    required('shortDescription', 'plugin_short_description', 30);
    final longDescription = required(
      'longDescription',
      'plugin_long_description',
      4000,
      singleLine: false,
    );
    required('developerName', 'plugin_developer_name', 80);

    if (longDescription != null && _mcpWord.hasMatch(longDescription)) {
      add(
        'release_mcp_reference',
        'interface.longDescription must not mention MCP in the skills-only release.',
        'interface.longDescription',
      );
    }

    final category = interface['category'];
    if (category != null) {
      if (category is! String) {
        add(
          'plugin_category_wrong_type',
          'interface.category must be a string.',
          'interface.category',
        );
      } else if (category.trim().isEmpty) {
        add(
          'plugin_category_empty',
          'interface.category must be non-empty when provided.',
          'interface.category',
        );
      } else if (!allowedCategories.contains(category)) {
        add(
          'plugin_category_unknown',
          'interface.category must be one of: ${allowedCategories.join(', ')}.',
          'interface.category',
        );
      }
    }

    final capabilities = interface['capabilities'];
    if (capabilities == null || capabilities is! List) {
      add(
        'plugin_capabilities_wrong_type',
        'interface.capabilities must be a list of strings (use [] if there are none).',
        'interface.capabilities',
      );
    } else {
      if (capabilities.length > 20) {
        add(
          'plugin_capabilities_too_many',
          'interface.capabilities must contain 20 entries or fewer.',
          'interface.capabilities',
        );
      }
      for (final capability in capabilities) {
        if (capability is! String) {
          add(
            'plugin_capability_wrong_type',
            'Each capability must be a string.',
            'interface.capabilities',
          );
        } else if (capability.trim().isEmpty) {
          add(
            'plugin_capability_empty',
            'Each capability must be non-empty.',
            'interface.capabilities',
          );
        } else {
          if (capability.length > 120) {
            add(
              'plugin_capability_too_long',
              'Each capability must be 120 characters or fewer.',
              'interface.capabilities',
            );
          }
          _text(capability, 'plugin_capability', 'interface.capabilities');
          if (_mcpWord.hasMatch(capability)) {
            add(
              'release_mcp_reference',
              'capabilities must not include "$capability" in the skills-only release.',
              'interface.capabilities',
            );
          }
        }
      }
    }

    _url(
      interface,
      'websiteURL',
      'plugin_website_url',
      fieldPrefix: 'interface.',
    );
    _url(
      interface,
      'supportURL',
      'plugin_support_url',
      fieldPrefix: 'interface.',
    );
    _url(
      interface,
      'privacyPolicyURL',
      'plugin_privacy_policy_url',
      fieldPrefix: 'interface.',
    );
    _url(
      interface,
      'termsOfServiceURL',
      'plugin_terms_of_service_url',
      fieldPrefix: 'interface.',
    );

    _defaultPrompts(interface['defaultPrompt']);
    _brandColor(interface, 'brandColor', 'plugin_brand_color', const [
      0xFF,
      0xFF,
      0xFF,
    ], 'white');
    _brandColor(interface, 'brandColorDark', 'plugin_brand_color_dark', const [
      0x21,
      0x21,
      0x21,
    ], '#212121');

    if (interface.containsKey('screenshots')) {
      add(
        'screenshot_configuration_excluded',
        'Skills-only ZIP uploads must not include interface.screenshots.',
        'interface.screenshots',
      );
    }
  }

  void _defaultPrompts(Object? value) {
    const path = 'interface.defaultPrompt';
    if (value == null) return;
    final List<Object?> prompts;
    if (value is String) {
      prompts = [value];
    } else if (value is List) {
      prompts = value;
    } else {
      add(
        'plugin_default_prompt_wrong_type',
        '$path must be a string or list of strings.',
        path,
      );
      return;
    }
    if (prompts.length > 3) {
      add(
        'plugin_default_prompt_too_many',
        '$path must contain at most three prompts.',
        path,
      );
    }
    final seen = <String>{};
    for (final prompt in prompts) {
      if (prompt is! String) {
        add(
          'plugin_default_prompt_entry_wrong_type',
          'Each $path entry must be a string.',
          path,
        );
        continue;
      }
      if (prompt.trim().isEmpty) {
        add(
          'plugin_default_prompt_empty',
          'Each $path entry must be non-empty.',
          path,
        );
        continue;
      }
      if (prompt.length > 128) {
        add(
          'plugin_default_prompt_too_long',
          'Each $path entry must be 128 characters or fewer.',
          path,
        );
      }
      _text(prompt, 'plugin_default_prompt', path);
      if (_mention.hasMatch(prompt)) {
        add(
          'plugin_default_prompt_mention',
          'Starter prompts must not contain @mentions.',
          path,
        );
      }
      if (!seen.add(
        prompt.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
      )) {
        add(
          'plugin_default_prompt_duplicate',
          'Starter prompts must be unique.',
          path,
        );
      }
    }
  }

  void _brandColor(
    Map<String, Object?> interface,
    String field,
    String codePrefix,
    List<int> background,
    String backgroundName,
  ) {
    final path = 'interface.$field';
    final value = interface[field];
    if (value == null) return;
    if (value is! String) {
      add('${codePrefix}_wrong_type', '$path must be a string.', path);
    } else if (value.isEmpty) {
      add(
        '${codePrefix}_empty',
        '$path must be non-empty when provided.',
        path,
      );
    } else if (!_hexColor.hasMatch(value)) {
      add(
        '${codePrefix}_format',
        '$path must be a six-digit hex color, such as #1ABCFE.',
        path,
      );
    } else {
      final rgb = [
        for (var i = 1; i < 7; i += 2)
          int.parse(value.substring(i, i + 2), radix: 16),
      ];
      if (contrastRatio(rgb, background) < 2) {
        add(
          '${codePrefix}_contrast',
          '$path must have at least 2:1 contrast against $backgroundName.',
          path,
        );
      }
    }
  }

  void _assets(Map<String, Object?> interface) {
    for (final field in const ['composerIcon', 'logo']) {
      if (interface[field] == null) {
        add(
          field == 'logo'
              ? 'plugin_logo_path_missing'
              : 'plugin_composer_icon_path_missing',
          'interface.$field is required and must reference a square image.',
          'interface.$field',
        );
      }
    }
    for (final field in const [
      'composerIcon',
      'composerIconDark',
      'logo',
      'logoDark',
    ]) {
      final value = interface[field];
      if (value == null) continue;
      final path = _assetPath(value, 'interface.$field');
      if (path != null) _image(path, 'interface.$field');
    }
  }

  /// Checks an asset path field and returns the archive path it points to.
  String? _assetPath(Object value, String field) {
    if (value is! String) {
      add(
        'declared_asset_path_wrong_type',
        '$field must be a file path string.',
        field,
      );
      return null;
    }
    if (value.isEmpty) {
      add('declared_asset_path_empty', '$field must not be empty.', field);
      return null;
    }
    if (value.trim() != value) {
      add(
        'declared_asset_path_has_outer_whitespace',
        '$field must not begin or end with whitespace.',
        field,
      );
      return null;
    }
    if (RegExp('[\u0000-\u001F\u007F]').hasMatch(value)) {
      add(
        'declared_asset_path_has_control_character',
        '$field must not contain control characters.',
        field,
      );
      return null;
    }
    if (!value.startsWith('./')) {
      add(
        'branding_asset_path_missing_root_prefix',
        '$field must start with "./".',
        field,
      );
      return null;
    }
    final relative = value.substring(2);
    final segments = relative.split('/');
    if (relative.startsWith('/') ||
        segments.contains('..') ||
        RegExp(r'^[A-Za-z]:').hasMatch(relative)) {
      add(
        'declared_asset_path_unsafe',
        '$field must be a relative path inside the plugin.',
        field,
      );
      return null;
    }
    if (package.directories.contains(relative)) {
      add(
        'declared_asset_not_regular_file',
        '$field must reference a file, not a directory.',
        field,
      );
      return null;
    }
    if (!package.files.containsKey(relative)) {
      add(
        'declared_asset_file_missing',
        '$field references $value, which is not in the zip.',
        field,
      );
      return null;
    }
    return relative;
  }

  void _image(String path, String field) {
    final bytes = package.files[path]!;
    if (bytes.length > _maxImageBytes) {
      add('image_file_too_large', 'Image must not exceed 5 MiB.', field);
    }
    final extension = path.contains('.')
        ? path.split('.').last.toLowerCase()
        : '';
    if (extension == 'svg') {
      _svg(bytes, field);
      return;
    }
    final expected = switch (extension) {
      'png' => RasterFormat.png,
      'jpg' || 'jpeg' => RasterFormat.jpeg,
      'webp' => RasterFormat.webp,
      _ => null,
    };
    if (expected == null) {
      add(
        'image_file_format_unsupported',
        'Image filename must end in .png, .jpg, .jpeg, .webp, or .svg.',
        field,
      );
      return;
    }
    final actual = detectRasterFormat(bytes);
    if (actual != null && actual != expected) {
      add(
        'raster_image_extension_content_mismatch',
        'Image extension .$extension does not match its ${actual.name.toUpperCase()} content.',
        field,
      );
    }
    final size = readRasterSize(bytes);
    if (size == null) {
      add(
        'raster_image_decode_failed',
        'Raster image must be a PNG, JPEG, or WebP file that can be decoded.',
        field,
      );
      return;
    }
    _dimensions(size.width, size.height, field, prefix: 'raster_image');
    if (size.width > _maxRasterPixels || size.height > _maxRasterPixels) {
      add(
        'raster_image_dimensions_too_large',
        'Image is $size; the limit is 4,096×4,096.',
        field,
      );
    }
  }

  void _svg(Uint8List bytes, String field) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(utf8.decode(bytes));
    } catch (_) {
      add('svg_xml_malformed', 'SVG must contain valid UTF-8 XML.', field);
      return;
    }
    final root = document.rootElement;
    if (root.name.local != 'svg') {
      add('svg_root_element_invalid', 'SVG root element must be <svg>.', field);
      return;
    }

    num? parse(String? value) =>
        value == null ? null : num.tryParse(value.trim());
    final viewBox = root.getAttribute('viewBox');
    final width = root.getAttribute('width');
    final height = root.getAttribute('height');

    num? w;
    num? h;
    if (viewBox != null) {
      final parts = viewBox
          .trim()
          .split(RegExp(r'[\s,]+'))
          .map(num.tryParse)
          .toList();
      if (parts.length != 4 || parts.contains(null)) {
        add(
          'svg_dimensions_not_numeric',
          'SVG viewBox must contain four numbers.',
          field,
        );
        return;
      }
      w = parts[2];
      h = parts[3];
    } else if (width != null && height != null) {
      w = parse(width);
      h = parse(height);
      if (w == null || h == null) {
        add(
          'svg_dimensions_not_numeric',
          'SVG width and height must be numeric, without units or percentages.',
          field,
        );
        return;
      }
    } else {
      add(
        'svg_dimensions_missing',
        'SVG must define a numeric viewBox or numeric width and height.',
        field,
      );
      return;
    }
    if (w! <= 0 || h! <= 0 || !w.isFinite || !h.isFinite) {
      add(
        'svg_dimensions_not_positive',
        'SVG width and height must be positive finite numbers.',
        field,
      );
      return;
    }
    _dimensions(w, h, field, prefix: 'svg');
  }

  void _dimensions(
    num width,
    num height,
    String field, {
    required String prefix,
  }) {
    if (width != height) {
      add(
        prefix == 'svg'
            ? 'svg_dimensions_not_square'
            : 'raster_image_not_square',
        'Image must be square (it is $width×$height).',
        field,
      );
    }
    if (width < _minImagePixels || height < _minImagePixels) {
      add(
        '${prefix}_dimensions_too_small',
        'Image dimensions must be at least 48×48 (it is $width×$height).',
        field,
      );
    }
  }

  void _releaseNotes() {
    final publication = _openAiExtension()?['publication'];
    final notes = publication is Map ? publication['release_notes'] : null;
    if (notes is! String || notes.trim().isEmpty) {
      add(
        'release_notes_missing',
        'extensions.com.openai.publication.release_notes must be set; otherwise the portal keeps the previous release notes.',
        'extensions.com.openai.publication.release_notes',
      );
    }
  }

  Map<String, Object?>? _openAiExtension() {
    final extensions = manifest['extensions'];
    if (extensions is! Map) return null;
    final openai = extensions['com.openai'];
    return openai is Map<String, Object?> ? openai : null;
  }

  String? _requiredString(String field, String codePrefix) {
    final value = manifest[field];
    if (value == null) {
      add('${codePrefix}_missing', '$field is required.', field);
      return null;
    }
    if (value is! String) {
      add('${codePrefix}_wrong_type', '$field must be a string.', field);
      return null;
    }
    if (value.trim().isEmpty) {
      add('${codePrefix}_empty', '$field must be non-empty.', field);
      return null;
    }
    return value;
  }

  void _url(
    Map<String, Object?> object,
    String key,
    String codePrefix, {
    int maxLength = 1024,
    String fieldPrefix = '',
  }) {
    final field = '$fieldPrefix$key';
    final value = object[key];
    if (value == null) return;
    if (value is! String) {
      add('${codePrefix}_wrong_type', '$field must be a string.', field);
      return;
    }
    if (value.trim().isEmpty) {
      add(
        '${codePrefix}_empty',
        '$field must be non-empty when provided.',
        field,
      );
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      add(
        '${codePrefix}_${codePrefix == 'plugin_author_url' ? 'not_https' : 'format'}',
        '$field must be an HTTPS URL.',
        field,
      );
    } else if (uri.userInfo.isNotEmpty) {
      add(
        '${codePrefix}_has_credentials',
        '$field must not contain credentials.',
        field,
      );
    }
    if (value.length > maxLength) {
      add(
        '${codePrefix}_too_long',
        '$field must be $maxLength characters or fewer.',
        field,
      );
    }
  }

  void _text(
    String value,
    String codePrefix,
    String field, {
    bool singleLine = true,
  }) {
    if (_unsupportedChars.hasMatch(value) ||
        (singleLine && _lineBreak.hasMatch(value))) {
      add(
        '${codePrefix}_character_unsupported',
        '$field must use supported text${singleLine ? ' and fit on one line' : ''}.',
        field,
      );
    }
  }
}

void _validateSkills(_Package package, List<Finding> findings) {
  if (!package.directories.contains('skills')) {
    findings.add(
      const Finding(
        'plugin_runtime_surface_missing',
        'A skills-only ZIP must contain at least one valid skill.',
      ),
    );
    return;
  }

  // SKILL.md files deeper than skills/<name>/SKILL.md.
  for (final path in package.files.keys) {
    final segments = path.split('/');
    if (segments.first == 'skills' &&
        segments.last == 'SKILL.md' &&
        segments.length > 3) {
      findings.add(
        Finding(
          'skill_manifest_nested',
          'Each skill directory must be an immediate child of skills/.',
          path: path,
        ),
      );
    }
  }

  final names = <String, String>{};
  var validSkills = 0;
  final pluginName = _pluginNameFrom(package);

  for (final child in package.childrenOf('skills').toList()..sort()) {
    final dir = 'skills/$child';
    if (package.files.containsKey(dir)) {
      findings.add(
        Finding(
          'skill_file_ignored',
          'Files directly under skills/ are not imported as skills.',
          path: dir,
        ),
      );
      continue;
    }
    if (child.startsWith('.')) {
      findings.add(
        Finding(
          'skill_directory_hidden',
          'Skill directory names must not begin with ".".',
          path: dir,
        ),
      );
      continue;
    }
    final skillMd = package.files['$dir/SKILL.md'];
    if (skillMd == null) {
      findings.add(
        Finding(
          'skill_manifest_missing',
          'Skill must contain a SKILL.md file.',
          path: dir,
        ),
      );
      continue;
    }
    final name = _validateSkillMd(skillMd, '$dir/SKILL.md', findings);
    if (name != null) {
      validSkills++;
      final existing = names[name];
      if (existing != null) {
        findings.add(
          Finding(
            'skill_identity_duplicate',
            'Skill name "$name" is also used by $existing.',
            path: dir,
          ),
        );
      }
      names[name] = dir;
      if (pluginName != null && '$pluginName:$name'.length > 64) {
        findings.add(
          Finding(
            'skill_identity_too_long',
            '"$pluginName:$name" must be 64 characters or fewer.',
            path: dir,
          ),
        );
      }
    }
    final agent = package.files['$dir/agents/openai.yaml'];
    if (agent != null) {
      _validateAgentYaml(agent, '$dir/agents/openai.yaml', findings);
    }
  }

  if (validSkills == 0) {
    findings.add(
      const Finding(
        'plugin_runtime_surface_missing',
        'A skills-only ZIP must contain at least one valid skill.',
      ),
    );
  }
}

String? _pluginNameFrom(_Package package) {
  try {
    final json = jsonDecode(utf8.decode(package.files[manifestPath]!));
    return json is Map && json['name'] is String
        ? json['name'] as String
        : null;
  } catch (_) {
    return null;
  }
}

/// Validates a SKILL.md file and returns its name if the frontmatter is valid.
String? _validateSkillMd(Uint8List bytes, String path, List<Finding> findings) {
  void add(String code, String message) =>
      findings.add(Finding(code, message, path: path));

  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    add('skill_manifest_invalid_utf8', 'SKILL.md must contain valid UTF-8.');
    return null;
  }
  final lines = const LineSplitter().convert(text.replaceFirst('\uFEFF', ''));
  if (lines.isEmpty || lines.first.trim() != '---') {
    add(
      'skill_frontmatter_missing',
      'SKILL.md must start with YAML front matter between "---" lines.',
    );
    return null;
  }
  final end = lines.indexWhere((line) => line.trim() == '---', 1);
  if (end == -1) {
    add(
      'skill_frontmatter_unclosed',
      'SKILL.md YAML front matter must end with "---".',
    );
    return null;
  }
  final Object? frontmatter;
  try {
    frontmatter = loadYaml(lines.sublist(1, end).join('\n'));
  } on YamlException catch (e) {
    add(
      'skill_frontmatter_yaml_malformed',
      'SKILL.md front matter must contain valid YAML: ${e.message}',
    );
    return null;
  }
  if (frontmatter is! YamlMap) {
    add(
      'skill_frontmatter_wrong_type',
      'SKILL.md front matter must contain a YAML mapping.',
    );
    return null;
  }

  final map = frontmatter;
  String? field(String key, int? maxLength) {
    final value = map[key];
    if (value == null) {
      add('skill_${key}_missing', '$key is required and must not be empty.');
      return null;
    }
    if (value is! String) {
      add('skill_${key}_wrong_type', '$key must be a string.');
      return null;
    }
    if (value.trim().isEmpty) {
      add('skill_${key}_empty', '$key must be non-empty.');
      return null;
    }
    if (maxLength != null && value.trim().length > maxLength) {
      add(
        'skill_${key}_too_long',
        '$key must be $maxLength characters or fewer.',
      );
    }
    if (_unsupportedChars.hasMatch(value)) {
      add(
        'skill_${key}_character_unsupported',
        '$key must use supported text.',
      );
    }
    return value.trim();
  }

  final name = field('name', null);
  field('description', 1024);
  if (lines.sublist(end + 1).join('\n').trim().isEmpty) {
    add('skill_body_empty', 'Skill instructions must not be empty.');
  }
  return name;
}

void _validateAgentYaml(Uint8List bytes, String path, List<Finding> findings) {
  void add(String code, String message) =>
      findings.add(Finding(code, message, path: path));

  final Object? yaml;
  try {
    yaml = loadYaml(utf8.decode(bytes));
  } on YamlException {
    add(
      'skill_agent_yaml_malformed',
      'agents/openai.yaml must contain valid YAML.',
    );
    return;
  } on FormatException {
    add(
      'skill_agent_invalid_utf8',
      'agents/openai.yaml must contain valid UTF-8.',
    );
    return;
  }
  if (yaml is! YamlMap) {
    add(
      'skill_agent_top_level_wrong_type',
      'agents/openai.yaml must contain a YAML mapping.',
    );
    return;
  }
  final interface = yaml['interface'];
  if (interface == null) {
    add(
      'skill_agent_interface_missing',
      'interface is required in agents/openai.yaml.',
    );
  } else if (interface is! YamlMap) {
    add(
      'skill_agent_interface_wrong_type',
      'interface must be a YAML mapping.',
    );
  } else {
    for (final key in const ['display_name', 'short_description']) {
      final value = interface[key];
      if (value == null) {
        add('skill_agent_${key}_missing', 'interface.$key is required.');
      } else if (value is! String) {
        add(
          'skill_agent_${key}_wrong_type',
          'interface.$key must be a string.',
        );
      } else if (value.trim().isEmpty) {
        add('skill_agent_${key}_empty', 'interface.$key must not be empty.');
      }
    }
    for (final key in const ['icon_small', 'icon_large', 'default_prompt']) {
      final value = interface[key];
      if (value == null) continue;
      if (value is! String) {
        add(
          'skill_agent_${key}_wrong_type',
          'interface.$key must be a string.',
        );
      } else if (value.trim().isEmpty) {
        add(
          'skill_agent_${key}_empty',
          'interface.$key must be non-empty when provided.',
        );
      }
    }
    final color = interface['brand_color'];
    if (color != null) {
      if (color is! String) {
        add(
          'skill_agent_brand_color_wrong_type',
          'interface.brand_color must be a string.',
        );
      } else if (!_hexColor.hasMatch(color)) {
        add(
          'skill_agent_brand_color_format',
          'interface.brand_color must be a six-digit hex color.',
        );
      }
    }
  }
  final policy = yaml['policy'];
  if (policy != null) {
    if (policy is! YamlMap) {
      add('skill_agent_policy_wrong_type', 'policy must be a YAML mapping.');
    } else {
      final products = policy['products'];
      final implicit = policy['allow_implicit_invocation'];
      final validKeys = policy.keys.every(
        (k) => k == 'products' || k == 'allow_implicit_invocation',
      );
      final validProducts =
          products == null ||
          (products is YamlList &&
              products.every((p) => p == 'CHAT' || p == 'CODEX'));
      if (!validKeys ||
          !validProducts ||
          (implicit != null && implicit is! bool)) {
        add(
          'skill_agent_allow_implicit_invocation_wrong_type',
          'policy may contain only products (CHAT, CODEX) and allow_implicit_invocation (true or false).',
        );
      }
    }
  }
  final dependencies = yaml['dependencies'];
  if (dependencies != null) {
    if (dependencies is! YamlMap) {
      add(
        'skill_agent_dependencies_wrong_type',
        'dependencies must be a YAML mapping.',
      );
    } else if (dependencies.keys.any((k) => k != 'tools')) {
      add(
        'skill_agent_dependency_unsupported',
        'Only dependencies.tools is supported.',
      );
    }
  }
}

void _validateExcludedFiles(_Package package, List<Finding> findings) {
  if (package.files.containsKey('.mcp.json') ||
      package.files.containsKey('mcp.json')) {
    findings.add(
      const Finding(
        'mcp_configuration_excluded',
        'The release zip must not include MCP configuration.',
        path: '.mcp.json',
      ),
    );
  }
  if (package.files.containsKey('.app.json')) {
    findings.add(
      const Finding(
        'app_configuration_excluded',
        'ZIP uploads must not include .app.json.',
        path: '.app.json',
      ),
    );
  }
  if (package.directories.contains('hooks')) {
    findings.add(
      const Finding(
        'release_hooks_excluded',
        'Packages with lifecycle hooks cannot be submitted to the public directory.',
        path: 'hooks/',
      ),
    );
  }
}

/// The WCAG contrast ratio between two sRGB colors given as [r, g, b] bytes.
double contrastRatio(List<int> a, List<int> b) {
  double luminance(List<int> rgb) {
    double channel(int value) {
      final c = value / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(rgb[0]) +
        0.7152 * channel(rgb[1]) +
        0.0722 * channel(rgb[2]);
  }

  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
