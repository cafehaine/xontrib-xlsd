# xontrib-xlsd

An improved ls for xonsh, inspired by lsd

1. [How to install xontrib-xlsd](#how-to-install-xontrib-xlsd)
   - [Release version](#release-version)
   - [From git (might be unstable)](#from-git-might-be-unstable)
2. [Features](#features)
3. [Customizing](#customizing)
   - [File order](#file-order)
      - [Setting the file order](#setting-the-file-order)
      - [Creating your own sort function](#creating-your-own-sort-function)
    - [`-l` mode columns](#-l-mode-columns)
      - [Changing the columns/the order](#changing-the-columnsthe-order)
      - [Writing your own column](#writing-your-own-column)

# How to install xontrib-xlsd

## Release version

Install the xontrib

```bash
xpip install xontrib-xlsd
```

And load it in your `.xonshrc`:

```
xontrib load xlsd
```

## From git (might be unstable)

```bash
xpip install git+https://github.com/cafehaine/xontrib-xlsd
```

And load it in your `.xonshrc`:

```
xontrib load xlsd
```

# Features

- Emojis
- Colors
- A `tree`-like display when called recursively
- Customizable
- Written in python so it doesn't need to run a separate binary

# Customizing

## File order

### Setting the file order

In your `.xonshrc`, define a `$XLSD_SORT_METHOD` environment variable with one of the following values:

- `"directories_first"`: The default: alphabetical order, with directories first
- `"alphabetical"`: Simple alphabetical order
- `"as_is"`: The default order of your OS.

### Creating your own sort function

You can create a simple alphabetical (case sensitive) sort function with the snippet:

```python
import xlsd

@xlsd.xlsd_register_sort_method('alpha_case_sensitive')
def my_sort_method(entries):
    entries.sort(key=lambda e: e.name)
    return entries
```

## `-l` mode columns

### Changing the columns/the order

In your `.xonshrc`, define a `$XLSD_LIST_COLUMNS` environment variable and set it's value to your desires.

The default value (similar to coreutil's `ls`) is the following:
```bash
$XLSD_LIST_COLUMNS = ['mode', 'hardlinks', 'uid', 'gid', 'size', 'mtime', 'name']
```

All the built-in columns are used in this config.

### Writing your own column

A column is a function taking for only argument an `os.DirEntry` and that outputs a string.

A simple filename column could be registered like this:
```python
@xlsd_register_column('filename', ColumnAlignment.LEFT)
def _xlsd_column_filename(direntry):
    return direntry.name
```
