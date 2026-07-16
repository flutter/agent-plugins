# Known Downstream Consumers of `dart_skills_lint`

When evaluating the impact of pull requests on downstream repositories, check against these known ecosystem consumers. 

> [!NOTE]
> Local directory paths across individual development machines vary. Avoid assuming fixed directory locations. Locate repositories dynamically (e.g., searching relative to workspace root parent directories or checking common checkout folders) or consult machine-specific local Knowledge Items if available.

## Repository Directory & Usage Profile

### 1. `flutter/flutter`
- **Repository URL**: [flutter/flutter](https://github.com/flutter/flutter)
- **Primary Consumer Location**: `dev/tools/`
- **Tooling Engine**: `flutter pub get` and `flutter test`
- **Focus Areas**: Validating agent skills embedded within repository automation and development workflows.

### 2. `flutter/devtools`
- **Repository URL**: [flutter/devtools](https://github.com/flutter/devtools)
- **Primary Consumer Location**: `tool/`
- **Tooling Engine**: `flutter pub get` and `flutter test` (or `dart test`)
- **Focus Areas**: Custom verification harnesses requiring absolute path isolation patterns (e.g., `validate_skills_test.dart`).

### 3. `flutter/packages`
- **Repository URL**: [flutter/packages](https://github.com/flutter/packages)
- **Primary Consumer Location**: Package-specific automation tools (for instance, `packages/camera/camera_android_camerax/pubspec.yaml` or shared verification test benches).
- **Tooling Engine**: `flutter pub get` and `flutter test`
- **Focus Areas**: Custom domain-specific validation rules extending `SkillRule` directly.

### 4. `dart-lang/site-www`
- **Repository URL**: [dart-lang/site-www](https://github.com/dart-lang/site-www)
- **Primary Consumer Location**: `site/`
- **Tooling Engine**: `dart pub get` and `dart test`
- **Focus Areas**: Web documentation generation workflows (`test/lint_skills_test.dart`).

### 5. `dart-lang/skills`
- **Repository URL**: [dart-lang/skills](https://github.com/dart-lang/skills)
- **Primary Consumer Location**: Root skill sets or tooling harnesses.
- **Tooling Engine**: `dart pub get` and `dart test`

### 6. `kevmoo/dart-best-practices`
- **Repository URL**: [kevmoo/dart-best-practices](https://github.com/kevmoo/dart-best-practices)
- **Primary Consumer Location**: Root tooling verification tests.
- **Tooling Engine**: `dart pub get` and `dart test`
