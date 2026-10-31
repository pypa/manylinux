#!/bin/bash
# Install ca-certificate and make sure it's "up-to-date", patch if needed

# Stop at any error, show all commands
set -exuo pipefail

# Decision to patch is recorded in install-ca-certificates.sh
# We use /opt/_internal/certs to monitor that decision
if [ ! -d /opt/_internal/certs ]; then
	exit 0
fi

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

case "${OS_ID_LIKE}" in
	rhel) SYSTEM_SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem;;
	debian) SYSTEM_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt;;
	*) exit 1;;
esac

TIMESTAMP_FILE=/opt/_internal/certs.ml.timestamp
if [ -f "${TIMESTAMP_FILE}" ] && [ "${TIMESTAMP_FILE}" -nt "${SYSTEM_SSL_CERT_FILE}" ]; then
	exit 0
fi

CERTIFI_CERT_COUNT=$(grep -c 'BEGIN CERTIFICATE' "${SSL_CERT_FILE}")

if [ "${OS_ID_LIKE}" == "rhel" ]; then
	if [ -d /etc/pki/ca-trust/source/anchors ]; then
		rm -rf /etc/pki/ca-trust/source/anchors
	fi
	mkdir -p /etc/pki/ca-trust/source/anchors
	if [ -d /usr/share/pki/ca-trust-source ]; then
		rm -rf /usr/share/pki/ca-trust-source
		mkdir -p /usr/share/pki/ca-trust-source
	fi
	cp -l /opt/_internal/certs/* /etc/pki/ca-trust/source/anchors/
	# update the system trust store
	update-ca-trust extract
elif [ "${OS_ID_LIKE}" == "debian" ]; then
	# disable all certificates in conf
	sed -i 's/^mozilla\//!mozilla\//g' /etc/ca-certificates.conf
	if [ -d /usr/local/share/ca-certificates ]; then
		rm -rf /usr/local/share/ca-certificates
	fi
	mkdir -p /usr/local/share/ca-certificates
	cp -l /opt/_internal/certs/* /usr/local/share/ca-certificates/
	# update the system trust store
	update-ca-certificates --fresh
fi
NEW_CERT_COUNT=$(grep -c 'BEGIN CERTIFICATE' ${SYSTEM_SSL_CERT_FILE})
if [ "${CERTIFI_CERT_COUNT}" -ne "${NEW_CERT_COUNT}" ]; then
	exit 1
fi
touch ${TIMESTAMP_FILE}
