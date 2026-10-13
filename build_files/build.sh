#!/bin/bash

set -euo pipefail

# Add only NECD identity in this foundation; preserve Aurora packages/services.
cp -avf /ctx/system_files/. /
install -d -m 0755 /usr/share/necdos
cat > /usr/share/necdos/release.json <<'JSON'
{
  "name": "NECD OS",
  "stage": "foundation",
  "base": "ghcr.io/ublue-os/aurora:stable",
  "ready_for_practice": false,
  "requirements": "https://github.com/Northeast-Childrens-Dentistry/necdos/blob/main/docs/requirements.md"
}
JSON
chmod 0644 /usr/share/necdos/release.json

# Approved app provisioning, fonts and personal setup are subsequent tasks.
