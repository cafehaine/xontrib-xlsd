#!/usr/bin/env python3
"""
An improved ls for xonsh, inspired by lsd.

Registers automatically as an alias for ls on load.
"""
import argparse
from enum import Enum, auto
from fnmatch import fnmatch
import grp
import math
import os
import pwd
import re
import shutil
import stat
import time
from typing import Callable, Dict, List, Optional, Tuple, Union

from xonsh import platform
from xonsh.color_tools import RE_XONSH_COLOR
from xonsh.proc import STDOUT_CAPTURE_KINDS
from xonsh.tools import format_color, print_color
from wcwidth import wcswidth

import xlsd
from xlsd import COLORS, icons

class ColumnAlignment(Enum):
    LEFT = auto()
    RIGHT = auto()
    IGNORE = auto()
    #TODO CENTERED = auto()

if 'XLSD_SORT_METHOD' not in ${...}:
    $XLSD_SORT_METHOD = 'directories_first'

if 'XLSD_LIST_COLUMNS' not in ${...}:
    $XLSD_LIST_COLUMNS = ['mode', 'hardlinks', 'uid', 'gid', 'size', 'mtime', 'name']

XlsdColumn = Callable[[os.DirEntry],str]

#TODO see with xonsh devs, imo shouldn't crash
#_XLSD_COLUMNS: Dict[str, Tuple[XlsdColumn, ColumnAlignment]] = {}
_XLSD_COLUMNS = {}

def xlsd_register_column(name: str, alignment: ColumnAlignment):
    """
    Register a function that can be called in the -l list mode.
    """
    def decorator(func: XlsdColumn):
        _XLSD_COLUMNS[name] = (func, alignment)
        return func
    return decorator

if 'XLSD_ICON_SOURCES' not in ${...}:
    $XLSD_ICON_SOURCES = ['extension', 'libmagic']

XlsdIconSource = Callable[[os.DirEntry], Optional[str]]

#TODO see with xonsh devs, imo shouldn't crash
#_XLSD_ICON_SOURCES: Dict[str, XlsdIconSource] = {}
_XLSD_ICON_SOURCES = {}

def xlsd_register_icon_source(name: str):
    """
    Register a function that can be used to determine the icon for a direntry.
    """
    def decorator(func: XlsdIconSource):
        _XLSD_ICON_SOURCES[name] = func
        return func
    return decorator


# Shamefully taken from https://stackoverflow.com/a/14693789
_ANSI_ESCAPE_REGEX = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def _text_width(text: str) -> int:
    """
    Return the number of terminal cells occupied by some text.

    Handles ANSI escape sequences, as well as xonsh color codes.
    """
    # formatted might be a list of "tokens" or a string with ansi codes
    formatted = format_color(text)
    if isinstance(formatted, list):
        formatted = "".join([tok[1] for tok in formatted])

    no_ansi = _ANSI_ESCAPE_REGEX.sub("", formatted)
    return wcswidth(no_ansi)


_LS_COLUMN_SPACING = 2

