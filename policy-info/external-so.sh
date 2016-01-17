#!/bin/bash

# Usage: $0 MAIN-DIR [SUPP-DIR1 ...]

# Prints a list of all shared libraries that are *needed* by some file in
# MAIN-DIR, but are not *provided* by either the MAIN-DIR or any of the
# SUPP-DIRs.

# First pipeline finds all ELF files, then uses readelf to extract list of
# NEEDED objects (printed like 'blah blah [actual .so name]'), and extracts
# the 'actual .so name' part from this line.
#
# Second pipeline finds all .so basenames.
#
# Then comm -23 means "give me everything in first file that's not in second".
#
# Canopy does weird stuff with splitting the install across two directories
# with symlinks between them, so we accept multiple directory names, and use
# -L to follow symlinks, just to be sure.
comm -23 \
     <(find -L "$1"                                               \
            -type f -a -exec sh -c "file '{}' | grep -q ELF" \;   \
            -print0                                               \
       | xargs -0 -I FILE readelf -d FILE                         \
       | grep NEEDED                                              \
       | sed -e 's/.*\[\(.*\)\]/\1/'                              \
       | sort -u)                                                 \
     <(find -L "$@" -name '*.so*' | xargs -n1 basename | sort -u)
