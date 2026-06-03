import importlib
import os
import sys
import sysconfig
import unittest

ALL_MODULES = [
    "abc",
    "aifc",
    "antigravity",
    "argparse",
    "ast",
    "asynchat",
    "asyncore",
    "asyncio",
    "audioop",
    "base64",
    "bdb",
    "binhex",
    "bisect",
    "bz2",
    "cProfile",
    "calendar",
    "cgi",
    "cgitb",
    "chunk",
    "cmd",
    "code",
    "codecs",
    "codeop",
    "collections",
    "colorsys",
    "compileall",
    "concurrent",
    "configparser",
    "contextlib",
    "contextvars",
    "copy",
    "copyreg",
    "crypt",
    "csv",
    "ctypes",  # depends on libffi
    "curses",  # depends on libncurses
    "dataclasses",
    "datetime",
    "dbm",
    "dbm.gnu",  # depends on libgdbm
    "dbm.ndbm",  # depends on libdb or libgdbm_compat
    "decimal",
    "difflib",
    "dis",
    "distutils",
    "doctest",
    "email",
    "encodings",
    "ensurepip",
    "enum",
    "faulthandler",
    "filecmp",
    "fileinput",
    "fnmatch",
    "formatter",
    "fractions",
    "ftplib",
    "functools",
    "genericpath",
    "getopt",
    "getpass",
    "gettext",
    "glob",
    "gzip",
    "hashlib",
    "heapq",
    "hmac",
    "html",
    "http",
    "idlelib",
    "imaplib",
    "imghdr",
    "imp",
    "importlib",
    "inspect",
    "io",
    "ipaddress",
    "json",
    "keyword",
    "lib2to3",
    "linecache",
    "locale",
    "logging",
    "lzma",
    "mailbox",
    "mailcap",
    "mimetypes",
    "modulefinder",
    "multiprocessing",
    "netrc",
    "nntplib",
    "ntpath",
    "nturl2path",
    "numbers",
    "opcode",
    "operator",
    "optparse",
    "os",
    "ossaudiodev",
    "parser",
    "pathlib",
    "pdb",
    "pickle",
    "pickletools",
    "pipes",
    "pkgutil",
    "platform",
    "plistlib",
    "poplib",
    "posixpath",
    "pprint",
    "profile",
    "pstats",
    "pty",
    "py_compile",
    "pyclbr",
    "pydoc",
    "pydoc_data",
    "queue",
    "quopri",
    "random",
    "re",
    "readline",  # depends on libreadline
    "reprlib",
    "rlcompleter",
    "runpy",
    "sched",
    "secrets",
    "selectors",
    "shelve",
    "shlex",
    "shutil",
    "signal",
    "site",
    "smtpd",
    "smtplib",
    "sndhdr",
    "socket",
    "socketserver",
    "spwd",
    "sqlite3",
    "sre_compile",
    "sre_constants",
    "sre_parse",
    "ssl",
    "stat",
    "statistics",
    "string",
    "stringprep",
    "struct",
    "subprocess",
    "sunau",
    "symbol",
    "symtable",
    "sysconfig",
    "tabnanny",
    "tarfile",
    "telnetlib",
    "tempfile",
    "test",
    "textwrap",
    "threading",
    "timeit",
    "tkinter",
    "token",
    "tokenize",
    "trace",
    "traceback",
    "tracemalloc",
    "tty",
    "turtle",
    "turtledemo",
    "types",
    "typing",
    "unittest",
    "urllib",
    "uu",
    "uuid",
    "venv",
    "warnings",
    "wave",
    "weakref",
    "webbrowser",
    "wsgiref",
    "xdrlib",
    "xml",
    "xmlrpc",
    "zipapp",
    "zipfile",
]


class TestModules(unittest.TestCase):
    def test_sqlite3(self):
        # Make sure sqlite3 module can be loaded properly and is the manylinux version one
        # c.f. https://github.com/pypa/manylinux/issues/1030
        sqlite3 = importlib.import_module("sqlite3")
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
        tk = importlib.import_module("tkinter")
        print(f"{tk.TkVersion=}", end=" ", file=sys.stderr)
        assert tk.TkVersion >= 8.6

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
        ldshared = f"{cc} -shared"
        ldcxxshared = f"{cxx} -shared"
        if os.environ["AUDITWHEEL_POLICY"] == "musllinux_1_2" and sys.version_info[:2] >= (3, 15):
            stack = "-Wl,-z,stack-size=1048576"
            ldshared = f"{ldshared} {stack}"
            ldcxxshared = f"{ldcxxshared} {stack}"

        assert cc == f"gcc{pthread}", cc
        assert cxx == f"g++{pthread}", cxx
        assert config_vars["LDSHARED"] == ldshared, config_vars["LDSHARED"]
        assert config_vars["LDCXXSHARED"] == ldcxxshared, config_vars["LDCXXSHARED"]

    @unittest.skipIf(sys.version_info[:2] < (3, 14), reason="not supported in this version")
    def test_zstd(self):
        zstd = importlib.import_module("compression.zstd")
        print(f"{zstd.zstd_version_info=}", end=" ", file=sys.stderr)
        assert zstd.zstd_version_info[:3] >= (1, 5, 7)

    def test_ssl(self):
        ssl = importlib.import_module("ssl")
        print(f"{ssl.OPENSSL_VERSION_INFO=}", end=" ", file=sys.stderr)
        assert ssl.OPENSSL_VERSION_INFO[:3] >= (1, 1, 1)

    def test_modules(self):
        modules = set(ALL_MODULES)
        if sys.version_info >= (3, 10):
            modules.remove("formatter")
            modules.remove("parser")
            modules.remove("symbol")
        if sys.version_info >= (3, 11):
            modules.add("tomllib")
            modules.add("wsgiref.types")
            modules.remove("binhex")
        if sys.version_info >= (3, 12):
            modules.remove("asynchat")
            modules.remove("asyncore")
            modules.remove("distutils")
            modules.remove("imp")
            modules.remove("smtpd")
        if sys.version_info >= (3, 13):
            modules.add("dbm.sqlite3")
            modules.remove("aifc")
            modules.remove("audioop")
            modules.remove("cgi")
            modules.remove("cgitb")
            modules.remove("chunk")
            modules.remove("crypt")
            modules.remove("imghdr")
            modules.remove("lib2to3")
            modules.remove("mailcap")
            modules.remove("nntplib")
            modules.remove("ossaudiodev")
            modules.remove("pipes")
            modules.remove("sndhdr")
            modules.remove("spwd")
            modules.remove("sunau")
            modules.remove("telnetlib")
            modules.remove("uu")
            modules.remove("xdrlib")
        if sys.version_info >= (3, 14):
            modules.add("annotationlib")
            modules.add("compression.bz2")
            modules.add("compression.gzip")
            modules.add("compression.lzma")
            modules.add("compression.zlib")
            modules.add("compression.zstd")
            modules.add("concurrent.interpreters")
            modules.add("string.templatelib")
        if sys.version_info >= (3, 15):
            modules.add("math.integer")
            modules.remove("sre_compile")
            modules.remove("sre_constants")
            modules.remove("sre_parse")
        for module in sorted(modules):
            with self.subTest(module=module):
                importlib.import_module(module)


if __name__ == "__main__":
    unittest.main(verbosity=2)
