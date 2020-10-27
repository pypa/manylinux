centos-6-no-vsyscall
====================

*Summary*: Because of
https://mail.python.org/pipermail/wheel-builders/2016-December/000239.html,
this a CentOS 6.10 Docker image that rebuilds ``glibc`` without
*vsyscall* is necessary to reliably run ``manylinux2010`` on 64-bit
hosts.  This requires building the image on a system with
``vsyscall=emulate`` but allows the resulting container to run on
systems with ``vsyscall=none`` or ``vsyscall=emulate``.

*vsyscall* is an antiquated optimization for a small number of
frequently-used system calls.  A vsyscall-enabled Linux kernel maps a
read-only page of data and system calls into a process' memory at a
fixed address.  These system calls can then be invoked by
dereferencing a function pointers to fixed offsets in that page,
saving a relatively expensive context switch. [1]_

Unfortunately, because the code and its location in memory are fixed
and well-known, the vsyscall mechanism has become a source of gadgets
for ROP attacks (specifically, Sigreturn-Oriented Programs). [2]_
Linux 3.1 introduced vsyscall emulation that prevents attackers from
jumping into the middle of the system calls' code at the expense of
speed, as well as the ability to disable it entirely.  [3]_ [4]_ The
vsyscall mechanism could not be eliminated at the time because
``glibc`` versions earlier than 2.14 contained hard-coded references
to the fixed memory address, specifically in ``time(2)``. [5]_ These
segfault when attempting to issue a vsyscall-optimized system call
against a kernel that has disabled it.

Linux introduced a "virtual dynamic shared object" (vDSO) that
achieves the same high-speed, in-process system call mechanism via
shared objects sometime before the kernel's migration to git.  While
old itself, vDSO 's presentation as a shared library allows it to
benefit from ASLR on modern systems, making it no more amenable to ROP
gadgets than any other shared library.  ``glibc`` only switched over
completely to vDSO as of glibc 2.25, so until recently vsyscall
emulation has remained on for most kernels. [6]_ Furthermore, i686
does not use vsyscall at all, so no version of ``glibc`` requires
patching on that architecture.

At the same time, vsyscall emulation still exposed values useful to
ROP attacks, so Linux 4.4 added a compilation option to disable
it. [7]_ [8]_ Distributions are beginning to ship kernels configured
without vsyscall, and running CentOS 5 (``glibc`` 2.5) or 6 (``glibc``
2.12) Docker containers on these distributions indeed causes segfaults
without ``vsyscall=emulate`` [9]_ [10]_.  CentOS 6, however, is
supported until 2020.  It is likely that more and more distributions
will ship with ``CONFIG_LEGACY_VSYSCALL_NONE``; if managed CI services
like Travis make this switch, developers will be unable to build
``manylinux2010`` wheels with our Docker image.

Fortunately, vsyscall is merely an optimization, and patches that
remove it can be backported to glibc 2.12 and the library recompiled.
The result is this Docker image.  It can be run on kernels regardless
of their vsyscall configuration because executable and libraries on
CentOS are dynamically linked against glibc.  Libraries built on this
image are unaffected because:

a) the kernel only maps vsyscall pages into processes;
b) only glibc used the vsyscall interface directly, and it's
   included in manylinux2010's whitelist policy.

Developers who build this vsyscall-less Docker image itself, however,
must do so on a system with ``vsyscall=emulate``.

References:
===========

.. [1] https://lwn.net/Articles/446528/
.. [2] http://www.cs.vu.nl/~herbertb/papers/srop_sp14.pdf
.. [3] https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=5cec93c216db77c45f7ce970d46283bcb1933884
.. [4] https://www.kernel.org/pub/linux/kernel/v3.x/ChangeLog-3.1
.. [5] https://sourceware.org/git/?p=glibc.git;a=blob;f=ChangeLog;h=3a6abda7d07fdaa367c48a9274cc1c08498964dc;hb=356f8bc660a154a07b03da7c536831da5c8f74fe
.. [6] https://sourceware.org/git/?p=glibc.git;a=blob;f=ChangeLog;h=6037fef737f0338a84c6fb564b3b8dc1b1221087;hb=58557c229319a3b8d2eefdb62e7df95089eabe37
.. [7] https://googleprojectzero.blogspot.fr/2015/08/three-bypasses-and-fix-for-one-of.html
.. [8] https://outflux.net/blog/archives/2016/09/27/security-things-in-linux-v4-4/
.. [9] https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=852620#20
.. [10] https://github.com/CentOS/sig-cloud-instance-images/issues/62
