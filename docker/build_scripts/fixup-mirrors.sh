#!/bin/bash
# Fix up mirrors once distro reaches EOL

# Stop at any error, show all commands
set -exuo pipefail
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	if [ "${AUDITWHEEL_ARCH}" == "s390x" ]; then
		yum-config-manager --setopt=os.baseurl=https://download.sinenomine.net/clefos/7/os --save 1>/dev/null
		yum-config-manager --setopt=updates.baseurl=https://download.sinenomine.net/clefos/7/updates --save 1>/dev/null
		yum-config-manager --setopt=extras.baseurl=https://download.sinenomine.net/clefos/7/extras --save 1>/dev/null
		yum-config-manager --setopt=centosplus.baseurl=https://download.sinenomine.net/clefos/7/centosplus --save 1>/dev/null
		if [ -f /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo ]; then
			yum-config-manager --setopt=clefos-rh.baseurl=https://download.sinenomine.net/clefos/7/sclo/s390x/rh --save 1>/dev/null
		fi
		if [ -f /etc/yum.repos.d/epel.repo ]; then
			yum-config-manager --setopt=epel.baseurl=https://download.sinenomine.net/clefos/epel7 --save 1>/dev/null
		fi
	else
		# Centos 7 is EOL and is no longer available from the usual mirrors, so switch
		# to https://vault.centos.org
		sed -i 's/enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf
		sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/*.repo
		sed -i 's;^.*baseurl=http://mirror;baseurl=https://vault;g' /etc/yum.repos.d/*.repo
		if [ "${AUDITWHEEL_ARCH}" == "aarch64" ] || [ "${AUDITWHEEL_ARCH}" == "ppc64le" ]; then
			sed -i 's;/centos/7/;/altarch/7/;g' /etc/yum.repos.d/*.repo
		fi
	fi
fi
