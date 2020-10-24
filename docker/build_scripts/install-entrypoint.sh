#!/bin/bash
# Install entrypoint:
# make sure yum is configured correctly and linux32 is available on i686

# Stop at any error, show all commands
set -exuo pipefail

if [ "${AUDITWHEEL_PLAT}" == "manylinux2010_i686" ] || [ "${AUDITWHEEL_PLAT}" == "manylinux2014_i686" ]; then
	echo "i386" > /etc/yum/vars/basearch
	yum -y update
	yum install -y util-linux-ng
	yum clean all
	rm -rf /var/cache/yum
fi
