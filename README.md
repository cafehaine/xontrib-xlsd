# xontrib-xlsd
# DISCLAIMER: This is really early software, it probably wont work on your system.

An improved ls for xonsh, inspired by lsd
[![asciicast](https://asciinema.org/a/mxvzgiAT8tBldKsrxFusN2riY.svg)](https://asciinema.org/a/mxvzgiAT8tBldKsrxFusN2riY)
The asciinema demo isn't great as it doesn't seem to account for the emoji's cell width.

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

# Installation

Install the `xontrib-xlsd` package
```bash
pip install --user xontrib-xlsd
```

And load it from your `.xonshrc`
```bash
xontrib load xlsd
```

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
