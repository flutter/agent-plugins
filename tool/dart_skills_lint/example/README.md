# dart_skills_lint examples

Two reference fixtures live in this directory:

| Fixture | Expected outcome |
| --- | --- |
| [`valid/`](valid/SKILL.md) | All rules pass; the CLI exits 0. |
| [`invalid/`](invalid/SKILL.md) | Multiple rules fail; the CLI exits 1. |

Use them to take the linter for a spin without writing your own skill
first, and to see exactly what real diagnostic output looks like.

## Run the valid fixture

```bash
dart run dart_skills_lint --skill ./example/valid
```

You should see:

```
Evaluating directory: example/valid
--- Validating skill: valid ---
  Skill is valid.
```

Exit code: `0`.

## Run the invalid fixture

With default rule severities, only `invalid-skill-name` fires (the other
two violations are below their default threshold):

```bash
dart run dart_skills_lint --skill ./example/invalid
```

Exit code: `1`. To see every violation surface as an error, escalate the
other two rules with explicit flags:

```bash
dart run dart_skills_lint --skill ./example/invalid \
  --disallowed-field --check-absolute-paths
```

Three rules now report failures:

- `invalid-skill-name` — names the offending frontmatter value, calls
  out the directory mismatch, and suggests a corrected form.
- `disallowed-field` — names the unknown field (`secret_field`) and
  links to the spec's allowed-field list.
- `check-absolute-paths` — flags the `/tmp/...` link as non-portable
  and links to the spec section on relative paths.

The exact wording is asserted by
[`test/example_fixtures_test.dart`](../test/example_fixtures_test.dart),
so the fixtures and their expected diagnostics cannot drift apart.

## Trying out --fix

The invalid fixture's `check-absolute-paths` violation is auto-fixable
when the target file exists. To experiment, point it at a real local
file:

```bash
dart run dart_skills_lint --skill ./example/invalid --fix --dry-run
```

`--dry-run` shows the proposed diff without writing; drop it to apply
the change.
