# Python Documentation

## Documentation Styles

### Docstrings vs Comments

- **Docstrings**: Use `""" ... """` for documentation that describes usage, arguments, and return values (public API) to make them accessible via `__doc__` and tools like `pydoc`.
- **Block/Inline Comments**: Use `#` for implementation details relevant only to developers reading the source.

## Google Style Docstrings

Follow the [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html) for docstrings.

### General Format

- **Triple Double-Quotes**: Always use `"""`.
- **Summary Line**: Write a concise summary (max 80 chars) on the first line, ending with a period.
- **Blank Line**: Follow the summary with a blank line.
- **Sections**: Use specific headers for arguments, return values, and exceptions.

```python
def fetch_bigtable_rows(table_handle, other_silly_variable=None):
    """Fetches rows from a Bigtable.

    Retrieves rows pertaining to the given keys from the Table instance
    represented by table_handle.  String keys will be UTF-8 encoded.

    Args:
        table_handle: An open smalltable.Table instance.
        other_silly_variable: Another optional variable, that has a much
            longer name than the other args, and which does nothing.

    Returns:
        A dict mapping keys to the corresponding table row data
        fetched. Each row is represented as a tuple of strings. For
        example:

        {'Serak': ('Rigel VII', 'Preparer'),
         'Zim': ('Irk', 'Invader'),
         'Lrrr': ('Omicron Persei 8', 'Emperor')}

        If a row is not found, it is not included in the dict.

    Raises:
        IOError: An error occurred accessing the bigtable.Table object.
    """
    pass
```

### Sections Detailed

- **Args**: List each parameter by name, followed by its description.
- **Returns**: Describe the return value (or use `Yields` for generators). You may omit this section if the function returns `None`, though explicit documentation is preferred.
- **Raises**: List all exceptions relevant to the interface.

### Type Annotations

- **Inline Types**: Omit type information from the docstring arguments if you use PEP 484 type hints (strongly recommended) to avoid duplication and drift.

  ```python
  def greet(name: str) -> str:
      """Returns a greeting.

      Args:
          name: The person to greet.

      Returns:
          The greeting string.
      """
      return f"Hello, {name}"
  ```

## Module Docstrings

Provide a top-level docstring in every file describing its contents and usage.

```python
"""A one-line summary of the module or program, terminating in a period.

Leave one blank line.  The rest of this docstring should contain an
overall description of the module or program.  Optionally, it may also
contain a brief description of exported classes and functions and/or usage
examples.

  Typical usage example:

  foo = ClassFoo()
  bar = foo.FunctionBar()
"""
```

## Class Docstrings

Describe the class and its usage. Document public attributes here under an `Attributes` section.

```python
class SampleClass:
    """Summary of class here.

    Longer class information....

    Attributes:
        likes_spam: A boolean indicating if we like SPAM.
        eggs: An integer count of the eggs we have.
    """

    def __init__(self, likes_spam: bool = False):
        """Inits SampleClass with default values."""
        self.likes_spam = likes_spam
        self.eggs = 0
```
