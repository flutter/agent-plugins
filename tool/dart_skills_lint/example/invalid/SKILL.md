---
name: NotInvalid
description: A deliberately broken fixture used by example/README.md to show what each rule's error output looks like.
secret_field: not allowed by the spec
---

# Invalid example skill

This skill deliberately trips three rules so the CLI's diagnostic output
can be inspected end-to-end. One fires under defaults; two need to be
enabled to surface as errors (the spec ships them at lower severities).

1. `invalid-skill-name` *(error by default)* — the frontmatter `name:`
   is `NotInvalid`, which is not lowercase **and** does not match the
   parent directory `invalid`.
2. `disallowed-field` *(disabled by default; enable via
   `--disallowed-field` or YAML config)* — `secret_field:` is not in
   the spec's allowed field list.
3. `check-absolute-paths` *(warning by default; escalate to error via
   `--check-absolute-paths` or YAML config)* — the link below uses an
   absolute filesystem path, which is not portable across machines.

The broken link: [absolute link](/tmp/this/does/not/exist.md)

Run it with default rules:

```bash
dart run dart_skills_lint --skill ./example/invalid
```

…and again with every rule turned up to error:

```bash
dart run dart_skills_lint --skill ./example/invalid \
  --disallowed-field --check-absolute-paths
```

Expected: non-zero exit, error messages naming each rule that is enabled.
