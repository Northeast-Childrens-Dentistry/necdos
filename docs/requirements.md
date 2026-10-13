# NECD OS requirements — v0.2

Recorded October 13, 2026. Implements the planning portion of [issue #1](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/1). This document is a requirements manifest, not an installer or proof of compatibility.

## Shared application manifest

| Item | Required behavior | Delivery decision / validation owner |
| --- | --- | --- |
| Google Chrome | Installed, default browser, default HTTP/HTTPS handler for new users | Choose supported package channel and validate launchers in #5 |
| Firefox | Installed alternative browser | Preserve upstream delivery where present; verify in #5 |
| Brave | Installed alternative browser | Prefer Flatpak if workflow testing passes; #5 |
| Krita | Installed by default on every NECD OS workstation; survives personal cleanup | Flatpak preferred; package identity and updates validated in #7 |
| Teams for Linux | Installed by default on every NECD OS workstation; survives personal cleanup | Unofficial third-party client (Flatpak `com.github.IsmaelMartinez.teams_for_linux`, GPL-3.0); Microsoft ships no official Linux desktop client. Verify sign-in, calls, screen sharing and updates in #7 |
| Zoom | Installed by default on every NECD OS workstation; survives personal cleanup | Flatpak `us.zoom.Zoom` (proprietary Zoom binary, community-maintained wrapper, not verified by Zoom). Verify meetings, audio/video, screen sharing under Wayland and updates in #7 |
| CareStack | Distinct Chrome app window/menu entry using supplied icon | https://necdsa.carestack.com; #6 |
| Iris chat | Distinct Chrome app window/menu entry using supplied icon | http://iris-mw.carestack.com/?; inspect redirect/HTTPS behavior before changing destination; #6 |
| Waydroid | Host runtime included, documented per-device Android initialization | Audit compatible Bazzite integration, kernel/binder, graphics, services and networking; #8 |
| Aurora desktop utilities | Retain normal upstream KDE/desktop utilities | Inventory at build time; avoid duplicate installations; #7 |
| Windows 11 fonts | Include requested Windows 11 set through an authorized distribution/provisioning route | Exact font inventory, pinned source and asset terms in #12 |
| NECD fonts | Include NECD website font families | Source commit pinned below; desktop format and font names verified in #12 |
| Apple emoji | Default emoji family where supported; retain glyph fallback | Linux font plus dedicated fontconfig preference; KDE/Qt and browser testing in #12 |

The requested shared scope is the list above. Kevin confirmed Krita as a missing default app on October 13, 2026, and added Teams for Linux and Zoom the same day. This is a living manifest: future shared app additions go here and into #7, and are delivered by the normal NECD update/provisioning path. Personal-only additions go into the kevcops manifest and retain reversible installation tracking. Extra 3D imaging/design applications are excluded from the shared image. MeshLab is an explicit personal-only exception. No Google Play/GApps requirement has been specified for Waydroid. This does not remove Aurora base applications without a separate approved need.

Supplied icon filenames from the prior work: CS.ico, image.png and 64.png. Inspect bytes and associate each with its correct application before importing; filenames alone are not enough.

## Font sources

- Windows 11 directory: https://github.com/pjobson/Microsoft-Fonts/tree/main/2021%20-%20Windows%2011
- NECD assets at commit bfef04932e0a8c7de02b8ffad618395942af1bb4: https://github.com/Northeast-Childrens-Dentistry/wp-theme/tree/bfef04932e0a8c7de02b8ffad618395942af1bb4/assets/fonts
- Apple emoji Linux build: https://github.com/samuelngs/apple-emoji-ttf

Font families and package assets are not yet enumerated. Issue #12 owns inventory, format compatibility, hashes and font asset distribution terms. Repository code licensing is not evidence of permission to redistribute proprietary font assets. Shared fonts must persist when removekevcops runs.

## Personal setup manifest

| Item | Activation | Reversal |
| --- | --- | --- |
| Aurora developer tools | Enabled by ujust kevcops; reproduce current upstream DX capabilities through a verified architecture | Remove command-owned tools or stage standard NECD deployment if full DX was used |
| figma-linux-next | Install via the selected maintained project distribution; verify local fonts | Remove command-owned app/launcher; preserve personal settings |
| NordVPN | Install and integrate actual host VPN client/daemon through an Aurora-compatible mechanism | Stop personal services, restore previous networking and reverse owned installation/settings |
| MeshLab | Install as a Flatpak | Remove only if installed by kevcops; preserve preexisting installation and user data |

Current upstream DX capability inventory to verify in #9: VS Code/devcontainers, Docker/Compose, Podman/Desktop, QEMU/KVM/virt-manager, Incus, Cockpit and diagnostics. Exact packages/versions follow the selected upstream image; this document does not hardcode stale package versions.

### Living command contract

1. Kevin can update the trusted personal manifest/script in this repository and invoke ujust kevcops to apply its current verified revision. Routine personal app additions should not require a complete NECD OS rebuild.
2. Report the applied revision and retain the last working offline copy. Validate updates before executing them. Interrupted runs are recoverable and repeated invocations are harmless.
3. Maintain a persistent ledger of installations and changed settings, including what existed before activation. Reconcile additions/removals across revisions; use the installed ledger during removal even if a new script drops old items.
4. ujust removekevcops reverses command-owned installations and settings, preserving preexisting resources, projects, personal app settings and authentication data by default. This is an installation cleanup, not a user-data wipe.
5. Poweroff/restart automatically runs the same removal backend. Suspend/hibernate do not trigger cleanup. The next normal boot should be clean NECD OS, and personal apps are not automatically reinstalled until kevcops is invoked again.
6. Use bounded noninteractive shutdown cleanup with correct service/filesystem ordering and a persistent pending marker. Recover incomplete cleanup at startup after forced shutdown or power loss.
7. Full DX image changes and host VPN packages may require reboot/deployment transitions. Resolve activation/removal behavior before promising same-session full-DX toggles or an unconditional clean boot after every power failure.

Implementation owners: #9 (developer architecture), #10 (living install/removal), #11 (shutdown/recovery). Shared apps, fonts and Waydroid survive personal cleanup.

## Update and deployment requirements

- Build a small NECD layer on Aurora stable using the Universal Blue image template; no routine full-Aurora source-fork merges.
- Track upstream image digest changes automatically, rebuild, validate, sign and promote successful candidates. Record exact digests for provenance.
- Clients retain automatic staging and activate OS updates at normal reboot. No forced reboot during clinical work.
- Failed builds leave last working published images intact. Verify rollback and stale-build detection.
- Prefer GUI applications through supported upstream/Flatpak delivery. Host-integrated components such as Waydroid/NordVPN require their own tested integration.
- Start with a spare pilot workstation. Clinical workflow and peripheral compatibility must pass before practice rollout.

## Proposed pilot PC

Source: Kevin’s Windows hardware screenshot, October 13, 2026. These are observed specs, not an on-device hardware audit.

| Attribute | Observed | Verification status |
| --- | --- | --- |
| Processor | Intel Core i3-7100 @ 3.90 GHz | Model visible; two-core CPU per Intel specification; below Aurora listed quad-core baseline |
| Installed RAM | 8 GB at 2400 MHz | Visible; RAM upgrade optional depending on pilot workload results |
| Graphics | Intel HD Graphics 630 | Visible; Linux graphics/Vulkan and Waydroid behavior require testing |
| Drive capacity | 233 GB reported | Visible |
| Space in current Windows install | 156 GB used; approximately 77 GB free | Screenshot snapshot, not guaranteed future free space |
| Drive technology | Unknown | Confirm SSD versus HDD |
| PC make/model | Unknown | Needed for firmware, network and upgrade details |
| Firmware boot mode | Unknown | Confirm UEFI; current Aurora requires UEFI |
| Ethernet/Wi-Fi adapter | Unknown | Identify/test during pilot |
| Required peripherals | Unknown | Kevin to identify printer/scanner/camera/card reader or confirm none |

Aurora’s current documentation lists x86_64, UEFI, a 2 GHz quad-core CPU, 4 GB RAM (8 GB recommended), Vulkan 1.3+ graphics and an SSD with at least 40 GB free. The i3-7100 has only two physical cores. Basic browser use may be practical, but the machine is not established as fully meeting the listed specifications, and simultaneous Waydroid/developer/graphics workloads require actual performance testing.

Sources: https://docs.getaurora.dev/guides/system-requirements/ and https://www.intel.com/content/www/us/en/ark/products/series/95545/7th-generation-intel-core-i3-processors.html

### Hardware inventory checklist

- [x] Record screenshot CPU, RAM, GPU and storage figures.
- [ ] Record PC make/model.
- [ ] Confirm SSD/HDD.
- [ ] Confirm UEFI boot mode and record Secure Boot state (do not change it during inventory).
- [ ] Identify required peripherals or record that none are needed for this pilot.

On Windows, open System Information with Win+R → msinfo32 to find System Manufacturer, System Model and BIOS Mode. Task Manager → Performance → Disk usually reports SSD/HDD. Send only these hardware fields; a full system export is unnecessary.

### Pilot validation checklist — execution belongs to #13

- [ ] Boot Aurora/NECD candidate on this PC and check desktop graphics, resolution and display outputs.
- [ ] Validate Ethernet/Wi-Fi, audio, camera and every required peripheral.
- [ ] Test CareStack/Iris authentication, printing, downloads and normal browser workload.
- [ ] Test Waydroid startup/network/graphics and RAM pressure.
- [ ] Exercise kevcops activation, removal, normal shutdown cleanup and interrupted-cleanup recovery.
- [ ] Measure usability with personal developer/Figma/MeshLab workloads; document limits.
- [ ] Verify signed update, reboot and rollback.

## Step 01 completion boundary

Application and personal command requirements are recorded. Known pilot specs are recorded. Step 01 remains In Progress until the missing hardware inventory fields above are supplied or explicitly designated for later verification. No installation, destructive disk change or OS switch is authorized by this requirements capture alone.
