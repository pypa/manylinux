#!/bin/bash
set -e

# Compile wheels
for PYBIN in /opt/python/*/bin; do
    if [[ "$PYBIN" =~ cp26 ]]; then
        echo "Skipping 2.6 because it's horrible"
    elif [[ "$PYBIN" =~ cp33 ]]; then
        echo "Skipping 3.3 because we don't use it"
    elif [[ "$PYBIN" =~ cp34 ]]; then
        echo "Skipping 3.4 because we don't use it"
    else
         CFLAGS="-I/usr/lib/openssl/include" LDFLAGS="-L/usr/lib/openssl/lib" ${PYBIN}/pip wheel cryptography -w /io/wheelhouse/ -f /io/wheelhouse
         ${PYBIN}/pip wheel -r /io/dev-requirements.txt -w /io/wheelhouse/ -f /io/wheelhouse
    fi
done

# Bundle external shared libraries into the wheels
for whl in /io/wheelhouse/*.whl; do
    if [[ "$whl" =~ none-any ]]; then
        echo "Skipping pure wheel $whl"
    elif [[ "$whl" =~ manylinux ]]; then
        echo "Skipping manylinux wheel $whl"
    else
        auditwheel repair $whl -w /io/wheelhouse/
    fi
done

# Remove platform-specific wheels
rm -f /io/wheelhouse/*-linux*.whl
