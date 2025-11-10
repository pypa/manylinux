import os
import sys
import sysconfig
import unittest


class TestModules(unittest.TestCase):
    def test_sqlite3(self):
        # Make sure sqlite3 module can be loaded properly and is the manylinux version one
        # c.f. https://github.com/pypa/manylinux/issues/1030
        import sqlite3

        print(f"{sqlite3.sqlite_version=}", end=" ", file=sys.stderr)
        assert sqlite3.sqlite_version_info[0:2] >= (3, 50)

        # When the extension is not installed, it raises:
        # sqlite3.OperationalError: no such module: fts5
        conn = sqlite3.connect(":memory:")
        try:
            conn.execute("create virtual table fts5test using fts5 (data);")
        finally:
            conn.close()

    def test_tkinter(self):
        # Make sure tkinter module can be loaded properly
        import tkinter as tk

        print(f"{tk.TkVersion=}", end=" ", file=sys.stderr)
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

        print(f"{curses.ncurses_version=}", end=" ", file=sys.stderr)

    def test_ctypes(self):
        # depends on libffi
        import ctypes  # noqa: F401

    def test_sysconfig(self):
        config_vars = sysconfig.get_config_vars()
        cc = config_vars["CC"]
        cxx = config_vars["CXX"]
        pthread = (
            " -pthread"
            if os.environ["AUDITWHEEL_POLICY"]
            in {"manylinux2014", "manylinux_2_28", "manylinux_2_31"}
            else ""
        )
        assert cc == f"gcc{pthread}", cc
        assert cxx == f"g++{pthread}", cxx
        assert config_vars["LDSHARED"] == f"{cc} -shared", config_vars["LDSHARED"]
        assert config_vars["LDCXXSHARED"] == f"{cxx} -shared", config_vars["LDCXXSHARED"]

    @unittest.skipIf(sys.version_info[:2] < (3, 14), reason="not supported in this version")
    def test_zstd(self):
        from compression import zstd

        print(f"{zstd.zstd_version_info=}", end=" ", file=sys.stderr)
        assert zstd.zstd_version_info[:3] >= (1, 5, 7)

    def test_ssl(self):
        import ssl

        print(f"{ssl.OPENSSL_VERSION_INFO=}", end=" ", file=sys.stderr)
        assert ssl.OPENSSL_VERSION_INFO[:3] >= (1, 1, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
