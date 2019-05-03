PEP: XXX
Title: Future 'manylinux' Platform Tags for Portable Linux Built Distributions
Version: $Revision$
Last-Modified: $Date$
Author: Nathaniel J. Smith <njs@pobox.com>
        Thomas Kluyver <thomas@kluyver.me.uk>
BDFL-Delegate: Nick Coghlan <ncoghlan@gmail.com>
Discussions-To: Distutils SIG <distutils-sig@python.org>
Status: Active
Type: Informational
Content-Type: text/x-rst
Created: 3-May-2019
Post-History: 3-May-2019

Abstract
========

This PEP proposes a scheme for new 'manylinux' distribution tags to be defined
without requiring a PEP for every specific tag. The naming scheme is based on
glibc versions, with profiles in the auditwheel tool defining what other
external libraries and symbols a compatible wheel may link against.

While there is interest in defining tags for non-glibc Linux platforms,
this PEP does not attempt to address that.

Rationale
=========

Distributing compiled code for Linux is more complicated than for other popular
operating systems, because the Linux kernel and the libraries which typically
accompany it are built in different configurations and combinations for different
distributions. However, there are certain core libraries which can be expected in
many common distributions and are reliably backwards compatible, so binaries
built with older versions of these libraries will work with newer versions.
:pep:`513` describes these ideas in much more detail.

The ``manylinux1`` (:pep:`513`) and ``manylinux2010`` (:pep:`571`) tags make
use of these features. They define a set of core libraries and symbol versions
which wheels may expect on the system, based on CentOS 5 and 6 respectively.
Typically, packages are built in Docker containers based on these old CentOS
versions, and then the ``auditwheel`` tool is used to check them and bundle any
other linked libraries into the wheel.

If we were to define a ``manylinux2014`` tag based on CentOS 7, there would be
five steps involved to make it practically useful:

1. Write a PEP
2. Prepare docker images based on CentOS 7.
3. Add the definition to auditwheel
4. Allow uploads with the new tag on PyPI
5. Add code to pip to recognise the new tag and check if the platform is
   compatible

Although preparing the docker images and updating auditwheel take more work,
these parts can be used as soon as that work is complete. The changes to pip
are more straightforward, but not all users will promptly install a new version
of pip, so distributors are concerned about moving to a new tag too quickly.

This PEP aims to remove the need for steps 1 and 5 above, so new manylinux tags
can be adopted more easily.

Naming
======

Tags using the new scheme will look like::

    manylinux_glibc_2_17_x86_64

Where ``2_17`` is the major and minor version of glibc. I.e. for this example,
the platform must have glibc 2.17 or newer. Installer tools should be prepared
to handle any numeric values here, but building and publishing wheels to PyPI
will probably be constrained to specific profiles defined by auditwheel.

The existing manylinux tags can also be represented in the new scheme:

- ``manylinux1_x86_64`` becomes ``manylinux_glibc_2_5_x86_64``
- ``manylinux2010_x86_64`` becomes ``manylinux_glibc_2_12_x86_64``

``x86_64`` refers to the CPU architecture, as in previous tags.

While this PEP does not attempt to define tags for non-glibc Linux, the name
glibc is included to leave room for future efforts in that direction.

Wheel compatibility
===================

There are two components to a tag definition: a specification of what makes a
compatible wheel, and of what makes a compatible platform.

A wheel may never use symbols from a newer version of glibc than that indicated
by its tag. Likewise, a wheel with a glibc tag under this scheme may not be
linked against another libc implementation.

As with the previous manylinux tags, wheels will be allowed to link against
a limited set of external libraries and symbols. These will be defined by
profiles in auditwheel. At least initially, they will likely be similar to
the list for manylinux2010 (:pep:`571`), and based on library versions in
newer versions of CentOS.

As with the previous manylinux tags, required libraries which are not on
the whitelist will need to be bundled into the wheel.

Building compatible wheels
--------------------------

For each profile defined in auditwheel, there should be a canonical build
environment, such as a Docker image, available for people to build wheels
for that profile. People can build in other environments, so long as the
resulting wheels can be verified by auditwheel, but the canonical environments
hopefully provide an easy answer for most packages.

The definition of a new profile may well precede the construction of its
build environment; it's not expected that the definition in auditwheel
is held up until a corresponding environment is ready to use.

Verification on upload
----------------------

It is proposed that PyPI will validate manylinux wheels on upload using
auditwheel, and reject non-compliant packages. This means that only tags for
which there is a defined profile can be distributed publicly. However,
organisations may choose to use other tags with this pattern internally,
for instance if they want to build wheels on Debian instead of CentOS.

Platform compatibility
======================

The checks for a compatible platform on installation consist of a heuristic
and an optional override. The heuristic is that the platform is compatible if
and only if it has a version of glibc equal to or greater than that indicated
in the tag name.

The override is defined in an importable ``_manylinux`` module,
the same as already used for manylinux1 and manylinux2010 overrides.
For the new scheme, this module must define a function rather than an
attribute. ``manylinux_glibc_compatible(major, minor)`` takes two integers
for the glibc version number in the tag, and returns True, False or None.
If it is not defined or it returns None, the default heuristic is used.

The compatibility check could be implemented like this::

    def is_manylinux_glibc_compatible(major, minor):
        # Check for presence of _manylinux module
        try:
            import _manylinux
            f = _manylinux.manylinux_glibc_compatible
        except (ImportError, AttributeError):
            # Fall through to heuristic check below
            pass
        else:
            compat = f(major, minor)
            if compat is not None:
                return bool(compat)

        # Check glibc version.
        # PEP 513 contains an implementation of this function.
        return have_compatible_glibc(major, minor)

The installer should also check that the platform is Linux and that the
architecture in the tag matches that of the running interpreter.
These checks are not illustrated here.