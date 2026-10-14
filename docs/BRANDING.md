# Branding guide

Every place this repository carries the NECD OS brand, and how to swap it. Written for a human or an AI agent rebranding the image (for example NECD OS → CarestackOS, or a fork for another organization). Follow "Quick pass", then run "Verify".

Describes `main` after PRs #20 (branding), #21 (boot splash) and #22 (identity/trust) are merged.

## Quick pass (agent instructions)

1. Collect the **inputs** below from the human. Do not invent names, URLs or artwork.
2. Replace the **variables** everywhere in the **touchpoint inventory**; the inventory lists every file. Regenerate generated assets with the listed scripts, never by hand.
3. Do **not** change anything under "Intentionally upstream".
4. Generate a **new cosign key pair** for the new brand (never reuse another organization's key) and update the key files and secrets listed under Trust.
5. Run **Verify**. Build, then boot the image in a VM and check the visual list.

### Inputs the human must supply

| Input | NECD value | Used for |
| --- | --- | --- |
| Display name | `NECD OS` | os-release, Welcome app, About page, MOTD, theme names |
| Image name | `necdos` | registry path, image-info, hostname default |
| GitHub organization | `Northeast-Childrens-Dentistry` | registry path, ISO config, policy |
| Hostname default | `necdos` | os-release |
| Logo badge (stacked/square) | `branding/necd-badge.png` | launcher, About, login splash, terminal logo |
| Logo wordmark (wide) | `branding/necd-wordmark.png` | boot splash, banner |
| Wallpapers | 10 images, 1920x1080 (3840x2160 preferred) | desktop, lock/login, first-boot setup |
| Which wallpaper is default / lock | #4 desktop, #10 lock | see Wallpapers |
| Accent background color | cream `#fffbf3` | boot splash |
| Support / home URL (optional) | none | os-release (currently removed) |

## Touchpoint inventory

### 1. Image identity and registry
| File | What to change |
| --- | --- |
| `image-template.env` | `IMAGE_NAME`, `REPO_ORGANIZATION`, `IMAGE_DESC`, `IMAGE_KEYWORDS`, `IMAGE_LOGO_URL`, `DEFAULT_TAG` |
| `build_files/build.sh` | os-release `sed` block (`NAME`, `PRETTY_NAME`, `DEFAULT_HOSTNAME`, `CPE_NAME`, `LOGO`); `image-info.json` `jq` block (name, vendor, ref, tag); `release.json` text; end-of-file check lines that grep the name |
| `disk_config/iso-kde.toml`, `disk_config/disk.toml` | `bootc switch ... ghcr.io/<org>/<image>:candidate` |
| `.github/workflows/build-disk.yml` | `DEFAULT_TAG` (image name comes from the repository name) |
| Repository name | `IMAGE_NAME` in the workflows is the repo name; keep it equal to `IMAGE_NAME` above |

### 2. Trust (signing) — new key per brand
| File / secret | What to do |
| --- | --- |
| `cosign.pub` and `system_files/etc/pki/containers/necd.pub` | replace both with the new public key (rename `necd.pub`, and update the `keyPath` in `build.sh`) |
| `system_files/etc/containers/registries.d/necdos.yaml` | rename file; update the `ghcr.io/<org>/<image>` key |
| `build_files/build.sh` (policy `python3` block and final `jq` check) | update the `ghcr.io/<org>/<image>` string |
| GitHub secrets `SIGNING_SECRET`, `COSIGN_PASSWORD` | set from the new private key; never commit `cosign.key` |

### 3. Wallpapers, lock screen, first-boot
| File | What to change |
| --- | --- |
| `system_files/usr/share/wallpapers/NECD-<Name>/` (one per image: `metadata.json` + `contents/images/1920x1080.png`) | replace with the new set; `Id`/`Name` in `metadata.json` |
| `system_files/usr/share/wallpapers/Aurora/` | **folder name must stay `Aurora`** (first-boot setup hard-codes it). Replace the contents with the default wallpaper: `3840x2160.jxl`, `1440x2960.png` (portrait, padded with the accent color), `1920x1080.png`; set `Name` in `metadata.json` |
| `system_files/usr/share/backgrounds/default.jxl`, `default-dark.jxl` | default wallpaper as JXL (`magick in.png out.jxl`) |
| `system_files/usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/plasmoidsetupscripts/org.kde.plasma.folder.js` | path of the new-user default wallpaper |
| `system_files/usr/share/kde-settings/kde-profile/default/xdg/kscreenlockerrc`, `system_files/usr/lib/plasmalogin/defaults.conf` | lock screen and login wallpaper (`Image=`, `PreviewImage=`) |
| `build_files/build.sh` (first block) | wallpaper folder names removed/checked |

Defaults apply to **new users only**; existing home directories keep their settings.

### 4. Logos and icons
Sources in `branding/`: `necd-badge.png` (square-ish stacked logo), `necd-wordmark.png` (wide logo). Both must be flat-color with transparency.

| Step | Command |
| --- | --- |
| Regenerate all SVG/PNG variants into `system_files/usr/share/necdos/branding/` | `python3 branding/make-assets.py` (needs `python3-pillow`, `potrace`, `rsvg-convert`) |
| Regenerate `system-logo.png` / `system-logo-white.png` (256 px) | `rsvg-convert -w 256 -h 256 system_files/usr/share/necdos/branding/logo.svg -o .../system-logo.png` (and `logo-white.svg`) |
| Login splash logo | `gzip -9nc .../branding/logo.svg > system_files/usr/share/plasma/look-and-feel/dev.getaurora.{aurora,auroralight}.desktop/contents/splash/images/aurora_logo.svgz` |
| Boot splash image | `rsvg-convert -w 1200 .../branding/wordmark.svg -o system_files/usr/share/plymouth/themes/necd/logo.png` |
| Terminal logo | `python3 branding/make-ansi-logo.py branding/necd-badge.png system_files/usr/share/necdos/logo.ans` |

`build.sh` copies the logo SVGs over every Aurora `distributor-logo*`, `start-here*` and `auroralogo-*` icon in all icon themes, and over `/usr/share/pixmaps/system-logo*.png` and `aurora-banner.svg`. The launcher button icon is set in `.../plasmoidsetupscripts/org.kde.plasma.kickoff.js`.

### 5. Boot splash (Plymouth)
`system_files/usr/share/plymouth/themes/necd/` (`necd.plymouth`, `necd.script`, `logo.png`). Rename the theme folder and files, update `ScriptFile`/`ImageDir`, background color constants in `necd.script`, and the `plymouth-set-default-theme necd` line plus its checks in `build.sh`. The initramfs is rebuilt there: a mistake can stop boot, so test in a VM.

### 6. Names and text users see
| File | What to change |
| --- | --- |
| `system_files/usr/share/plasma/look-and-feel/dev.getaurora.{aurora,auroralight}.desktop/metadata.json` | `Name`, `Description`, `Authors` (keep `Id`) |
| `system_files/usr/share/plasma/plasma-welcome/intro-customization.desktop` | `Name`, optional `Comment`/`URL` |
| `system_files/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | `Name`, optional `Website` |
| `system_files/usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc` | pinned taskbar apps |
| `system_files/usr/share/ublue-os/motd/template.md` | terminal banner |
| `system_files/usr/share/applications/dev.getaurora.system-update.desktop` | launcher text |
| `system_files/etc/xdg/fastfetch/config.jsonc`, `system_files/usr/bin/ublue-fastfetch` | fastfetch logo config; the wrapper stops upstream forcing its own config |
| `system_files/usr/share/ublue-os/just/00-entry.just` | custom `ujust` overrides (see README) |

### 7. Documentation
`README.md`, `docs/requirements.md` (requirements and org-specific values), `docs/first-build.md`, this file. Update names, URLs, board links.

### 8. Organization-specific content (not branding, but must change)
`docs/requirements.md` and the README name the practice's URLs (CareStack/Iris), fonts (NECD fonts from the wp-theme repo), office printers/scanners, and pilot hardware. Replace or remove them for another organization.

## Intentionally upstream (do not rename)
- `Containerfile` `FROM ghcr.io/ublue-os/aurora:stable` and the Renovate rule naming it: Aurora is the base image.
- `ID`, `VARIANT_ID`, `IMAGE_ID` in os-release stay `aurora`, and `ID_LIKE="fedora"`: upstream tooling keys on them. Change only after testing in a VM.
- Look-and-feel IDs `dev.getaurora.aurora.desktop` / `dev.getaurora.auroralight.desktop` (display names are changed, IDs are referenced by upstream's first-boot scripts), and the `Aurora` wallpaper folder name.
- Aurora's `/usr/share/licenses` and package names: license notices must stay. Keep one credit line ("based on Aurora") in the README.

## Verify
Leak scan: list every remaining mention of the old brand. Expected hits are only the "Intentionally upstream" items, history in `docs/`, and PNG/SVG art.
```bash
grep -rIn -i -E 'necd|northeast|carestack|aurora' --exclude-dir=.git . | grep -v -E 'dev\.getaurora|ublue-os/aurora|^./docs/(first-build|requirements)\.md'
```
After building (`build.sh` also fails the build if key files are missing):
```bash
podman run --rm --entrypoint bash <image> -c 'cat /etc/os-release; cat /usr/share/ublue-os/image-info.json; jq .transports.docker /etc/containers/policy.json'
```
Boot in a VM with a **new user** and check: first-boot setup wallpaper, desktop wallpaper, lock screen, login screen, launcher icon, Settings → About, Welcome app, terminal banner and `fastfetch`, boot splash, `ujust` list, and a signed `bootc switch --enforce-container-sigpolicy`.
