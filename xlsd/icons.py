import stat
from typing import Generic, Optional, TypeVar

from wcwidth import wcswidth

T = TypeVar('T')


class IconSet(Generic[T]):
    """
    A storage for icons.

    It has the nice feature that is always returns icons of the same width.

    This is done by getting the cell width of each icons, and padding the
    shorter ones.
    """
    def __init__(self, icons: dict[T, str]):
        self._icons = icons
        self._width = self._compute_width()

    def _compute_width(self) -> int:
        """
        Return the maximum width of this IconSet.
        """
        maximum = 0
        for icon in self._icons.values():
            maximum = max(maximum, wcswidth(icon))
        return maximum

    def add(self, key: T, icon: str):
        """
        Add an icon to this IconSet.
        """
        self._icons[key] = icon
        self._width = self._compute_width()

    def _pad_icon(self, icon: str):
        """
        Pad an icon to this IconSet's width.
        """
        width = wcswidth(icon)
        to_add = self._width - width

        if to_add < 0:
            raise ValueError("This icon's width is bigger than the IconSet's width.")
        if to_add == 0:
            return icon

        right = to_add // 2
        left = to_add - right
        return " "*right + icon + " "*left

    def get_default(self) -> str:
        """
        Return a default icon of the correct width.
        """
        icon = ''
        if self._width == 1:
            icon = '?'
        elif self._width > 1:
            icon = '❔'

        return self._pad_icon(icon)

    def get(self, key: T) -> str:
        """
        Return the icon or a default one with the correct width.
        """
        icon = self._icons.get(key, None)

        # use a default icon
        if icon is None:
            return self.get_default()

        return self._pad_icon(icon)

    def get_or_none(self, key: T) -> Optional[str]:
        """
        Return the icon or None.
        """
        icon = self._icons.get(key, None)

        if icon is None:
            return None

        return self._pad_icon(icon)


STAT_ICONS: IconSet[int] = IconSet({
    stat.S_IFSOCK: "🌐",
    stat.S_IFLNK:  "🔗",
    stat.S_IFREG:  "📄",
    stat.S_IFBLK:  "💾",
    stat.S_IFDIR:  "📁",
    stat.S_IFCHR:  "🖶",
    stat.S_IFIFO:  "🚿",
})

LS_ICONS: IconSet[str] = IconSet({
    'default':    "❔",
    'error':      "🚫",
    'folder':     "📁",
    'text':       "📄",
    'chart':      "📊",
    'music':      "🎵",
    'video':      "🎬",
    'photo':      "📷",
    'iso':        "💿",
    'compressed': "🗜",
    'application':"⚙",
    'rich_text':  "📰",
    'stylesheet': "🎨",
    'contacts':   "📇",
    'calendar':   "📅",
    'config':     "🔧",
    'lock':       "🔒",
    'pirate':     "🕱",
    'database':   "🗃",
    'package':    "📦",
    'mail':       "✉",
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
    'c':          "𝐂",
    'xonsh':      "🐚",
    'haskell':    "λ",
})

MIMETYPE_ICONS = [
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

EXTENSION_ICONS = [
    # Text
    ({'txt', 'log'}, 'text'),
    ({'json', 'yml', 'toml', 'xml', 'ini', 'conf', 'rc', 'cfg', 'vbox', 'vbox-prev'}, 'config'),
    ({'eml'}, 'mail'),
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
    ({'xsh', 'xonshrc'}, 'xonsh'),
    ({'hs', 'lhs', 'hi'}, 'haskell'),
    # Compressed files
    ({'zip', '7z', 'rar', 'gz', 'xz'}, 'compressed'),
    # Executables
    ({'exe', 'bat', 'cmd', 'dll'}, 'windows'),
    ({'so', 'elf', 'sh', 'zsh', 'ksh', 'pl', 'o'}, 'linux'),
    # Misc
    ({'iso', 'cue'}, 'iso'),
    ({'vcard'}, 'contacts'),
    ({'ics'}, 'calendar'),
    ({'lock', 'lck'}, 'lock'),
    ({'reg'}, 'windows'),
    ({'pkg', 'deb', 'rpm', 'apk'}, 'package'),
    ({'db', 'sqlite', 'sqlite3', 'kdbx'}, 'database'),
    ({'torrent'}, 'pirate'),
]
