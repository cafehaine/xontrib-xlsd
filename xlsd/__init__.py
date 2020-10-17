import os
from typing import Callable, Dict, List

COLORS = {
    'symlink_target': "{CYAN}",
    'owner_user':     "{INTENSE_YELLOW}",
    'owner_group':    "{BLUE}",
    'size_unit':      "{CYAN}",
}

XlsdSortMethod = Callable[[List[os.DirEntry]], List[os.DirEntry]]

XLSD_SORT_METHODS: Dict[str, XlsdSortMethod] = {}
#XLSD_SORT_METHODS = {}

def xlsd_register_sort_method(name: str):
    """
    Register a function that will be used to sort all direntries.
    """
    def decorator(func: XlsdSortMethod):
        XLSD_SORT_METHODS[name] = func
        return func
    return decorator

def _direntry_lowercase_name(entry: os.DirEntry) -> str:
    """
    Return the lowercase name for a DirEntry.

    This is used to sort a list of DirEntry by name.
    """
    return entry.name.lower()

@xlsd_register_sort_method('directories_first')
def xlsd_sort_directories_first(entries: List[os.DirEntry]) -> List[os.DirEntry]:
    """
    Sort the entries in alphabetical order, directories first.
    """
    directories = []
    files = []

    for entry in entries:
        if entry.is_dir():
            directories.append(entry)
        else:
            files.append(entry)

    directories.sort(key=_direntry_lowercase_name)
    files.sort(key=_direntry_lowercase_name)

    return directories + files

@xlsd_register_sort_method('alphabetical')
def xlsd_sort_alphabetical(entries: List[os.DirEntry]) -> List[os.DirEntry]:
    """
    Sort the entries in alphabetical order.
    """
    entries.sort(key=_direntry_lowercase_name)
    return entries

@xlsd_register_sort_method('as_is')
def xlsd_sort_as_is(entries: List[os.DirEntry]) -> List[os.DirEntry]:
    """
    Keep the entries in the same order they were returned by the OS.
    """
    return entries
