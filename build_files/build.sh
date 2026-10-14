#!/bin/bash

set -euo pipefail

# Add only NECD identity in this foundation; preserve Aurora packages/services.

# Drop Aurora's wallpaper packs so NECD's replace them (the "Aurora" folder name is
# hard-coded by the first-boot setup screen, so system_files ships NECD art under it).
rm -rf /usr/share/wallpapers/Aurora /usr/share/wallpapers/aurora-wallpaper-* \
  /usr/share/wallpapers/greg-rakozy-aurora /usr/share/wallpapers/jonatan-pie-aurora \
  /usr/share/backgrounds/aurora

cp -avf /ctx/system_files/. /

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

# Fail the build if branding did not land.
for f in /usr/share/wallpapers/Aurora/contents/images/3840x2160.jxl \
         /usr/share/wallpapers/NECD-Kids-on-Toothpaste/contents/images/1920x1080.png \
         /usr/share/wallpapers/NECD-Logo-Multicolor/contents/images/1920x1080.png \
         /usr/share/backgrounds/default.jxl \
         /usr/share/plasma/plasma-welcome/intro-customization.desktop \
         /usr/share/necdos/logo.ans \
         /usr/share/necdos/branding/logo.svg; do
  test -s "$f" || { echo "missing $f" >&2; exit 1; }
done
grep -q NECD-Kids-on-Toothpaste /usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/plasmoidsetupscripts/org.kde.plasma.folder.js
