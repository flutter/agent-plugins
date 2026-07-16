# Reviewing Tests

This reference document outlines guidelines for reviewing and evaluating unit, integration, and other tests during code reviews to ensure coverage, reliability, and correctness.

To make test reviews effective:

- Keep pull requests small and focused. Avoid reviewing tests in large, multi-feature PRs.
- For complex or high-risk features, consider interactive review walkthroughs with developers and testers to align unit, integration, and acceptance tests.

## Architectural boundaries and test doubles

Unit, integration, and end-to-end tests should have distinct purposes:

- **Avoid redundant overlap**: Do not assert the same business outcomes across all levels.
- **Share utilities**: Reuse test data generation factories and helper objects across test suites.
- **Isolate unit tests**: Use test doubles to replace external dependencies (such as databases and APIs) to keep tests fast and deterministic.

Minimize the use of mocks. AI tools and developers often over-rely on mocks, which leads to fragile tests that pass even when integration points are broken. Use the most appropriate testing double:

| Double type        | Purpose                                                         | Verification style      | Review standard                                                           |
| :----------------- | :-------------------------------------------------------------- | :---------------------- | :------------------------------------------------------------------------ |
| **Fake**  | Lightweight, working implementation (e.g., in-memory database). | State verification      | Preferred. Minimizes external dependencies without mock setup.            |
| **Stub**  | Returns hardcoded responses to specific calls.                  | State verification      | Good for controlling specific test inputs.                                |
| **Mock**  | Verifies specific method interactions and call counts.          | Behavioral verification | Limit to 3-4 per test. Only mock I/O boundaries.                          |
| **Spy**   | Wraps a real object to record calls while executing real logic. | Hybrid verification     | Avoid unless verifying interactions with immutable third-party libraries. |
| **Dummy** | Empty object passed to satisfy type signatures.                 | None                    | Preferred for clean setup when the dependency is unused.                  |

## Test smells

Flag test smells (poor testing practices) during code reviews. Unaddressed smells cause test suites to become flaky, slow, and hard to maintain.

| Smell classification   | Specific anti-pattern | Diagnostic indicator                                                            | Impact                                                  |
| :--------------------- | :-------------------- | :------------------------------------------------------------------------------ | :------------------------------------------------------ |
| **Structural**     | Mystery Guest         | Relies on external files, databases, or configuration not declared in the test. | Environment-dependent failures, cannot run in parallel. |
| **Structural**     | Eager Test            | Verifies multiple distinct functional concepts in a single test block.          | Hard to diagnose failures.                              |
| **Behavioral**     | Assertion Roulette    | Multiple assertions in a test block without custom failure messages.            | First failure halts execution, hiding other failures.   |
| **Behavioral**     | For Testers Only      | Modifying production code API solely to make it testable.                       | Compromised production API design.                      |
| **Maintenance**    | Sleepy Test           | Using hardcoded delays or sleep statements.                                     | Slow execution, race conditions.                        |
| **Maintenance**    | Sensitive Equality    | Assertions that fail on minor, irrelevant formatting changes.                   | Fragile tests that break on minor edits.                |
| **Maintenance**    | Dead Test             | Tests with missing or trivial assertions.                                       | False confidence in test coverage.                      |
| **Organizational** | Test Maverick         | Fails to follow project testing conventions.                                    | Readability and onboarding issues.                      |
| **Organizational** | General Fixture       | Setup code loads unrelated data models and tables.                              | Slow execution, database flakiness.                     |

## SDK contracts, web UI, and dynamic waits

Apply specific standards when reviewing tests for libraries, SDKs, or web interfaces:

- **SDK tests**: Verify public attributes, return types, method chaining, and default values. When introducing breaking changes, write tests that assert deprecation warnings are emitted and verify legacy behavior.
- **UI selectors**: Use accessibility-aware selectors (like roles or labels) rather than absolute page layouts or CSS class structures.
- **Waits**: Use asynchronous, dynamic conditional waiting (polling until state is met) instead of hardcoded sleep intervals.

## Generative AI and deterministic verification

AI-generated tests can create a coverage illusion by asserting current code behavior—including existing bugs—rather than the actual business requirements.

Use a structured workflow for AI-assisted tests:

1. **Behavioral specification**: Draft empty test blocks defining expectations before generating code.
2. **AI generation**: Use AI to write boilerplate setup, mocks, and execution logic.
3. **Human review**: Evaluate the assertions against business requirements. Ask if the tests would pass if a bug were introduced.
4. **Mutation testing**: Run mutation tools (such as StrykerJS, mutmut, or pitest) to verify that tests catch changes to production code.

To avoid manual mocking and flaky behavior, consider deterministic verification tools (like BitDive or Skyramp) that capture and replay database and network calls. Keep a centralized, repository-managed registry of regression test cases to train and update automated verification agents.

## Review matrix

Use the following checklist and questions to evaluate test files:

| Target                                | Self-reflection question                                          | Intended check                                                       |
| :------------------------------------ | :---------------------------------------------------------------- | :------------------------------------------------------------------- |
| **Functional correctness** | Does the test confirm acceptance criteria and cover edge cases?   | Identifies missing Happy Path or Failure Path scenarios.             |
| **Refactoring integrity**    | Would the test still pass if the internal implementation changed? | Identifies tests tightly coupled to specific implementation details. |
| **Failure predictability**   | If a bug were deliberately introduced, would this test fail?      | Identifies weak assertions or dead tests.                            |
| **Boundary security**            | Are inputs validated and permission boundaries asserted?          | Identifies missing security validation.                              |
| **Concurrency safety**           | Does the test execute safely in a parallel thread environment?    | Identifies race conditions and deadlocks.                            |
| **State isolation**          | Does the test clean up mutations to avoid leaking state?          | Identifies flaky tests that fail when run concurrently.              |

### Open-ended questions

Ask yourself these questions during code review:

- "What is the reasoning behind this specific test architecture or mock setup?"
- "Are there performance, database query count, or latency impacts associated with this setup?"
- "How does this testing strategy align with our team's conventions and standards?"
- "What changes would improve the readability and maintainability of this test structure?"
- "What testing strategy do you recommend for high-risk safety requirements?"
- "As a skeptical engineer, where will the tests pass when they shouldn't?"
