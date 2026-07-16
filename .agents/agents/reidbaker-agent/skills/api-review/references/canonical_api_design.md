# Foundations of canonical API design principles

This document contains the canonical principles for designing and improving APIs within the GenUI ecosystem. These principles are distilled from established software engineering best practices.

## Table of contents

- [Core architectural philosophy](#core-architectural-philosophy)
  - [1. Contract-first design (API first)](#1-contract-first-design-api-first)
  - [2. The KISS mandate (minimal surface area)](#2-the-kiss-mandate-minimal-surface-area)
  - [3. YAGNI (avoid speculative generality)](#3-yagni-avoid-speculative-generality)
  - [4. Separation of concerns (information hiding)](#4-separation-of-concerns-information-hiding)
  - [5. Explicit configuration (dependency injection over stateful globals)](#5-explicit-configuration-dependency-injection-over-stateful-globals)
- [Interface ergonomics & semantics](#interface-ergonomics--semantics)
  - [1. The principle of least astonishment (predictability)](#1-the-principle-of-least-astonishment-predictability)
  - [2. Intent-revealing names](#2-intent-revealing-names)
  - [3. Command-query separation (CQS)](#3-command-query-separation-cqs)
  - [4. Orthogonality (composable primitives)](#4-orthogonality-composable-primitives)
- [Operational reliability & robustness](#operational-reliability--robustness)
  - [1. Idempotency (safe retries)](#1-idempotency-safe-retries)
  - [2. The robustness principle (Postel’s Law)](#2-the-robustness-principle-postels-law)
  - [3. Circuit breaking (fail fast)](#3-circuit-breaking-fail-fast)
  - [4. Bulk & batch operations](#4-bulk--batch-operations)
- [Data handling & evolution](#data-handling--evolution)
  - [1. Scalable pagination (cursor over offset)](#1-scalable-pagination-cursor-over-offset)
  - [2. Evolutionary design (versioning)](#2-evolutionary-design-versioning)
  - [3. Type safety & strict validation](#3-type-safety-strict-validation)
  - [4. Structured error reporting](#4-structured-error-reporting)
  - [5. Single source of truth (DRY data)](#5-single-source-of-truth-dry-data)

## Core architectural philosophy

Foundational decisions that shape the system's structure and maintainability.

### 1. Contract-first design (API first)

Treat the interface definition as the primary product artifact, distinct from its implementation. Define the contract (the "what") rigorously before writing the code (the "how"). This decoupling allows consumers to validate the design against requirements before engineering resources are committed, and it serves as the single source of truth for the system's capabilities.

### 2. The KISS mandate (minimal surface area)

Complexity is the primary vector for defects and integration friction. Expose the smallest number of concepts necessary to solve the problem, aiming for "just enough power." Avoid "Swiss Army knife" interfaces that perform multiple unrelated operations. As a useful heuristic, if an interface requires extensive setup or explanation to use, it likely violates this principle.

### 3. YAGNI (avoid speculative generality)

Do not add parameters, operations, or data fields for hypothetical future needs. Speculative features introduce "accidental complexity"—complexity arising from the solution rather than the problem. Aim to build only what is required for current, concrete use cases to maintain a lean and testable interface.

### 4. Separation of concerns (information hiding)

The API must expose capabilities, not internal state or storage models. Never leak implementation details, such as database schemas or specific algorithms, through the interface. This encapsulation ensures that the internal architecture can be refactored or completely replaced without breaking consumers.

### 5. Explicit configuration (dependency injection over stateful globals)

Prefer explicit parameter passing and dependency injection over stateful global state, singletons, registries, or environment variables for API configuration. Implicit configurations obscure dependencies from caller visibility, prevent static type safety, and introduce global state mutations that make concurrent execution and parallel testing difficult. Programmatic instantiations are statically verifiable, isolate test cases, and make dependency compilation boundaries transparent to bundling tools.

## Interface ergonomics & semantics

Principles for ensuring the API is predictable, descriptive, and easy to use.

### 1. The principle of least astonishment (predictability)

An interface should behave exactly as a user expects based on their prior knowledge of the system. If a standard pattern exists for naming conventions or error structures, deviate from it only with significant justification. Consistency reduces the cognitive load required to learn and use the API.

### 2. Intent-revealing names

Names should describe business intent rather than technical mechanics. For example, a method named `publishArticle()` is superior to `updateRowStatus()`. Use specific, self-descriptive terminology, like `temperatureCelsius` instead of `temp`, to prevent ambiguity and reduce reliance on external documentation.

### 3. Command-query separation (CQS)

Clearly distinguish between operations that retrieve data (queries) and operations that modify state (commands). Queries should ideally be safe and side-effect-free, allowing consumers to call them repeatedly without risk. Avoid mixing data retrieval with state mutation in a single operation, as it leads to unpredictable system behavior.

### 4. Orthogonality (composable primitives)

Design small, independent primitives that can be composed to create complex behaviors, rather than creating rigid, complex operations for every specific scenario. Changing one independent parameter should not have unexpected side effects on unrelated parts of the request.

## Operational reliability & robustness

Designing for failure, distributed systems, and performance in a production environment.

### 1. Idempotency (safe retries)

In a distributed system, network failures are inevitable. Operations that change state must be designed to be idempotent, meaning they can be safely retried multiple times without producing cumulative side effects, such as double-charging. This is often achieved by requiring clients to provide a unique idempotency key or transaction identifier.

### 2. The robustness principle (Postel’s Law)

Follow the robustness principle: "Be conservative in what you send, be liberal in what you accept." Strictly adhere to the interface contract when generating output, but implement tolerance when processing input, such as ignoring unknown fields rather than crashing. This approach improves interoperability and allows the system to evolve without immediately breaking older clients.

### 3. Circuit breaking (fail fast)

If a dependency or subsystem is failing, stop calling it immediately to prevent cascading failures. The interface should fail fast and return a specific error rather than hanging indefinitely. This preserves system resources and provides immediate feedback to the consumer.

### 4. Bulk & batch operations

To reduce network overhead and latency, provide mechanisms to process multiple items in a single request, such as `createItems([item1, item2])`. Ensure the behavior of partial failures is well-defined: either the entire batch fails atomically, or the response clearly indicates the success or failure status of each individual item.

## Data handling & evolution

Guidelines for managing state, validation, and long-term interface maintenance.

### 1. Scalable pagination (cursor over offset)

Never return unbounded lists of data. For large datasets, prefer cursor-based (keyset) pagination over offset-based pagination. Cursors, which point to a specific record, provide constant-time performance (O(1)) and data stability. In contrast, offsets degrade in performance (O(n)) and suffer from skipped or duplicate records when data is modified during iteration.

### 2. Evolutionary design (versioning)

Plan for change from day one. Interfaces will evolve, and breaking changes must be managed without disrupting existing consumers. Use explicit versioning strategies, such as semantic versioning, and establish a clear deprecation lifecycle (warn, then sunset, and finally remove) to give consumers time to migrate.

### 3. Type safety & strict validation

Enforce constraints at the boundary. Use strong types, such as enums instead of raw strings, or distinct types for monetary values, to make invalid states unrepresentable. Validate all input rigorously before processing to prevent data corruption and security vulnerabilities.

### 4. Structured error reporting

Errors must be machine-readable and actionable. Return specific error codes, rather than generic failure indicators, accompanied by descriptive messages. Where possible, include structured metadata that allows the consumer to programmatically recover or correct their input.

### 5. Single source of truth (DRY data)

Avoid defining the same business logic or data structure in multiple places. Ensure that a concept, such as a user or an order, has a canonical representation. Divergent definitions lead to integration errors where one part of the system enforces rules that another ignores.
