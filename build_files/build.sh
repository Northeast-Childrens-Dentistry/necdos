#!/bin/bash

set -euo pipefail

# Add only NECD identity in this foundation; preserve Aurora packages/services.
cp -avf /ctx/system_files/. /

### Identity: rename the OS and cut Aurora's own links. ID/VARIANT_ID/IMAGE_ID stay "aurora" for now
### because upstream tooling keys on them; change only after testing in a VM.
OSR=/usr/lib/os-release
sed -i -e 's|^NAME=.*|NAME="NECD OS"|' \
  -e 's|^PRETTY_NAME="Aurora |PRETTY_NAME="NECD OS |' \
  -e 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="necdos"|' \
  -e 's|^CPE_NAME=.*|CPE_NAME="cpe:/o:universal-blue:necdos:44"|' \
  -e 's|^LOGO=.*|LOGO=distributor-logo|' "$OSR"
sed -i -E '/^(HOME_URL|DOCUMENTATION_URL|SUPPORT_URL|BUG_REPORT_URL|VERSION_CODENAME)=/d' "$OSR"

# image-info.json drives ujust rebase helpers, the MOTD and the signed-image indicator.
IMG=/usr/share/ublue-os/image-info.json
jq '."image-name"="necdos" | ."image-vendor"="northeast-childrens-dentistry"
    | ."image-ref"="ostree-image-signed:docker://ghcr.io/northeast-childrens-dentistry/necdos"
    | ."image-tag"="candidate"' "$IMG" > /tmp/image-info.json
cp -f /tmp/image-info.json "$IMG"

# Remove Aurora's docs/discussion launchers, offline docs, and unused tips.
rm -f /usr/share/applications/dev.getaurora.{discussions,documentation,offline-docs}.desktop \
  /usr/share/kglobalaccel/dev.getaurora.offline-docs.desktop \
  /usr/share/icons/hicolor/scalable/apps/aurora-{docs,discussions,update}.svg \
  /usr/share/ublue-os/motd/tips/10-tips.md /usr/share/ublue-os/aurora-ascii-logo.txt
rm -rf /usr/share/doc/aurora

### Trust: require a valid NECD signature for the NECD image (cosign.pub), keeping upstream entries.
python3 - <<'PY'
import json
p = "/etc/containers/policy.json"
d = json.load(open(p))
d["transports"].setdefault("docker", {})["ghcr.io/northeast-childrens-dentistry/necdos"] = [
    {"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/necd.pub", "signedIdentity": {"type": "matchRepository"}}]
json.dump(d, open(p, "w"), indent=2)
PY
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

# Identity and trust checks.
grep -q '^NAME="NECD OS"' /etc/os-release
if grep -qi -E 'getaurora|ublue-os/aurora' /etc/os-release; then exit 1; fi
test "$(jq -r '."image-name"' /usr/share/ublue-os/image-info.json)" = necdos
jq -e '.transports.docker["ghcr.io/northeast-childrens-dentistry/necdos"][0].type == "sigstoreSigned"' /etc/containers/policy.json >/dev/null
test -s /etc/pki/containers/necd.pub
ujust toggle-devmode | grep -q "not available on NECD OS"
