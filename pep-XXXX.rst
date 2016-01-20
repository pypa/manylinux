PEP: XXXX
Title: A Platform Tag for Portable Linux Built Distributions
Version: $Revision$
Last-Modified: $Date$
Author: Robert T. McGibbon <rmcgibbo@gmail.com>, Nathaniel J. Smith <njs@pobox.com>
Status: Draft
Type: Process
Content-Type: text/x-rst
Created: 01-Jan-2016
Post-History: 30-Aug-2002


Abstract
========

This PEP proposes the creation of a new platform tag for Python package built
distributions, such as wheels, called ``manylinux_1_{x86_64,i386}`` with
external dependencies limited restricted to a standardized subset of
the Linux kernel and core userspace ABI. It proposes that PyPI support
uploading and distributing Wheels with this platform tag, and that ``pip``
support downloading and installing these packages on compatible platforms.


Rationale
=========

Currently, distribution of binary Python extensions for Windows and OS X is
straightforward. Developers and packagers build wheels, which are assigned
platform tags such as ``win32`` or ``macosx_10_6_intel``, and upload these
wheels to PyPI. Users can download and install these wheels using tools such
as ``pip``.

For Linux, the situation is much more delicate. In general, compiled Python
extension modules built on one Linux distribution will not work on other Linux
distributions, or even on the same Linux distribution with different system
libraries installed.

Build tools using PEP 425 platform tags [1]_ do not track information about the
particular Linux distribution or installed system libraries, and instead assign
all wheels the too-vague ``linux_i386`` or ``linux_x86_64`` tags. Because of
this ambiguity, there is no expectation that ``linux``-tagged built
distributions compiled on one machine will work properly on another, and for
this reason, PyPI has not permitted the uploading of wheels for Linux.

It would be ideal if wheel packages could be compiled that would work on *any*
linux system. But, because of the incredible diversity of Linux systems -- from
PCs to Android to embedded systems with custom libcs -- this cannot
be guaranteed in general.

Instead, we define a standard subset of the kernel+core userspace ABI that,
in practice, is compatible enough that packages conforming to this standard
will work on *many* linux systems, including essentially all of the desktop
and server distributions in common use. We know this because there are
companies who have been distributing such widely-portable pre-compiled Python
extension modules for Linux -- e.g. Enthought with Canopy [2]_ and Continuum
Analytics with Anaconda [3]_.

Building on the compability lessons learned from these companies, we thus
define a baseline ``manylinux_1`` platform tag for use by binary Python
wheels, and introduce the implementation of preliminary tools to aid in the
construction of these ``manylinux_1`` wheels.


Key Causes of Inter-Linux Binary Incompatibility
================================================

To properly define a standard that will guarantee that wheel packages meeting
this specification will operate on *many* linux platforms, it is necessary to
understand the root causes which often prevent portability of pre-compiled
binaries on Linux. The two key causes are dependencies on shared libraries
which are not present on users' systems, and dependencies on particular
versions of certain core libraries like ``glibc``.


External Shared Libraries
-------------------------

Most desktop and server linux distributions come with a system package manager
(examples include ``APT`` on Debian-based systems, ``yum`` on
``RPM``-based systems, and ``pacman`` on Arch linux) that manages, among other
responsibilities, the installation of shared libraries installed to system
directories such as ``/usr/lib``. Most non-trivial Python extensions will depend
on one or more of these shared libraries, and thus function properly only on
systems where the user has the proper libraries (and the proper
versions thereof), either installed using their package manager, or installed
manually by setting certain environment variables such as ``LD_LIBRARY_PATH``
to notify the runtime linker of the location of the depended-upon shared
libraries.


Versioning of Core Shared Libraries
-----------------------------------

Even if author or maintainers of a Python extension module with to use no
external shared libraries, the modules will generally have a dynamic runtime
dependency on the GNU C library, ``glibc``. While it is possible, statically
linking ``glibc`` is usually a bad idea because of bloat, and because certain
important C functions like ``dlopen()`` cannot be called from code that
statically links ``glibc``. A runtime shared library dependency on a
system-provided ``glibc`` is unavoidable in practice.

The maintainers of the GNU C library follow a strict symbol versioning scheme
for backward compatibility. This ensures that binaries compiled against an older
version of ``glibc`` can run on systems that have a newer ``glibc``. The
opposite is generally not true -- binaries compiled on newer Linux
distributions tend to rely upon versioned functions in glibc that are not
available on older systems.

This generally prevents built distributions compiled on the latest Linux
distributions from being portable.


The ``manylinux_1`` policy
==========================

For these reasons, to achieve broad portability, Python wheels

 * should depend only on an extremely limited set of external shared
   libraries; and
 * should depend only on ``old`` symbol versions in those external shared
   libraries.

The ``manylinux_1`` policy thus encompasses a standard for what the
permitted external shared libraries a wheel may depend on, and the maximum
depended-upon symbol versions therein.