def _format_size(size: int) -> str:
    """
    Format a binary size using the IEC units.
    """
    units = ["", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi", "Yi"]
    unit_index = 0

    while size > 1024 and unit_index < len(units) - 1:
        unit_index += 1
        size /= 1024

    unit = units[unit_index] + "B" if unit_index != 0 else "B  "

    return f"{size:.1f}{COLORS['size_unit']}{unit}{{RESET}}"

################
# Icon sources #
################

# the 'magic' lib might only be included in arch linux, it doesn't seem to work
# on macos.
try:
    import magic
    @xlsd_register_icon_source('libmagic')
    def _xlsd_icon_source_libmagic(direntry: os.DirEntry) -> Optional[str]:
        """
        Return the icon for a direntry using the file's mimetype.
        """
        real_path = direntry.path if not direntry.is_symlink() else os.readlink(direntry.path)
        try:
            # This is twice as fast as the "intended method"
            # magic.detect_from_filename(path).mime_type
            # since the "intended method" seems to run the matching twice
            mimetype = magic.mime_magic.file(real_path).split('; ')[0]
        except:
            return None

        for pattern, icon_name in icons.MIMETYPE_ICONS:
            if fnmatch(mimetype, pattern):
                return icon_name
        return None
except ModuleNotFoundError:
    pass


@xlsd_register_icon_source('extension')
def _xlsd_icon_source_extension(direntry: os.DirEntry) -> Optional[str]:
    """
    Return the emoji for a direntry using the file extension.
    """
    if direntry.is_dir(follow_symlinks=True):
        return 'folder'

    _, extension = os.path.splitext(direntry.name)
    extension = extension[1:].lower() # remove leading '.' and use lowercase

    for extensions, icon_name in icons.EXTENSION_ICONS:
        if extension in extensions:
            return icon_name

    return None

#################
# /Icon sources #
#################

def _icon_for_direntry(entry: os.DirEntry) -> str:
    """
    Return the icon for a direntry.
    """
    for source_name in $XLSD_ICON_SOURCES:
        name = None
        try:
            name = _XLSD_ICON_SOURCES[source_name](entry)
        except Exception:
            pass
        if name is not None:
            break

    return icons.LS_ICONS.get(name)


def _get_color_for_direntry(entry: os.DirEntry) -> str:
    """Return one or multiple xonsh colors for the entry using $LS_COLORS."""
    colors = []

    mode = entry.stat(follow_symlinks=False).st_mode
    file_type = stat.S_IFMT(mode)

    # Most of the entries of this list: http://www.bigsoft.co.uk/blog/2008/04/11/configuring-ls_colors
    if entry.is_dir(follow_symlinks=False): # Directory
        colors.extend($LS_COLORS.get("di", []))
    elif not os.path.exists(entry.path): # Broken symlink
        colors.extend($LS_COLORS.get("or", []))
    elif entry.is_symlink(): # Symlink
        colors.extend($LS_COLORS.get("ln", []))
    elif file_type == stat.S_IFIFO: # Pipe
        colors.extend($LS_COLORS.get("pi", []))
    elif file_type == stat.S_IFBLK: # Block device
        colors.extend($LS_COLORS.get("bd", []))
    elif file_type == stat.S_IFCHR: # Char device
        colors.extend($LS_COLORS.get("cd", []))
    elif file_type == stat.S_IFSOCK: # Socket
        colors.extend($LS_COLORS.get("so", []))
    elif mode & stat.S_ISUID: # Setuid
        colors.extend($LS_COLORS.get("su", []))
    elif mode & stat.S_ISGID: # Setgid
        colors.extend($LS_COLORS.get("sg", []))
    elif entry.is_dir(follow_symlinks=False):
        if mode & stat.S_ISVTX and mode & stat.S_IWOTH: # sticky + other writable
            colors.extend($LS_COLORS.get("tw", []))
        elif mode & stat.S_IWOTH: # other writable
            colors.extend($LS_COLORS.get("ow", []))
        elif mode & stat.S_ISVTX: # sticky
            colors.extend($LS_COLORS.get("st", []))
    elif os.access(entry.path, os.X_OK): # executable
        colors.extend($LS_COLORS.get("ex", []))
    else: # Technically wrong, but will probably get us the expected result
        colors.extend($LS_COLORS.get("fi", []))

    for glob, matched_colors in $LS_COLORS.items():
        if fnmatch(entry.name, glob):
            colors.extend(matched_colors)
            return "".join("{"+color+"}" for color in colors)
    return "".join("{"+color+"}" for color in colors)


def _format_direntry_name(entry: os.DirEntry, show_target: bool = True) -> str:
    """
    Return a string containing a bunch of ainsi escape codes as well as the "width" of the new name.
    """
    path = entry.path if not entry.is_symlink() else os.readlink(entry.path)
    name = entry.name

    # Show the icon
    icon = _icon_for_direntry(entry)
    colors = []
    name = "{}{}{{RESET}}".format(icon, name)

    # if entry is a directory, add a trailing '/'
    try:
        if entry.is_dir():
            name = name + "/"
    except OSError: # Probably a circular symbolic link
        name = name + "/"

    # apply color
    color = _get_color_for_direntry(entry)
    if color:
        colors.append(color)

    # if entry is a symlink, underline it
    if entry.is_symlink() and show_target:
        # Show "source -> target"
        target = os.readlink(entry.path)
        name = name + f" {COLORS['symlink_target']}->{{RESET}} {target}"

    return "".join(colors) + name


def _direntry_lowercase_name(entry: os.DirEntry) -> str:
    """
    Return the lowercase name for a DirEntry.

    This is used to sort list of DirEntry by name.
    """
    return entry.name.lower()


def _get_entries(path: str, show_hidden: bool) -> List[os.DirEntry]:
    """
    Return the list of DirEntrys for a path, sorted by name, directories first.
    """
    entries = []
    try:
        with platform.scandir(path) as iterator:
            for entry in iterator:
                # Skip entries that start with a '.'
                if not show_hidden and entry.name.startswith('.'):
                    continue

                entries.append(entry)
    except PermissionError:
        pass

    sort_method = xlsd.XLSD_SORT_METHODS.get($XLSD_SORT_METHOD, lambda x: x)

    return sort_method(entries)


def _get_column_width(entries: List[str], columns: int, column: int) -> int:
    """
    Return the width for a specific column when the layout uses a specified count of columns.
    """
    max_width_col = 0
    for i in range(column, len(entries), columns):
        entry_width = _text_width(entries[i])
        if entry_width > max_width_col:
            max_width_col = entry_width
    return max_width_col


def _compute_width_for_columns(entries: List[str], columns: int) -> int:
    """
    Return the width occupied by the entries when using the specified column
    count.
    """
    # fetch the max width for each columns
    column_max_widths = []
    for col in range(columns):
        column_max_widths.append(_get_column_width(entries, columns, col))

    return sum(column_max_widths) + (columns - 1) * _LS_COLUMN_SPACING


def _determine_column_count(entries: List[str], term_width: int) -> int:
    """
    Return the number of columns that should be used to display the listing.
    """
    max_column_count = 1
    min_width = min([_text_width(e) for e in entries])

    #TODO This could probably be smaller.
    for i in range(term_width // min_width):
        if _compute_width_for_columns(entries, i) < term_width:
            max_column_count = max(i, max_column_count)

    return max_column_count


def _list_directory(path: str, show_hidden: bool = False) -> None:
    """
    Display a listing for a single directory.
    """
    direntries = _get_entries(path, show_hidden)

    if not direntries:
        print("[no files]")
        return

    entries = [_format_direntry_name(direntry, False) for direntry in direntries]

    term_size = shutil.get_terminal_size()

    column_count = _determine_column_count(entries, term_size.columns)

    row_count = math.ceil(len(entries) / column_count)
    columns = [[] for i in range(column_count)]

    # Generate the columns
    for index, entry in enumerate(entries):
        column_index = index % column_count
        columns[column_index].append(entry)

    _show_table(columns)


def _tree_list(path: str, show_hidden: bool = False, prefix: str = "") -> None:
    """
    Recursively prints a tree structure of the filesystem.
    """
    direntries = _get_entries(path, show_hidden)
    for index, direntry in enumerate(direntries):
        is_last_entry = index == len(direntries) - 1
        entry_prefix = prefix + ("╰─" if is_last_entry else "├─")
        print_color("{}{}".format(entry_prefix, _format_direntry_name(direntry, True)))
        if not direntry.is_symlink() and direntry.is_dir():
            _tree_list(direntry.path, show_hidden, prefix + ("  " if is_last_entry else "│ "))


def _column_max_width(column: List[str]) -> int:
    """
    Return the maximum width for a column.
    """
    if not column:
        return 0
    return max([_text_width(cell) for cell in column])


def _show_table(columns: List[List[str]], column_alignments: List[ColumnAlignment] = None) -> None:
    """
    Display a table in the terminal.
    """
    if column_alignments is None:
        column_alignments = [ColumnAlignment.LEFT for column in columns]

    column_max_widths = [_column_max_width(column) for column in columns]

    max_row = len(max(columns, key=lambda col: len(col)))

    for row in range(max_row):
        row_text = []
        for index, col in enumerate(columns):
            last_column = index == len(columns) - 1
            text_value = ""
            length = 0
            if len(col) > row:
                cell = col[row]
                text_value = cell
                length = _text_width(cell)

            if length < column_max_widths[index]:
                alignment = column_alignments[index]
                to_pad = column_max_widths[index] - length
                if alignment == ColumnAlignment.LEFT and not last_column:
                    text_value = text_value + " " * to_pad
                elif alignment == ColumnAlignment.RIGHT:
                    text_value = " " * to_pad + text_value
                elif alignment == ColumnAlignment.IGNORE:
                    pass
            row_text.append(text_value)

        print_color((" " * _LS_COLUMN_SPACING).join(row_text))

################
# List columns #
################

@xlsd_register_column('mode', ColumnAlignment.LEFT)
def _xlsd_column_mode(direntry: os.DirEntry) -> str:
    """
    Format the mode from the stat structure for a file.
    """
    mode = direntry.stat(follow_symlinks=False).st_mode
    file_type = stat.S_IFMT(mode)
    permissions = f"{mode - file_type:4o}"
    permissions_text = f"{permissions[0]}{COLORS['owner_user']}{permissions[1]}{{RESET}}{COLORS['owner_group']}{permissions[2]}{{RESET}}{permissions[3]}"
    return "{}{}".format(icons.STAT_ICONS.get(file_type), permissions_text)


@xlsd_register_column('hardlinks', ColumnAlignment.RIGHT)
def _xlsd_column_hardlinks(direntry: os.DirEntry) -> str:
    """
    Show the number of hardlinks for a file.
    """
    return str(direntry.stat(follow_symlinks=False).st_nlink)


@xlsd_register_column('uid', ColumnAlignment.LEFT)
def _xlsd_column_uid(direntry: os.DirEntry) -> str:
    """
    Show the owner (user) of the file.
    """
    username = pwd.getpwuid(direntry.stat().st_uid)[0]
    return f"{COLORS['owner_user']}{username}{{RESET}}"


@xlsd_register_column('gid', ColumnAlignment.LEFT)
def _xlsd_column_gid(direntry: os.DirEntry) -> str:
    """
    Show the group that owns the file.
    """
    groupname = grp.getgrgid(direntry.stat().st_gid)[0]
    return f"{COLORS['owner_group']}{groupname}{{RESET}}"


@xlsd_register_column('size', ColumnAlignment.RIGHT)
def _xlsd_column_size(direntry: os.DirEntry) -> str:
    """
    Format the size of a file.
    """
    return _format_size(direntry.stat().st_size)


@xlsd_register_column('mtime', ColumnAlignment.LEFT)
def _xlsd_column_mtime(direntry: os.DirEntry) -> str:
    """
    Format the last modification date for a direntry.
    """
    return time.strftime("%x %X", time.gmtime(direntry.stat().st_mtime))


@xlsd_register_column('name', ColumnAlignment.LEFT)
def _xlsd_column_name(direntry: os.DirEntry) -> str:
    """
    Simply format the filename of the direntry.
    """
    return _format_direntry_name(direntry, True)

#################
# /List columns #
#################

def _long_list(path: str, show_hidden: bool = False) -> None:
    """
    Display the long list format for a directory.
    """
    selected_columns = [_XLSD_COLUMNS.get(name, (None, ColumnAlignment.LEFT)) for name in $XLSD_LIST_COLUMNS]
    columns = [[] for i in range(len(selected_columns))]
    alignments = [tup[1] for tup in selected_columns]

    direntries = _get_entries(path, show_hidden)
    for direntry in direntries:
        for index, (callback, _) in enumerate(selected_columns):
            value = "ERR"
            #value = callback(direntry)
            try:
                value = callback(direntry)
            except Exception:
                pass
            columns[index].append(value)

    _show_table(columns, alignments)


_ls_parser = argparse.ArgumentParser()
_ls_parser.add_argument('paths', type=str, nargs='*', default=['.'], help="The directories to list")
_ls_parser.add_argument("-a", "--all", help="Don't hide entries starting with .", action="store_true")
_ls_format_group = _ls_parser.add_mutually_exclusive_group()
_ls_format_group.add_argument("-l", help="Long listing format", action="store_true")
_ls_format_group.add_argument("-R", "--recursive", help="Show in a tree format", action="store_true")


def _ls(args, stdin, stdout, stderr, spec):
    """
    My custom ls function.

    It adds icons like LSD, but also tweaks colors/display in order to have
    ntfs volumes not be a green mess.

    It also displays a tree structure when called with the recursive flag.
    """
    if spec.captured in STDOUT_CAPTURE_KINDS or not spec.last_in_pipeline:
        # If not running from a terminal, use system's "ls" binary.
        #TODO use xonsh's subprocess infrastructure
        @(["/usr/bin/env", "ls"] + args)
        return

    arguments = _ls_parser.parse_args(args)
    for index, path in enumerate(arguments.paths):
        if len(arguments.paths) > 1:
            print_color("{}:".format(path))

        if arguments.recursive:
            _tree_list(path, arguments.all)
        elif arguments.l:
            _long_list(path, arguments.all)
        else:
            _list_directory(path, arguments.all)

        if len(arguments.paths) > 1 and index != len(arguments.paths) - 1:
            print()


aliases['ls'] = _ls
