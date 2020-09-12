# xontrib-xlsd

An improved ls for xonsh, inspired by lsd

1. [How to install xontrib-xlsd](#how-to-install-xontrib-xlsd)
   - [Release version](#release-version)
   - [From git (might be unstable)](#from-git-might-be-unstable)
2. [Features](#features)
3. [Customizing](#customizing)
   - [Icons](#icons)
      - [Registering an icon](#registering-an-icon)
      - [Extension based icon source](#extension-based-icon-source)
      - [Libmagic based icon source](#libmagic-based-icon-source)
      - [Creating a custom icon source and changing the order](#creating-a-custom-icon-source-and-changing-the-order)
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

## Icons

### Registering an icon

In xlsd, icons are registered using a name. The name is then used by the different rules to get an icon for an `os.DirEntry`.

You can view the built-in icons in [xlsd/icons.py](xlsd/icons.py#L99).

Here is how to add an icon (for example a rainbow). Put this in your `.xonshrc`

```python
import xlsd.icons

xlsd.icons.LS_ICONS.add('rainbow', "🌈")
```

Icon sources can now use your fancy icon.

You can also override built-in icons this way.

### Extension based icon source

The extension based rules are the fastest to run, and thus are the prefered way of setting icons.

For example, to use your previously defined rainbow icon as the icon for `.txt` files, you can add the following snippet in your `.xonshrc`:

```python
import xlsd.icons

xlsd.icons.EXTENSION_ICONS.insert(0, ({'txt'}, 'rainbow'))
```

### Libmagic based icon source

*IMPORTANT NOTE*: This source seems to only work on Arch Linux systems at the moment.

The libmagic (used by the `file` command on \*nix) based rules are slower, but allow getting *an* icon when no extension matched.

For example, here we're going to use the xonsh icon for all folders. Add the following snippet in your `.xonshrc`:

```python
import xlsd.icons

xlsd.icons.MIMETYPE_ICONS.insert(0, ("inode/directory", 'xonsh'))
```

Note that this won't work unless you set the icon source order with libmagic as the first source, since the extension source already defines an icon for directory entries.

### Creating a custom icon source and changing the order

The following snipped registers a new icon source (that simply returns the xonsh icon for everything), and makes it the first checked source. Put this in your `.xonshrc`.

```python
@xlsd_register_icon_source('my_source')
def my_icon_source(direntry):
    return 'xonsh'

$XLSD_ICON_SOURCES['my_source', 'extension', 'libmagic']
```

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
