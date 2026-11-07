#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

PIP_WHEEL=$1
LOCAL_VERSION=$2
case "${3:-unpack}" in
	unpack) USE_UNZIP=0;;
	unzip) USE_UNZIP=1;;
	*) exit 1;;
esac

mkdir /tmp/patch-pip
pushd /tmp/patch-pip
if [ "${USE_UNZIP}" -eq 0 ]; then
	wheel unpack "${PIP_WHEEL}"
else
	unzip -d ./pip-unzip "${PIP_WHEEL}"
fi
rm -f "${PIP_WHEEL}"
PIP_CACERT_PEM=$(find . -path '*/_vendor/certifi/cacert.pem')
cp -f /opt/_internal/certs.pem "${PIP_CACERT_PEM}"
wheel pack -d "$(dirname "${PIP_WHEEL}")" --local-version "${LOCAL_VERSION}" ./pip-*
popd
rm -rf /tmp/patch-pip
