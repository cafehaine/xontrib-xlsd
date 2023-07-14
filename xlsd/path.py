import os
import stat


class PathEntry:
    """
    FileEntry is a utility class that represents a filesystem entry at a given path. The entry can represent a file,
    directory, or symbolic link. The class provides methods for checking the type of the entry and obtaining file
    statistics for it.

    The class can be used to mirror the behavior of os.DirEntry, because os.DirEntry objects returned by os.scandir()
    do not handle individual file paths and do not allow selective control over following symbolic links for
    different operations.
    """

    def __init__(self, path: str) -> None:
        """
        Initialize a new instance of the FileEntry class.

        :param path: A string containing a path to a file or directory.
        :type path: str
        """
        self.path = path
        self.name = os.path.basename(path)

    def is_dir(self, follow_symlinks: bool = True) -> bool:
        """
        Check if the path represents a directory.

        :param follow_symlinks: If True (default), symlinks are followed (i.e., if the path points to a directory
                                through a symlink, it will return True). If False, symlinks are not followed (i.e.,
                                if the path points to a directory through a symlink, it will return False).
        :type follow_symlinks: bool
        :return: True if the path represents a directory, False otherwise.
        :rtype: bool
        """
        if follow_symlinks:
            return os.path.isdir(self.path)
        else:
            return stat.S_ISDIR(self.stat(follow_symlinks=follow_symlinks).st_mode)

    def is_file(self, follow_symlinks: bool = True) -> bool:
        """
        Check if the path represents a file.

        :param follow_symlinks: If True (default), symlinks are followed (i.e., if the path points to a file through a
                                symlink, it will return True). If False, symlinks are not followed (i.e., if the path
                                points to a file through a symlink, it will return False).
        :type follow_symlinks: bool
        :return: True if the path represents a file, False otherwise.
        :rtype: bool
        """
        if follow_symlinks:
            return os.path.isfile(self.path)
        else:
            return stat.S_ISREG(self.stat(follow_symlinks=follow_symlinks).st_mode)

    def is_symlink(self) -> bool:
        """
        Check if the path represents a symbolic link.

        :return: True if the path represents a symbolic link, False otherwise.
        :rtype: bool
        """
        return os.path.islink(self.path)

    def stat(self, follow_symlinks: bool = True) -> os.stat_result:
        """
        Perform a stat system call on the given path.

        :param follow_symlinks: If True (default), symlinks are followed, similar to os.stat(). If False, symlinks are
                                not followed, similar to os.lstat().
        :type follow_symlinks: bool
        :return: The result of the stat or lstat call on the path.
        :rtype: os.stat_result
        """
        if follow_symlinks:
            return os.stat(self.path)
        else:
            return os.lstat(self.path)