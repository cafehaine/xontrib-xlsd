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
from typing import Callable, Dict, List, Tuple, Union

import magic
from xonsh.proc import STDOUT_CAPTURE_KINDS
from xonsh import platform
from wcwidth import wcswidth


class ColumnAlignment(Enum):
    LEFT = auto()
    RIGHT = auto()
    IGNORE = auto()
    #TODO CENTERED = auto()


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


# Shamefully taken from https://stackoverflow.com/a/14693789
_ANSI_ESCAPE_REGEX = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def _strip_ansi(text: str) -> str:
    """
    Remove all ansi escape codes in order to simplify length computation.
    """
    return _ANSI_ESCAPE_REGEX.sub("", text)


def _text_width(text: str) -> int:
    """
    Return the number of terminal cells occupied by some text.

    Handles ANSI escape sequences.
    """
    return wcswidth(_strip_ansi(text))


_LS_COLORS = {
    'reset':          "\033[0m",
    'exec':           "\033[1m",
    'symlink':        "\033[4m",
    'symlink_target': "\033[96m",
    'owner_user':     "\033[33m",
    'owner_group':    "\033[35m",
    'size_unit':      "\033[36m",
}

_LS_STAT_FILE_TYPE_ICONS = {
    stat.S_IFSOCK: "🌐",
    stat.S_IFLNK:  "🔗",
    stat.S_IFREG:  "📄",
    stat.S_IFBLK:  "💾",
    stat.S_IFDIR:  "📁",
    stat.S_IFCHR:  "🖶 ",
    stat.S_IFIFO:  "🚿",
}

# Technically only 1, but kitty uses 2 "cells" for each emoji.
_LS_ICON_WIDTH = 2
#TODO This should be determined per-icon with wcwidth

_LS_ICONS = {
    'default':    "❔",
    'error':      "🚫",
    'folder':     "📁",
    'text':       "📄",
    'chart':      "📊",
    'music':      "🎵",
    'video':      "🎬",
    'photo':      "📷",
    'iso':        "💿",
    'compressed': "🗜 ",
    'application':"⚙ ",
    'rich_text':  "📰",
    'stylesheet': "🎨",
    'contacts':   "📇",
    'calendar':   "📅",
    'config':     "🔧",
    'lock':       "🔒",
    # os
    'windows':    "🍷",
    'linux':      "🐧",
    # language
    'java':       "☕",
    'python':     "🐍",
    'php':        "🐘",
    'rust':       "🦀",
    'lua':        "🌙",
    'perl':       "🧅",
    'c':          "𝐂 ",
}

_LS_COLUMN_SPACING = 2

