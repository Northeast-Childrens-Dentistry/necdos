#!/bin/bash

set -euo pipefail

# Add only NECD identity in this foundation; preserve Aurora packages/services.

# Drop Aurora's wallpaper packs so NECD's replace them (the "Aurora" folder name is
# hard-coded by the first-boot setup screen, so system_files ships NECD art under it).
rm -rf /usr/share/wallpapers/Aurora /usr/share/wallpapers/aurora-wallpaper-* \
  /usr/share/wallpapers/greg-rakozy-aurora /usr/share/wallpapers/jonatan-pie-aurora \
  /usr/share/backgrounds/aurora
# default.jxl/default-dark.jxl are upstream symlinks into that folder; cp will not write through a dangling link.
rm -f /usr/share/backgrounds/default.jxl /usr/share/backgrounds/default-dark.jxl

cp -avf /ctx/system_files/. /
bash /ctx/apps.sh


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

# Friendlier app names for non-technical users: change only the menu entry's display name
# (window titles inside the apps keep their own name). Keywords keep the old name searchable.
rename_app() {
  local f=/usr/share/applications/$1.desktop
  [ -f "$f" ] || { echo "rename_app: $f not found, skipping"; return 0; }
  sed -i -E "/^\[Desktop Action/,\$!{/^Name\[[^]]*\]=/d}; s/^Name=$2\$/Name=$3/" "$f"
  grep -qx "Name=$3" "$f"
}
rename_app org.kde.dolphin Dolphin "Files"
rename_app org.kde.konsole Konsole "Terminal"
rename_app org.kde.kate Kate "Text Editor"
rename_app org.kde.ark Ark "Archive Manager"

### Trust: require a valid NECD signature for the NECD image (cosign.pub), keeping upstream entries.
python3 - <<'PY'
import json
p = "/etc/containers/policy.json"
d = json.load(open(p))
d["transports"].setdefault("docker", {})["ghcr.io/northeast-childrens-dentistry/necdos"] = [
    {"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/necd.pub", "signedIdentity": {"type": "matchRepository"}}]
json.dump(d, open(p, "w"), indent=2)
PY

# Replace Aurora's logo icons (svg, in every icon theme) with the NECD badge, by variant.
B=/usr/share/necdos/branding
while IFS= read -r -d '' f; do
  case "$f" in
    *-symbolic.svg) src=$B/logo-symbolic.svg ;;
    *-white.svg) src=$B/logo-white.svg ;;
    *) src=$B/logo.svg ;;
  esac
  cp -f --remove-destination "$src" "$f"
done < <(find /usr/share/icons /usr/share/pixmaps -type f \( -name 'distributor-logo*.svg' -o -name 'start-here*.svg' -o -name 'auroralogo-*.svg' \) -print0)
cp -f --remove-destination $B/wordmark.svg /usr/share/pixmaps/aurora-banner.svg
cp -f --remove-destination $B/system-logo.png /usr/share/pixmaps/system-logo.png
cp -f --remove-destination $B/system-logo-white.png /usr/share/pixmaps/system-logo-white.png
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

# Fail the build if branding did not land.
for f in /usr/share/wallpapers/Aurora/contents/images/3840x2160.jxl \
         /usr/share/wallpapers/NECD-Doodle-Cream/contents/images/1920x1080.png \
         /usr/share/wallpapers/NECD-Logo-Multicolor/contents/images/1920x1080.png \
         /usr/share/backgrounds/default.jxl \
         /usr/share/plasma/plasma-welcome/intro-customization.desktop \
         /usr/share/necdos/logo.ans \
         /usr/share/necdos/branding/logo.svg; do
  test -s "$f" || { echo "missing $f" >&2; exit 1; }
done
grep -q NECD-Doodle-Cream /usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/plasmoidsetupscripts/org.kde.plasma.folder.js
grep -qx "Name=Files" /usr/share/applications/org.kde.dolphin.desktop
K=/usr/share/kde-settings/kde-profile/default/xdg/kglobalshortcutsrc
grep -qx 'Log Out=Ctrl+Shift+Esc,Ctrl+Shift+Esc,Show Logout Screen' "$K"
grep -qx '_launch=Ctrl+Alt+Del\\tMeta+Esc' "$K"
test -e /usr/share/applications/org.kde.plasma-systemmonitor.desktop
