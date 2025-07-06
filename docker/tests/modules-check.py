import unittest


class TestModules(unittest.TestCase):
    def test_sqlite3(self):
        # Make sure sqlite3 module can be loaded properly and is the manylinux version one
        # c.f. https://github.com/pypa/manylinux/issues/1030
        import sqlite3

        print(f"{sqlite3.sqlite_version=}", end=" ", flush=True)
        assert sqlite3.sqlite_version_info[0:2] >= (3, 50)

    def test_tkinter(self):
        # Make sure tkinter module can be loaded properly
        import tkinter as tk

        print(f"{tk.TkVersion=}", end=" ", flush=True)
        assert tk.TkVersion >= 8.6

    def test_gdbm(self):
        # depends on libgdbm
        import dbm.gnu  # noqa: F401

    def test_ndbm(self):
        # depends on libdb or libgdbm_compat
        import dbm.ndbm  # noqa: F401

    def test_readline(self):
        # depends on libreadline
        import readline  # noqa: F401

    def test_ncurses(self):
        # depends on libncurses
        import curses

        print(f"{curses.ncurses_version=}", end=" ", flush=True)

    def test_ctypes(self):
        # depends on libffi
        import ctypes  # noqa: F401


if __name__ == "__main__":
    unittest.main(verbosity=2)
