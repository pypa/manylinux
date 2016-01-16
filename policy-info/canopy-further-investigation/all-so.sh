#!/bin/bash

for F in \
    $(find -L "$@" -type f -a -exec sh -c "file '{}' | grep -q ELF" \; -print);
do
    echo "$F"
    readelf -d "$F" | grep NEEDED
done
