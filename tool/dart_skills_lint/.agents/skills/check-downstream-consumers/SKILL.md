---
name: check-downstream-consumers
description: >
  Validates an in-progress PR or feature branch of dart_skills_lint against known downstream ecosystem consumers.
  Use when assessing breaking changes across external repositories during PR evaluation, testing migrations against the changelog, or determining necessary backwards compatibility shims.
metadata:
  internal: true
---

# Check Downstream Consumers & Evaluate Breaking Changes

> [!IMPORTANT]
> **No Downstream Commits Allowed**
> This skill is focused entirely on evaluating breaking changes within `dart_skills_lint` during PR review and changelog validation. All modifications applied to downstream consumer repositories (such as temporarily editing `pubspec.yaml` `ref:` hashes or updating calling syntax to verify migrations) are strictly **diagnostic and transient**. You must **never stage, commit, or push** code inside external downstream repositories during this workflow.

## 1. Preparation & Repository Verification

1. **Verify Local Linter State (`dart_skills_lint`)**
   - Ensure your working directory in `dart_skills_lint` is clean (`git status`).
   - Verify all existing tests pass cleanly (`dart test`).
   - Push current commits to the remote branch so downstream consumers can resolve git hashes directly via the network.
   - Record the latest remote git SHA-1 commit hash (e.g., `1e1f280...`).

2. **Locate & Check Out Downstream Consumers**
   - Read [`resources/known_consumers.md`](resources/known_consumers.md) to review typical consumer repositories (`flutter/flutter`, `flutter/devtools`, `dart-lang/site-www`, etc.) and their specific consumption subdirectories.
   - **Discovering Local Checkouts**: If you do not already know the exact directory paths where these consumer repositories live on disk:
     1. **Check Workspace Knowledge**: Inspect active workspace definitions and machine-specific local Knowledge Items (`KIs`), which frequently record configured system directory structures.
     2. **Inspect Adjacent Parent Directories**: Check common sibling paths right around your current repository root (for example, listing adjacent directories under `..` or running localized, depth-limited searches like `find .. -maxdepth 3 -name pubspec.yaml`).
     3. **Ask Before Running Blind Traversals**: Never execute unbounded root filesystem sweeps (`find / -name ...`). If a target repository cannot be found within adjacent workspace boundaries, immediately ask the user whether the repository is checked out locally and prompt for its path before evaluating.
   - For every target checked out on disk, verify its git state is clean and resting on its primary upstream branch (`main` or `master`). Do not run tests against dirty or out-of-date branches.

---

## 2. Pointing Consumers to the In-Progress Hash

For each downstream consumer under evaluation:

1. **Update `pubspec.yaml`**
   - Locate the target's relevant dependency specification (e.g., `dev/tools/pubspec.yaml` or `tool/pubspec.yaml`).
   - Update the `ref:` field under the `git` configuration for `dart_skills_lint` to exact match the in-progress commit hash:
     ```yaml
     dart_skills_lint:
       git:
         url: https://github.com/flutter/agent-plugins
         path: tool/dart_skills_lint
         ref: <LATEST_COMMIT_HASH>
     ```

2. **Resolve Dependencies & Run Verification Tests**
   - Execute dependency resolution according to the consumer environment (Flutter workspaces require `flutter pub get`; standard pure Dart repositories require `dart pub get`).
   - Run the consumer's verification tests (typically targeting tests like `test/validate_skills_test.dart` or running `flutter test` / `dart test`).

---

## 3. Breaking Change Evaluation & Decision Protocol

Whenever tests fail or dependency resolution encounters API friction, you must evaluate the nature of the breakage and pause for a deliberate human-in-the-loop decision before taking action.

### Analyzing the Failure
1. **Diagnose**: Identify exact causes (e.g., renamed public parameters, removed model types, altered getter return types, or modified severity profiles).
2. **Mitigation Options**: Determine if a backwards-compatible code layer can seamlessly bridge the change without compromising new features (e.g., `@Deprecated` getters mapping new types back to legacy structures, constructor parameter forwarding, or fallback exports).
3. **Changelog Integrity**: Verify whether the breaking behavior and its required migration steps are fully documented in `dart_skills_lint/CHANGELOG.md`.

### The Human Collaboration Point
Present your diagnostic summary to the human and request a deliberate path forward. The choice between mitigating a break inside the linter versus making a breaking change in downstream libraries is strictly a human decision based on ecosystem trade-offs.

#### Pathway A: Backwards Compatibility Mitigation (Approved by Human)
If the decision is to soften or eliminate the breaking change from `dart_skills_lint`:
1. Modify `dart_skills_lint` code to introduce the backward-compatible shim (such as deprecated getters/constructors or compatibility exports).
2. Add regression tests to ensure both legacy consumer calls and new patterns function properly without throwing exceptions, while verifying mutually exclusive flags fail gracefully if combined.
3. Ensure temporary shims are appropriately documented and tagged with tracking issues (`// TODO(...)`) for future removal.
4. Format code (`dart format .`), verify static analysis (`dart analyze --fatal-infos`), and confirm tests pass locally (`dart test`).
5. Commit and push the updated branch, capture the refreshed SHA-1 commit hash, update the downstream `pubspec.yaml`, and run tests again until the consumer cleanly compiles and passes.

#### Pathway B: Downstream Migration via Changelog (Break Accepted)
If the human instructs you not to mitigate (or if mitigation is structurally impossible) and accepts the breaking change:
1. **Attempt Downstream Upgrade**: Upgrade the downstream library's calling code **strictly following the migration instructions written in `dart_skills_lint/CHANGELOG.md`**.
2. **Evaluate Changelog Quality**: If the instructions written in the `CHANGELOG.md` are incomplete, confusing, or insufficient to cleanly migrate the downstream code, treat this as an explicit evaluation failure. Immediately propose targeted additions and clarity improvements to `dart_skills_lint/CHANGELOG.md`.
3. **Verify Build & Tests**: After updating both the consumer codebase and any changelog enhancements, re-run dependency checks (`pub get`) and test suites until the downstream package runs cleanly.

*Constraint — **Do Not Commit**: Remember that any migration edits made across the downstream codebase exist purely to verify that `dart_skills_lint/CHANGELOG.md` instructions function cleanly in practice. Do **not** stage or commit these edits inside the consumer repository.*

---

## 4. Iteration Loop & Repository Cleanup

After successfully evaluating and resolving one target repository:
1. **Clean Up Consumer State**: Because downstream edits are entirely transient, restore the external consumer repository cleanly back to its initial git state (`git checkout -- .` or `git restore .` across the modified paths) before proceeding to the next candidate, unless expressly instructed by the user to leave uncommitted changes on disk for local inspection.
2. **Record Evaluation Summary**: Update and maintain clear summaries documenting which repositories passed cleanly without changes, which required local mitigations inside `dart_skills_lint`, and which proved out changelog migration workflows.
3. **Check Reviewer Intent**: Ask the human reviewer whether to proceed directly to evaluating the next remaining repository listed in [`resources/known_consumers.md`](resources/known_consumers.md) or halt execution.