# Note that the order matters!
_LS_MIMETYPE_ICONS = [
    ('inode/directory', 'folder'),
    # Rich text
    ('application/pdf', 'rich_text'),
    ('application/vnd.oasis.opendocument.text', 'rich_text'),
    ('application/msword', 'rich_text'),
    ('application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'rich_text'),
    ('text/html', 'rich_text'),
    # Tabular data/charts
    ('application/vnd.oasis.opendocument.spreadsheet', 'chart'),
    ('application/vnd.ms-excel', 'chart'),
    ('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'chart'),
    ('text/csv', 'chart'),
    # Java
    ('application/java-archive', 'java'),
    ('application/x-java-applet', 'java'),
    # Misc
    ('application/x-iso9660-image', 'iso'),
    ('application/zip', 'compressed'),
    ('application/x-dosexec', 'windows'),
    ('text/x-script.python', 'python'),
    ('text/x-php', 'php'),
    ('application/x-pie-executable', 'linux'),
    ('text/vcard', 'contacts'),
    ('text/calendar', 'calendar'),
    # Generics
    ('text/*', 'text'),
    ('application/*', 'application'),
    ('image/*', 'photo'),
    ('audio/*', 'music'),
    ('video/*', 'video'),
]

_LS_EXTENSION_ICONS = [
    # Text
    ({'txt', 'log'}, 'text'),
    ({'json', 'yml', 'toml', 'xml', 'ini', 'conf', 'rc', 'cfg', 'vbox', 'vbox-prev'}, 'config'),
    # Photo
    ({'jpe', 'jpg', 'jpeg', 'png', 'apng', 'gif', 'bmp', 'ico', 'tif', 'tiff', 'tga', 'webp', 'xpm', 'xcf', 'svg'}, 'photo'),
    # Music
    ({'flac', 'ogg', 'mp3', 'wav'}, 'music'),
    # Video
    ({'avi', 'mp4'}, 'video'),
    # Rich text
    ({'pdf', 'odt', 'doc', 'docx', 'html', 'htm', 'xhtm', 'xhtml', 'md', 'rtf', 'tex', 'rst'}, 'rich_text'),
    # Tabular data/charts
    ({'ods', 'xls', 'xlsx', 'csv'}, 'chart'),
    # Programming languages
    ({'jar', 'jad', 'java'}, 'java'),
    ({'py', 'pyc'}, 'python'),
    ({'php'}, 'php'),
    ({'rs', 'rlib', 'rmeta'}, 'rust'),
    ({'lua'}, 'lua'),
    ({'pl'}, 'perl'),
    ({'css', 'less', 'colorscheme', 'theme', 'xsl'}, 'stylesheet'),
    ({'c', 'h'}, 'c'),
    # Compressed files
    ({'zip', '7z', 'rar', 'gz', 'xz'}, 'compressed'),
    # Executables
    ({'exe', 'bat', 'cmd', 'dll'}, 'windows'),
    ({'so', 'elf', 'sh', 'xsh', 'zsh', 'ksh', 'pl', 'o'}, 'linux'),
    # Misc
    ({'iso', 'cue'}, 'iso'),
    ({'vcard'}, 'contacts'),
    ({'ics'}, 'calendar'),
    ({'lock', 'lck'}, 'lock'),
]


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

    return f"{size:.1f}{_LS_COLORS['size_unit']}{unit}{_LS_COLORS['reset']}"


def _icon_from_mimetype(mimetype: str) -> str:
    """
    Return the emoji for a mimetype.
    """
    for pattern, icon_name in _LS_MIMETYPE_ICONS:
        if fnmatch(mimetype, pattern):
            return _LS_ICONS[icon_name]
    return _LS_ICONS['default']


def _icon_for_direntry(entry: os.DirEntry, real_path: str) -> str:
    """
    Return the emoji for a direntry.

    First tries to determine the emoji using the file extension, and then falls
    back to using mimetypes.
    """
    if entry.is_dir(follow_symlinks=True):
        return _LS_ICONS['folder']

    # Extension based matching
    _, extension = os.path.splitext(entry.name)
    extension = extension[1:].lower() # remove leading '.' and use lowercase

    for extensions, icon_name in _LS_EXTENSION_ICONS:
        if extension in extensions:
            return _LS_ICONS[icon_name]

    # Fall back to mimetype matching
    icon = _LS_ICONS['error']
    try:
        # This is twice as fast as the "intended method"
        # magic.detect_from_filename(path).mime_type
        # since the "intended method" seems to run the matching twice
        mimetype = magic.mime_magic.file(real_path).split('; ')[0]
        icon = _icon_from_mimetype(mimetype)
    except:
        pass
    return icon


def _format_direntry_name(entry: os.DirEntry, show_target: bool = True) -> str:
    """
    Return a string containing a bunch of ainsi escape codes as well as the "width" of the new name.
    """
    path = entry.path if not entry.is_symlink() else os.readlink(entry.path)
    name = entry.name
    # if we need to send the ainsi reset sequence
    need_reset = False

    # Show the icon
    icon = _icon_for_direntry(entry, path)
    name = "{}{}".format(icon, name)

    # if entry is a directory, add a trailing '/'
    if entry.is_dir():
        name = name + "/"

    # if entry is a symlink, underline it
    if entry.is_symlink():
        if show_target:
            # Show "source -> target" (with some colors)
            target = os.readlink(entry.path)
            name = f"{_LS_COLORS['symlink']}{name}{_LS_COLORS['reset']} {_LS_COLORS['symlink_target']}->{_LS_COLORS['reset']} {target}"
        else:
            name = _LS_COLORS['symlink'] + name
            need_reset = True

    # if entry is executable, make it bold (ignores directories as those must be executable)
    if not entry.is_dir() and os.access(path, os.X_OK):
        name = _LS_COLORS['exec'] + name
        need_reset = True

    if need_reset:
        name = name + _LS_COLORS['reset']

    return name


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
    files = []
    directories = []
    try:
        with platform.scandir(path) as iterator:
            for entry in iterator:
                # Skip entries that start with a '.'
                if not show_hidden and entry.name.startswith('.'):
                    continue

                if entry.is_dir():
                    directories.append(entry)
                else:
                    files.append(entry)
    except PermissionError:
        pass

    files.sort(key = _direntry_lowercase_name)
    directories.sort(key = _direntry_lowercase_name)
    return directories + files


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
        print("{}{}".format(entry_prefix, _format_direntry_name(direntry, True)))
        if direntry.is_dir() and not direntry.is_symlink():
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

        print((" " * _LS_COLUMN_SPACING).join(row_text))

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
    permissions_text = f"{permissions[0]}{_LS_COLORS['owner_user']}{permissions[1]}{_LS_COLORS['reset']}{_LS_COLORS['owner_group']}{permissions[2]}{_LS_COLORS['reset']}{permissions[3]}"
    return "{}{}".format(_LS_STAT_FILE_TYPE_ICONS[file_type], permissions_text)


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
    return f"{_LS_COLORS['owner_user']}{username}{_LS_COLORS['reset']}"


@xlsd_register_column('gid', ColumnAlignment.LEFT)
def _xlsd_column_gid(direntry: os.DirEntry) -> str:
    """
    Show the group that owns the file.
    """
    groupname = grp.getgrgid(direntry.stat().st_gid)[0]
    return f"{_LS_COLORS['owner_group']}{groupname}{_LS_COLORS['reset']}"


@xlsd_register_column('size', ColumnAlignment.LEFT)
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
            print("{}:".format(path))

        if arguments.recursive:
            _tree_list(path, arguments.all)
        elif arguments.l:
            _long_list(path, arguments.all)
        else:
            _list_directory(path, arguments.all)

        if len(arguments.paths) > 1 and index != len(arguments.paths) - 1:
            print()


aliases['ls'] = _ls
