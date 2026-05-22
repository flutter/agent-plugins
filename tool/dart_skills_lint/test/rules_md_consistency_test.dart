// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/fixable_rule.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/check_type.dart';
import 'package:dart_skills_lint/src/models/skill_rule.dart';
import 'package:dart_skills_lint/src/rule_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Pins [RULES.md](../RULES.md) to [RuleRegistry] so a rule cannot be
/// added, removed, renamed, or have its default severity / fixability
/// changed without the docs catching up in the same commit.
///
/// Per the answer to "What should T5 enforce?": this asserts all four
/// invariants — registry-without-docs, docs-without-registry, severity
/// mismatch, and fixable mismatch. Each failure prints which rule and
/// which field diverged so the fix is obvious.
void main() {
  group('RULES.md consistency', () {
    late Map<String, _DocRule> docRules;
    late Map<String, CheckType> registryByName;

    setUpAll(() {
      final String rulesPath = p.normalize(p.absolute('RULES.md'));
      final String content = File(rulesPath).readAsStringSync();
      docRules = _parseRulesDoc(content);
      registryByName = {for (final c in RuleRegistry.allChecks) c.name: c};
    });

    test('every registered rule has a RULES.md entry', () {
      final Set<String> missing = registryByName.keys.toSet()..removeAll(docRules.keys);
      expect(
        missing,
        isEmpty,
        reason:
            'RuleRegistry contains rules with no RULES.md entry: $missing. '
            'Add a `## <rule-name>` section to RULES.md.',
      );
    });

    test('every RULES.md entry maps to a registered rule', () {
      final Set<String> orphans = docRules.keys.toSet()..removeAll(registryByName.keys);
      expect(
        orphans,
        isEmpty,
        reason:
            'RULES.md documents rules that are not in RuleRegistry: $orphans. '
            'Either re-register them or remove the section.',
      );
    });

    test('RULES.md "Default severity:" matches CheckType.defaultSeverity', () {
      final List<String> mismatches = [];
      for (final MapEntry<String, _DocRule> entry in docRules.entries) {
        final String name = entry.key;
        final CheckType? check = registryByName[name];
        if (check == null) {
          continue;
        }
        if (entry.value.defaultSeverity != check.defaultSeverity) {
          mismatches.add(
            '$name: RULES.md says ${entry.value.defaultSeverity.name}, '
            'registry says ${check.defaultSeverity.name}',
          );
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason:
            'Default severity drifted between RULES.md and RuleRegistry:\n'
            '  ${mismatches.join('\n  ')}',
      );
    });

    test('RULES.md "Fixable:" matches whether the rule implements FixableRule', () {
      final List<String> mismatches = [];
      for (final MapEntry<String, _DocRule> entry in docRules.entries) {
        final String name = entry.key;
        final CheckType? check = registryByName[name];
        if (check == null) {
          continue;
        }
        final SkillRule? rule = RuleRegistry.createRule(name, check.defaultSeverity);
        if (rule == null) {
          mismatches.add('$name: RuleRegistry.createRule returned null');
          continue;
        }
        final actuallyFixable = rule is FixableRule;
        if (entry.value.fixable != actuallyFixable) {
          mismatches.add(
            '$name: RULES.md says fixable=${entry.value.fixable}, '
            'class is FixableRule=$actuallyFixable',
          );
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason:
            'Fixable claim drifted between RULES.md and the rule class:\n'
            '  ${mismatches.join('\n  ')}',
      );
    });
  });
}

class _DocRule {
  _DocRule({required this.defaultSeverity, required this.fixable});

  final AnalysisSeverity defaultSeverity;
  final bool fixable;
}

/// Parses every `## <rule-name>` section in RULES.md and extracts the
/// `Default severity:` and `Fixable:` lines. The format the test
/// enforces:
///
///   ## <rule-name>
///
///   - **Default severity:** <error|warning|disabled>
///   - **Fixable:** <yes|no>
///   ...
///
/// Sections whose heading does not look like a kebab-case rule name
/// (e.g. the introductory "Rules" `#` heading) are ignored.
Map<String, _DocRule> _parseRulesDoc(String content) {
  // Append a sentinel `## ` heading so the last real section terminates
  // cleanly. Dart's RegExp doesn't support `\Z`, and a multiline `$`
  // matches every newline, so we avoid both by feeding the parser a
  // synthetic trailing heading.
  final padded = '$content\n## __end__\n';
  final section = RegExp(
    r'^## ([a-z][a-z0-9-_]*)\s*\n(.*?)(?=^## )',
    multiLine: true,
    dotAll: true,
  );
  final Map<String, _DocRule> out = {};
  for (final Match m in section.allMatches(padded)) {
    final String name = m.group(1)!;
    if (name == '__end__') {
      continue;
    }
    final String body = m.group(2)!;
    final AnalysisSeverity? severity = _parseSeverity(body);
    final bool? fixable = _parseFixable(body);
    if (severity == null || fixable == null) {
      throw StateError(
        'RULES.md section "$name" is missing a "**Default severity:**" or '
        '"**Fixable:**" line. Found:\n$body',
      );
    }
    out[name] = _DocRule(defaultSeverity: severity, fixable: fixable);
  }
  return out;
}

AnalysisSeverity? _parseSeverity(String body) {
  final r = RegExp(r'\*\*Default severity:\*\*\s+(\w+)');
  final RegExpMatch? m = r.firstMatch(body);
  if (m == null) {
    return null;
  }
  final String raw = m.group(1)!.toLowerCase();
  for (final AnalysisSeverity s in AnalysisSeverity.values) {
    if (s.name == raw) {
      return s;
    }
  }
  return null;
}

bool? _parseFixable(String body) {
  final r = RegExp(r'\*\*Fixable:\*\*\s+(\w+)');
  final RegExpMatch? m = r.firstMatch(body);
  if (m == null) {
    return null;
  }
  switch (m.group(1)!.toLowerCase()) {
    case 'yes':
      return true;
    case 'no':
      return false;
    default:
      return null;
  }
}
