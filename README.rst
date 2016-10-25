manylinux
=========

Email: wheel-builders@python.org

Archives: https://mail.python.org/mailman/listinfo/wheel-builders

Older archives: https://groups.google.com/forum/#!forum/manylinux-discuss

The goal of the manylinux project is to provide a convenient way to
distribute binary Python extensions as wheels on Linux. This effort
has produced `PEP 513 <https://www.python.org/dev/peps/pep-0513/>`_
which defines the ``manylinux1_x86_64`` and ``manylinux1_i686`` platform
tags.

Wheel packages compliant with those tags can be uploaded to
`PyPI <https://pypi.python.org>`_ (for instance with `twine
<https://pypi.python.org/pypi/twine>`_) and can be installed with
**pip 8.1 and later**.

The manylinux1 tags allow projects to distribute wheels that are
automatically installed (and work!) on the vast majority of desktop
and server Linux distributions.

This repository hosts several manylinux-related things:


Docker images
-------------

We create Docker Images to be hosted on parsely/manylinux via DockerHub

TravisCI should build and push the docker image to DockerHub

dev-requirements
----------------
Update dev-requirements with the list of packages that we need wheels built for

Our server will periodically update from this repo and build the list of packages for our pypi mirror.
