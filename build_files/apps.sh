#!/bin/bash
# Shared apps: Google Chrome RPM (+ default browser) and build-time checks.
# Flatpaks (Krita, Zoom, Brave, Firefox, LibreOffice) ship as system_files preinstall.d entries.
set -euo pipefail

# --- Google Chrome (repo enabled only for this install) ---
cat > /etc/yum.repos.d/google-chrome.repo <<'REPO'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
REPO
# /opt is a symlink to /var/opt, which does not exist in the build container; rpm cannot mkdir /opt/google through a dangling link.
mkdir -p "$(realpath -m /opt)"
dnf5 install -y google-chrome-stable
# Updates arrive via image rebuilds; keep the repo file but disabled.
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/google-chrome.repo

# /opt is /var/opt on ostree: move the payload into the immutable /usr tree and let
# tmpfiles.d (system_files/usr/lib/tmpfiles.d/necdos-google-chrome.conf) re-link it.
install -d /usr/lib/opt
rm -rf /usr/lib/opt/google
mv "$(realpath /opt)/google" /usr/lib/opt/google

# --- Default browser for new users (Aurora pattern: system-wide mimeapps.list) ---
for t in x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; do
    XDG_CONFIG_HOME=/usr/share/applications xdg-mime default google-chrome.desktop "$t"
done

# --- Build-time checks ---
fail() { echo "apps.sh check failed: $*" >&2; exit 1; }
for f in krita zoom brave firefox libreoffice; do
    grep -q '^\[Flatpak Preinstall ' "/usr/share/flatpak/preinstall.d/$f.preinstall" || fail "$f.preinstall"
done
[[ -x /usr/lib/opt/google/chrome/google-chrome ]] || fail "chrome binary"
# Dangling until boot: the target is /opt/google (tmpfiles relinks it), so test the link, not what it points to.
[[ -L /usr/bin/google-chrome ]] || fail "/usr/bin/google-chrome"
[[ -f /usr/share/applications/google-chrome.desktop ]] || fail "chrome desktop file"
ls /usr/share/icons/hicolor/*/apps/google-chrome.png >/dev/null 2>&1 || fail "chrome icon"
grep -q '^L+ /var/opt/google ' /usr/lib/tmpfiles.d/necdos-google-chrome.conf || fail "tmpfiles snippet"
[[ ! -e "$(realpath /opt)/google" ]] || fail "/opt/google not relocated"
for t in http https; do
    grep -qx "x-scheme-handler/$t=google-chrome.desktop" /usr/share/applications/mimeapps.list || fail "default browser $t"
done

# Taskbar and launchers for the practice apps.
for f in /usr/share/applications/necd-carestack.desktop /usr/share/applications/necd-iris.desktop \
         /usr/share/icons/hicolor/64x64/apps/necd-carestack.png /usr/share/icons/hicolor/64x64/apps/necd-iris.png; do
    [[ -s "$f" ]] || fail "$f"
done
grep -q 'applications:necd-carestack.desktop' /usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js || fail "taskbar layout"
grep -qx 'BrowserApplication=google-chrome.desktop' /etc/xdg/kdeglobals || fail "BrowserApplication"
