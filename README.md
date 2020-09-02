# xontrib-xlsd
# DISCLAIMER: This is really early software, it probably wont work on your system.

An improved ls for xonsh, inspired by lsd
[![asciicast](https://asciinema.org/a/mxvzgiAT8tBldKsrxFusN2riY.svg)](https://asciinema.org/a/mxvzgiAT8tBldKsrxFusN2riY)
The asciinema demo isn't great as it doesn't seem to account for the emoji's cell width.

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
