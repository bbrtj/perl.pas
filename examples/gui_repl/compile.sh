#!/bin/bash

# Usage: compile.sh [-perl<PATH>] [fpc_args...]
# This script replicates the PERL_LDFLAGS_FPC processing from the makefile
# and passes the flags to fpc along with any additional arguments.
# Use -perl to specify a custom perl interpreter path (e.g., -perl/usr/bin/perl5.36)

PERL="${PERL:-perl}"
FPC_ARGS=()

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == -perl* ]]; then
        PERL="${arg#-perl}"
    else
        FPC_ARGS+=("$arg")
    fi
done

# Get Perl's ldopts
PERL_LDFLAGS=$($PERL -MExtUtils::Embed -e ldopts)

# Clean up gcc-specific flags: remove -Wl, prefix and replace commas with spaces
PERL_LDFLAGS_CLEAN=$(echo "$PERL_LDFLAGS" | sed -e 's/-Wl,/ /g' -e 's/,/ /g')

# Extract only the flags we need: -l%, -L%, -E, --export-dynamic
PERL_LDFLAGS_FPC=""
for flag in $PERL_LDFLAGS_CLEAN; do
    case "$flag" in
        -l*|-L*|-E|--export-dynamic)
            PERL_LDFLAGS_FPC="$PERL_LDFLAGS_FPC -k$flag"
            ;;
    esac
done

# Execute fpc with the extracted flags and any additional arguments
exec fpc $PERL_LDFLAGS_FPC "${FPC_ARGS[@]}"