The permitted external shared libraries are: ::

  "libpanelw.so.5", "libncursesw.so.5", "libgcc_s.so.1", "libstdc++.so.6",
  "libm.so.6", "libdl.so.2", "librt.so.1", "libcrypt.so.1", "libc.so.6",
  "libnsl.so.1", "libutil.so.1", "libpthread.so.0", "libX11.so.6",
  "libXext.so.6", "libXrender.so.1", "libICE.so.6", "libSM.so.6",
  "libGL.so.1", "libgobject-2.0.so.0", "libgthread-2.0.so.0",
  "libglib-2.0.so.0", "libgmodule-2.0.so.0", and "libgio-2.0.so.0".

On Debian-based systems, these libraries are provided by the packages ::

    "libncurses5", "libgcc1", "libstdc++6", "libc6", "libx11-6", "libxext6",
    "libxrender1", "libice6", "libsm6", "libgl1-mesa-glx", and "libglib2.0-0".

On RPM-based systems, these libraries are provided by the packages ::

    "ncurses", "libgcc", "libstdc++", "glibc", "libXext", "libXrender",
    "libICE", "libSM", "mesa-libGL", and "glib2".

This list was compiled by checking the external shared library dependencies of
the Canopy [1]_ and Anaconda [2]_ distributions, which both include a wide array
of the most popular Python modules and have been confirmed in practice to work
across a wide swath of Linux systems in the wild.

For dependencies on externally-provided versioned symbols in the above shared
libraries, the following symbol versions are permitted: ::

    GLIBC <= 2.5
    CXXABI <= 3.4.8
    GLIBCXX <= 3.4.9
    GCC <= 4.2.0

These symbol versions were determined by inspecting the latest symbol version
provided in the libraries distributed with CentOS 5, a Linux distribution
released in April 2007. In practice, this means that Python wheels which conform
to this policy should function on almost any linux distribution released after
this date.


Compilation and Tooling
=======================

To support the compilation of wheels meeting the ``manylinux_1`` standard, we
provide initial drafts of two tools.

The first is a Docker image based on CentOS 5.11, which is recommended as an
easy to use self-contained build box for compiling  ``manylinux_1`` wheels.
Compiling on a more recently-released linux distribution will generally
introduce dependencies on too-new versioned symbols. The image comes with a
full compiler suite installed (``gcc``, ``g++``, and ``gfortran`` 4.8.2) as
well as the latest releases of Python and pip.

The second tool is a command line executable called ``auditwheel``. First, it
inspects all of the ELF files inside a wheel to check for dependencies on
versioned symbols or external shared libraries, and verifies conformance with
the ``manylinux_1`` policy. This includes the ability to add the new platform
tag to conforming wheels.

In addition, ``auditwheel`` has the ability to automatically modify wheels that
depend on external shared libraries by copying those shared libraries from
the system into the wheel itself, and modifying the appropriate RPATH entries
such that these libraries will be picked up at runtime. This accomplishes a
similar result as if the libraries had been statically linked without requiring
changes to the build system.

Neither of these tools are necessary to build wheels which conform with the
``manylinux_1`` policy. Similar results can usually be achieved by statically
linking external dependencies and/or using certain inline assembly constructs
to instruct the linker to prefer older symbol versions, however these tricks
can be quite esoteric.


Platform Detection in ``pip``
=============================

TODO How does ``pip`` detect that it's running on a ``manylinux_1`` compatible
system?


Security Implications
=====================

One of the advantages of dependencies on centralized libraries in Linux is
that bugfixes and security updates can be deployed system-wide, and
applications which depend on on these libraries will automatically feel the
effects of these patches when the underlying libraries are updated. This can
be particularly important for security updates in packages communication
across the network or cryptography.

``manylinux_1`` wheels distributed through PyPI that bundle security-critical
libraries like OpenSSL will thus assume responsibility for prompt updates in
response disclosed vulnerabilities and patches. This closely parallels the
security implications of the distribution of binary wheels on Windows that,
because the platform lacks a system package manager, generally bundle their
dependencies.


Rejected Alternatives
=====================

One alternative is provide separate platform tags for each Linux distribution
(and each version thereof). This would require that package authors would be
required to compile and upload twenty or more different built distributions of
their package to PyPI to cover the common linux distributions in use, which we
consider too onerous to be practical.


References
==========

.. [1] PEP 425 -- Compatibility Tags for Built Distributions
   (https://www.python.org/dev/peps/pep-0425/)
.. [2] Enthought Canopy Python Distribution
   (https://store.enthought.com/downloads/)
.. [3] Continuum Analytics Anaconda Python Distribution
   (https://www.continuum.io/downloads)


Copyright
=========

This document has been placed into the public domain.

..

   Local Variables:
   mode: indented-text
   indent-tabs-mode: nil
   sentence-end-double-space: t
   fill-column: 70
   coding: utf-8
   End:
