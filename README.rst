manylinux
=========

Email: manylinux-discuss@googlegroups.com

Archives: https://groups.google.com/forum/#!forum/manylinux-discuss

Synopsis
--------

Right now, if you want to distribute a binary Python extension on
Windows or OS/X, then there's a nice straightforward way to do that:
you build a wheel, it gets a platform like "win32" or
"macosx_10_6_intel", you upload it to PyPI, your users download it,
everyone's happy. On Linux, though, the situation is a mess. The
standard advice is to make sure your build and target systems have the
same version of the same distribution with the same packages
installed. The standard tools don't even try to keep track of this;
they just give up and tag all builds as "linux", with the result that
this string is so generic it doesn't actually mean anything.

It sure would be nice if we there were a standard way to build our
packages that would let them work on *any* linux system, so we could
distribute wheels to our users. To distinguish them from the too-vague
"linux" tag, we might label these as "anylinux" builds.

Of course that's an impossible dream -- there are just too many wildly
different linux systems out there (think about Android, embedded
systems using weird libcs, ...). But it is possible to define a
standard subset of the kernel+core userspace ABI that, in practice, is
compatible enough that packages built against it will work on *many*
linux systems, including essentially all of the desktop and server
distributions that people actually use. We know this because there are
companies who have been doing it for years -- e.g. Enthought with
`Canopy <https://store.enthought.com/downloads/>`_ and Continuum with
`Anaconda <https://www.continuum.io/downloads>`_.

So: our plan here is to exploit the work these companies have already
done, and use it to standardize a baseline "manylinux" platform for
use in binary Python wheels. (Or, actually, a "manylinux1" platform,
because if this works then we expect that in a few years once people
stop using RHEL 5 then we'll want to bump up to a newer set of
baseline libraries.)


Todo
----

* Consolidate information about `Anaconda
  <https://mail.scipy.org/pipermail/numpy-discussion/2016-January/074602.html>`_
  and Canopy into a standard describing what libraries a manywheel1
  wheel is allowed to link against.

* Create a docker image to help people actually build such wheels:

  * As a starting point, we have a copy of the docker file that
    Enthought uses in ``docker/``.

  * What it's missing ATM is builds of the Python interpreter itself.

* Integrate Robert McGibbon's work to `audit and rename such wheels
  <https://github.com/rmcgibbo/deloc8>`_

* Make some demo wheels that people can try to verify that this
  approach works

* Write a PEP specifying the platform, and providing advice on how pip
  (or other pip-like installers) should determine whether the system
  they are running on counts as a "manylinux1 system".

* Get support for this into pip

* Get PyPI to start allowing manylinux wheels


Notes
-----

One thing we'll need is a rule for determining whether a system is
considered to be manylinux1-compatible (e.g., so pip can decide
whether it's running on a "manylinux1 system" -- this is different
from deciding whether a given *wheel* is manylinux1 compatible).
I (= njs) am thinking maybe our rule should be:

* the regular wheel platform tag (which is
  ``distutils.util.get_platform()``) starts with the string
  ``"linux"``
* the interpreter is linked to a version of glibc that is >= the one
  in CentOS 5
* we check some file in /etc/pypa/compatibility or something and find
  that there is no flag in there specifically saying "this platform is
  not manylinux1 compatible"

In principle one could get much fancier trying to track down every
library that's in the spec and checking its version etc., but keep in
mind that the companies distributing Python-on-Linux distributions are
using the rule "if it's linux then it's compatible", and this is
actually working for them, and the idea here is to use the same
baseline platform as they do. So "just assume it's compatible" is
*very* likely to be true; trying to get fancier is likely to introduce
more false negatives than it is to correct false positives, just
because there are so few false positives to correct. The glibc version
check is included because it's easy to do reliably (see below) and
will fix the main known problem of people running RHEL 4 or
alternative libcs. The config file check is included as
future-proofing in case RHEL 8 or whatever decides to change things in
a way that breaks old wheels.

How to determine whether the current Python interpreter is linked
against glibc, and if so then what version::

  import ctypes

  # We want a symbol from glibc, which would normally done by calling
  # CDLL("libc.so.6"). But that would have the side-effect of loading
  # glibc if it weren't already loaded, which would defeat the purpose
  # of this check. Instead we call CDLL(None), which calls
  # dlopen(NULL, ...), which gives us access to all the symbols in the
  # process's ELF namespace without loading anything new.
  process_namespace = ctypes.CDLL(None)

  try:
      gnu_get_libc_version = process_namespace.gnu_get_libc_version
  except AttributeError:
      print("Not glibc")

  gnu_get_libc_version.restype = ctypes.c_char_p
  version_str = gnu_get_libc_version()
  # py2 / py3 compatibility:
  if not isinstance(version_str, str):
      version_str = version_str.decode("ascii")

  version = [int(piece) for piece in version_str.split(".")]
  print("glibc, major version = %s, minor version = %s % version)

CentOS 5 uses glibc 2.5.
