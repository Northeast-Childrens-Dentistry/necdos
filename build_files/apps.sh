#!/bin/bash
# Shared apps: Google Chrome RPM (+ default browser) and build-time checks.
# Flatpaks (Krita, Zoom, Brave, Firefox, LibreOffice, Bottles) ship as system_files preinstall.d entries.
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

# KDE reads its own kde-mimeapps.list BEFORE the generic mimeapps.list; Aurora/Fedora's sets web links
# to Falkon (not installed), so KDE apps (Welcome Center, Flatpak link portal) ignored Chrome.
sed -i -E 's#^(x-scheme-handler/https?)=.*#\1=google-chrome.desktop#; s#^(text/html|application/xhtml\+xml)=.*#\1=google-chrome.desktop#' \
    /usr/share/applications/kde-mimeapps.list

# --- Build-time checks ---
fail() { echo "apps.sh check failed: $*" >&2; exit 1; }
for f in krita zoom brave firefox libreoffice bottles; do
    grep -q '^\[Flatpak Preinstall ' "/usr/share/flatpak/preinstall.d/$f.preinstall" || fail "$f.preinstall"
done
[[ -x /usr/lib/opt/google/chrome/google-chrome ]] || fail "chrome binary"
[[ -s /etc/opt/chrome/policies/managed/necd.json ]] || fail "chrome managed policy"
[[ -x /usr/libexec/necd/set-defaults ]] || fail "set-defaults script"
[[ -e "/etc/skel/.config/google-chrome/First Run" ]] || fail "chrome first-run sentinel in /etc/skel"
[[ -f /usr/share/ublue-os/user-setup.hooks.d/50-necd-defaults.sh ]] || fail "first-login defaults hook"
# Dangling until boot: the target is /opt/google (tmpfiles relinks it), so test the link, not what it points to.
[[ -L /usr/bin/google-chrome ]] || fail "/usr/bin/google-chrome"
[[ -f /usr/share/applications/google-chrome.desktop ]] || fail "chrome desktop file"
ls /usr/share/icons/hicolor/*/apps/google-chrome.png >/dev/null 2>&1 || fail "chrome icon"
grep -q '^L+ /var/opt/google ' /usr/lib/tmpfiles.d/necdos-google-chrome.conf || fail "tmpfiles snippet"
[[ ! -e "$(realpath /opt)/google" ]] || fail "/opt/google not relocated"
for t in http https; do
    grep -qx "x-scheme-handler/$t=google-chrome.desktop" /usr/share/applications/mimeapps.list || fail "default browser $t"
    grep -qx "x-scheme-handler/$t=google-chrome.desktop" /usr/share/applications/kde-mimeapps.list || fail "KDE default browser $t"
done

# Taskbar and launchers for the practice apps.
for f in /usr/share/applications/necd-carestack.desktop /usr/share/applications/necd-iris.desktop \
         /usr/share/icons/hicolor/64x64/apps/necd-carestack.png /usr/share/icons/hicolor/64x64/apps/necd-iris.png; do
    [[ -s "$f" ]] || fail "$f"
done
grep -q 'applications:necd-carestack.desktop' /usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js || fail "taskbar layout"
grep -qx 'BrowserApplication=google-chrome.desktop' /etc/xdg/kdeglobals || fail "BrowserApplication"

# --- Software store: Discover instead of Aurora's Bazaar ---
# Aurora removes plasma-discover; NECD OS wants the simpler store. Flatpak backend only: OS updates
# come from the image, so no rpm-ostree/PackageKit update backends.
dnf5 install -y --setopt=install_weak_deps=False plasma-discover plasma-discover-libs plasma-discover-flatpak
# Aurora removes the appstream KRunner plugin (KDE bug 523540); keep it removed.
rm -f /usr/lib64/qt6/plugins/kf6/krunner/krunner_appstream.so
# Do not install Bazaar for new users; open .flatpakref files with Discover.
rm -f /usr/share/flatpak/preinstall.d/bazaar.preinstall
XDG_CONFIG_HOME=/usr/share/applications xdg-mime default org.kde.discover.desktop application/vnd.flatpak.ref
[[ -f /usr/share/applications/org.kde.discover.desktop ]] || fail "discover desktop file"
[[ ! -e /usr/share/flatpak/preinstall.d/bazaar.preinstall ]] || fail "bazaar preinstall still present"
grep -qx 'application/vnd.flatpak.ref=org.kde.discover.desktop' /usr/share/applications/mimeapps.list || fail "flatpakref default"
grep -q 'applications:org.kde.discover.desktop' /usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js || fail "taskbar discover pin"

# --- Sunshine (game-streaming host) is not wanted on NECD OS ---
dnf5 -y remove Sunshine
rm -f /usr/lib/systemd/user-preset/89-aurora-sunshine.preset
if rpm -q Sunshine >/dev/null 2>&1; then fail "Sunshine still installed"; fi

# --- Arial / Times New Roman: fetched per computer by `ujust install-ms-fonts` (not redistributable) ---
dnf5 install -y --setopt=install_weak_deps=False cabextract
command -v cabextract >/dev/null || fail "cabextract"
ujust --summary | tr ' ' '\n' | grep -qx install-ms-fonts || fail "install-ms-fonts recipe"

# --- KDE apps Aurora only offers through `ujust install-system-flatpaks`, which nothing here runs ---
# RPMs, so they need no network at first boot. KCalc is renamed to "Calculator" in build.sh.
dnf5 install -y --setopt=install_weak_deps=False okular gwenview kcalc haruna skanpage kclock kweather kontact qrca
for d in okularApplication_pdf org.kde.okular org.kde.gwenview org.kde.kcalc org.kde.haruna org.kde.skanpage \
         org.kde.kclock org.kde.kweather org.kde.kontact org.kde.qrca; do
    [[ -f /usr/share/applications/$d.desktop ]] || fail "$d desktop file"
done
