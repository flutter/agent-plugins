# TypeScript Documentation

## Documentation Styles

### JSDoc vs Implementation Comments

- **Documentation**: Use `/** ... */` to document public APIs for users (JSDoc/TSDoc).
- **Implementation**: Use `//` for implementation details relevant only to developers reading the source code.
- **Block Comments**: Avoid `/* ... */` for multi-line comments. Use multiple `//` lines instead.

```typescript
/**
 * Computes the weight based on three factors.
 *
 * @param itemsSent The number of items sent.
 * @param itemsReceived The number of items received.
 */
function computeWeight(itemsSent: number, itemsReceived: number): number {
  // This is an implementation comment explaining the formula.
  // It uses multiple lines of // comments.
  return itemsSent * 2 + itemsReceived;
}
```

## JSDoc/TSDoc Format

### General Form

- **Single-line**: Use single-line format for short descriptions: `/** This is a short description. */`
- **Multi-line**: Use multi-line format for longer descriptions:
  ```typescript
  /**
   * Multiple lines of JSDoc text are written here,
   * wrapped normally.
   *
   * @param arg A number to do something to.
   */
  ```

### Markdown

Write JSDoc comments using **Markdown**.

- Use standard Markdown for lists, code blocks, and formatting.
- Avoid plain text formatting that relies on whitespace, as tools will ignore it.

```typescript
/**
 * Computes weight based on three factors:
 *
 * - items sent
 * - items received
 * - last timestamp
 */
```

### Tags

- **@param**: Place `@param` on its own line, followed by the parameter name and its description.
- **@return**: Place `@return` on its own line.
- **@deprecated**: Add this tag for deprecated symbols.

## What to Document

### Top-Level Exports

Document all top-level exports of modules (classes, interfaces, functions, constants).

- **Exception**: You may exempt symbols exported only for tooling (e.g., Angular `@NgModule` classes) if their purpose is obvious.

### Classes

Provide enough information/context for the reader to know **how and when** to use the class.

- Omit textual descriptions on the constructor if the class documentation already covers it.

### Methods and Functions

- **Purpose**: Explain what the function does.
- **Parameters/Return**: Document parameters and return values if they are not immediately obvious from types and names.
- **Redundancy**: Avoid merely restating the name (e.g., `@param name The name` is useless).

## Tooling Compatibility

- Ensure JSDoc structures are valid so that TypeScript-aware editors (VS Code) and documentation generators (TypeDoc) can process them.
- Ensure comments are well-formed to enable strict type checking and tool support.
