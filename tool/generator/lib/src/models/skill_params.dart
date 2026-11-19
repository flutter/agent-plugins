// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parameters for generating a skill from resources.
class SkillParams {
  /// Creates a new [SkillParams] instance.
  SkillParams({
    required this.name,
    required this.description,
    required this.resources,
    this.instructions,
    this.examplePrompt,
  });

  /// Creates a [SkillParams] instance from a JSON map.
  factory SkillParams.fromJson(Map<String, dynamic> json) =>
      SkillParams.fromYamlMap(json);

  /// Creates a [SkillParams] instance from a decoded YAML or JSON map.
  ///
  /// Throws a [FormatException] if required fields are missing or have invalid
  /// types.
  factory SkillParams.fromYamlMap(Map<Object?, Object?> map) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Skill "name" must be a non-empty string.');
    }
    final description = map['description'];
    if (description is! String) {
      throw FormatException(
        'Skill "$name" field "description" must be a string.',
      );
    }
    final rawResources = map['resources'];
    if (rawResources is! List<Object?>) {
      throw FormatException('Skill "$name" field "resources" must be a list.');
    }
    final resources = <String>[];
    for (final resource in rawResources) {
      if (resource is! String) {
        throw FormatException(
          'Skill "$name" resource entries must be strings.',
        );
      }
      resources.add(resource);
    }
    final instructions = map['instructions'];
    if (instructions != null && instructions is! String) {
      throw FormatException(
        'Skill "$name" field "instructions" must be a string.',
      );
    }
    final examplePrompt = map['examplePrompt'];
    if (examplePrompt != null && examplePrompt is! String) {
      throw FormatException(
        'Skill "$name" field "examplePrompt" must be a string.',
      );
    }

    return SkillParams(
      name: name,
      description: description,
      resources: List<String>.unmodifiable(resources),
      instructions: instructions as String?,
      examplePrompt: examplePrompt as String?,
    );
  }

  /// The name of the skill.
  final String name;

  /// The description of the skill.
  final String description;

  /// The example prompt for the skill.
  final String? examplePrompt;

  /// Optional instructions for generating the skill.
  final String? instructions;

  /// The resources to fetch content from.
  final List<String> resources;
}
