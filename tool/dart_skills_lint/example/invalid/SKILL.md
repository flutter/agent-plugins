---
name: NotInvalid
description: A deliberately broken fixture used by example/README.md to show what each rule's error output looks like.
secret_field: not allowed by the spec
---

# Invalid example skill

This skill deliberately fails three default rules at once:

1. `invalid-skill-name` — the frontmatter `name:` is `NotInvalid`, which
   is not lowercase **and** does not match the parent directory `invalid`.
2. `disallowed-field` — `secret_field:` is not in the spec's allowed
   field list.
3. `check-absolute-paths` — the link below uses an absolute filesystem
   path, which is not portable across machines.

The broken link: [absolute link](/tmp/this/does/not/exist.md)

Run it with:

```bash
dart run dart_skills_lint --skill ./example/invalid
```

Expected: non-zero exit, error messages naming each rule above.
