#!/usr/bin/env bash
# First login of each user: set NECD defaults. Bump the version number to re-run for existing users.
set -euo pipefail

source /usr/lib/ublue/setup-services/libsetup.sh
version-script necd-defaults user 1 || exit 0

/usr/libexec/necd/set-defaults || true
