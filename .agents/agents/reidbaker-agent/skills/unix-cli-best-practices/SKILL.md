---
name: unix-cli-best-practices
description: Safe, portable, and efficient command-line patterns for macOS/BSD Unix tools (grep, find, sed, awk, xargs, mdfind, pbcopy, open) and modern alternatives (ripgrep, fd). Covers common shell scripting and one-liner use cases including fast searching, text processing, codebase navigation, and parallel execution.
---

# Unix CLI best practices

This guide provides efficient, safe, and portable techniques for manipulating text and finding files from the command line on macOS. By default, macOS uses BSD-derived UNIX utilities (`grep`, `find`, `sed`, `awk`) which have subtle differences from their GNU/Linux counterparts.

When possible, use high-performance replacements (`ripgrep` and `fd`) which respect `.gitignore` rules by default and offer more ergonomic interfaces.

## Modern high-performance alternatives

Use these tools instead of standard BSD utilities for local codebase operations.

### ripgrep (`rg`)

Use `ripgrep` (`rg`) as the preferred tool for searching text. It is faster than standard `grep` and respects `.gitignore` rules by default.

Common use cases:
* Run `rg 'search_term'` to recursively search the current directory.
* Run `rg -S 'term'` to search case-insensitively unless the query contains uppercase letters. Use `rg -i 'term'` for strict case-insensitivity.
* Run `rg -g '*.ts' -g '!*.spec.ts' 'term'` to search `.ts` files while excluding `.spec.ts` files.
* Run `rg -v 'ignore_me'` to print lines that do not match the pattern.
* Run `rg -l 'term'` to list only the names of matching files. Combine with `rg -0` for null-terminated output suitable for `xargs`.
* Run `rg -F 'foo()'` to treat the search pattern as a fixed string rather than a regular expression.
* Run `rg -w 'const'` to match whole words only.
* Run `rg -C 2 'term'` to show two lines of surrounding context. Use `rg -B 2` for preceding context or `rg -A 2` for succeeding context.

Refer to `rg --help` for the complete options list.

### fd

Use `fd` as the preferred tool for traversing the filesystem and finding files. It is faster than standard `find` and respects `.gitignore` rules by default.

Common use cases:
* Run `fd 'pattern'` to find files matching the regex pattern anywhere in their path.
* Run `fd -e py -e txt` to filter results by file extensions.
* Run `fd -t d 'docs'` to find directories. Use `fd -t f` for files and `fd -t l` for symbolic links.
* Run `fd -H` to include hidden files, or `fd -I` to include ignored files (such as `node_modules`). Combine as `fd -HI` to search all files.
* Run `fd -p 'src/assets'` to match the pattern against the full path instead of just the filename.
* Run `fd -e log -x rm` to execute a command on each matching file individually. Use `-X` (e.g., `fd -e log -X rm`) to run the command once with all matching files as arguments.
* Run `fd -a 'pattern'` to return absolute paths instead of relative paths.

Refer to `fd --help` for the complete options list.

## Built-in tools for macOS and BSD

Use these built-in utilities only when `rg` and `fd` are unavailable. Apply precise filters to prevent performance degradation.

### Efficient searching with grep

Do not use `grep | grep -v 'unwanted_dir'` to exclude directories. This approach reads all files before filtering them. Use native exclusion arguments instead to exclude directories at the filesystem level:

```bash
# Slow: reads binary and ignored files
grep -R "pattern" . | grep -v "node_modules"

# Fast: skips the directory completely at the filesystem level
grep -R --exclude-dir=node_modules --exclude-dir=.git "pattern" .
```

Common `grep` flags:
* `-r` or `-R` to search recursively. `-R` follows symbolic links, while `-r` does not.
* `-I` to ignore binary files for faster execution and clean output.
* `--exclude="*.min.js"` to ignore files matching a specific glob.
* `--include="*.dart"` to search only files matching a specific glob.
* `-l` to print only the names of files containing matches.
* `-Z` to print a null character after each filename, which is useful when piping to `xargs -0`.

Example of safely deleting files containing a specific string:
```bash
grep -rlZ -I --exclude-dir=node_modules "DEPRECATED_API" . | xargs -0 rm
```

### High-performance traversal with find

Prevent `find` from traversing irrelevant directory trees by using the `-prune` option.

```bash
# Slow: traverses node_modules entirely, then filters output
find . -name "*.ts" | grep -v "node_modules"

# Fast: skips node_modules entirely
find . -name "node_modules" -prune -o -name "*.ts" -print
```

The expression `-name "node_modules" -prune` stops traversal when encountering a `node_modules` directory. The `-o` (OR) operator specifies that for any other directory or file ending in `.ts`, the path is printed.

### macOS portability with sed

macOS uses BSD `sed`, which differs from GNU `sed` in its handling of in-place editing.

Use the `-i` option with an explicit backup extension. To edit in-place without creating a backup, provide an empty string:

```bash
# Edit in-place without creating a backup
sed -i '' 's/oldName/newName/g' filename.txt

# Edit in-place and create a backup named filename.txt.bak
sed -i '.bak' 's/oldName/newName/g' filename.txt
```

Use the `-E` option to enable extended regular expressions, avoiding the need to escape parentheses and plus signs:
```bash
sed -E 's/(foo|bar)+/baz/g' file.txt
```

### Codebase analysis with awk

Use `awk` for line-by-line data extraction and text processing.

Common use cases:
* Print specific columns from space-separated input:
  ```bash
  ls -l | awk '{print $1, $3}'
  ```
* Find and print duplicate lines in a file without sorting them first:
  ```bash
  awk '!seen[$0]++' filename.txt
  ```
* Filter lines based on column values (for example, printing lines where the third column is greater than 100):
  ```bash
  awk '$3 > 100' data.txt
  ```
* Find lines matching a pattern and print their line number (`NR`) along with the content:
  ```bash
  awk '/Error/ {print NR, $0}' server.log
  ```

### Safe pipelines and parallelism with xargs

Use `xargs` to build and execute commands from standard input. Always use the `-0` option (null-terminated) when processing file paths to handle filenames containing spaces or special characters safely.

```bash
# Unsafe: will fail or perform unintended actions if filenames contain spaces
find . -name "*.log" | xargs rm

# Safe: handles spaces and special characters correctly
find . -name "*.log" -print0 | xargs -0 rm
```

Use the `-P` option to run tasks in parallel:
```bash
# Run up to 4 curl processes in parallel
cat urls.txt | xargs -n 1 -P 4 curl -O
```

### macOS-specific CLI tools

Use macOS-specific utilities to interact with operating system features:

* Use `mdfind` to query the macOS Spotlight index for fast, global file and content searches without scanning the disk:
  ```bash
  # Search by filename
  mdfind -name "project_spec"

  # Search by text content within files
  mdfind "kMDItemTextContent == 'TODO: Refactor'"
  ```
* Use `pbcopy` and `pbpaste` to interact with the system clipboard:
  ```bash
  # Copy file content to the clipboard
  cat ssh_key.pub | pbcopy

  # Paste clipboard content to a file
  pbpaste > new_file.txt
  ```
* Use `open` to open files, directories, or URLs with their default applications:
  ```bash
  # Open the current directory in Finder
  open .

  # Open a local HTML file using a specific application
  open -a "Google Chrome" index.html
  ```
