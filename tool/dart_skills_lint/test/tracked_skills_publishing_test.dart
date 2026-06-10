import 'dart:io';

import 'package:dart_skills_lint/src/config_parser.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('all tracked skills have prevent-skills-sh-publishing rule explicitly enabled', () async {
    // Explanation:
    // Any skill in .agents/skills/ that is checked into version control is considered an internal skill.
    // It must explicitly have the `prevent-skills-sh-publishing: error` rule enabled in dart_skills_lint.yaml
    // to prevent accidental publishing. Un-tracked / local dev skills (which are git-ignored) are exempt
    // so they can be published without friction.

    // 1. Get tracked files using git ls-files
    final ProcessResult processResult = await Process.run('git', ['ls-files', '.agents/skills']);
    expect(processResult.exitCode, 0, reason: 'git ls-files should succeed');

    final output = processResult.stdout as String;
    final Iterable<String> lines = output.split('\n').where((line) => line.trim().isNotEmpty);

    final trackedSkillDirs = <String>{};
    for (final line in lines) {
      final List<String> parts = p.split(line);
      // We look for files inside .agents/skills/<skill-name>/
      // parts[0] is .agents, parts[1] is skills
      if (parts.length >= 4 && parts[0] == '.agents' && parts[1] == 'skills') {
        trackedSkillDirs.add(parts[2]);
      }
    }

    // 2. Parse configuration
    final Configuration config = await ConfigParser.loadConfig();

    final Map<String, AnalysisSeverity> globalRules = config.configuredRules;
    final globalEnabled = globalRules['prevent-skills-sh-publishing'] == AnalysisSeverity.error;

    for (final skillDir in trackedSkillDirs) {
      var localEnabled = false;
      final expectedPath = '.agents/skills/$skillDir';

      for (final DirectoryConfig dirConfig in config.directoryConfigs) {
        if (dirConfig.path == expectedPath) {
          if (dirConfig.rules['prevent-skills-sh-publishing'] == AnalysisSeverity.error) {
            localEnabled = true;
          }
        }
      }

      expect(
        globalEnabled || localEnabled,
        isTrue,
        reason:
            'The tracked skill "$skillDir" must have "prevent-skills-sh-publishing: error" explicitly enabled in dart_skills_lint.yaml.',
      );
    }
  });
}
