Building Docker images
======================

Due to the age of CentOS 5, its version of ``wget`` is unable to fetch
OpenSSL and curl source tarballs. Modern versions of these are needed in
order to fetch the remaining sources.

To build the Docker images, you will need to fetch the tarballs to
``docker/sources/`` prior to building. This can be done with the
provided prefetch script, after which you can proceed with building.
Please run `./build.sh` from the _root_ directory (not this one).

