# NECD OS

An Aurora-based workstation image for Northeast Children’s Dentistry and a precursor to CarestackOS.

**Status: pilot build.** The image builds on Aurora stable, is signed, and includes the NECD app set (CareStack and Iris windows, Chrome defaults, shortcuts) and the fonts recipe. Automatic stable promotion and overnight updates ([#4](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/4)) are not active yet, and it has not been validated for practice rollout.

[Project board](https://github.com/orgs/Northeast-Childrens-Dentistry/projects/2) · [Implementation issues](https://github.com/Northeast-Childrens-Dentistry/necdos/issues)

## Architecture and updates

Keep a small customization layer on Aurora stable using the Universal Blue image template. No full Aurora fork or routine upstream source merges. Standard and, if needed for reversible personal tooling, DX variants share the same NECD layer.

The planned pipeline checks upstream stable image digests daily, rebuilds on base/configuration changes, records provenance, validates/signs candidates and promotes only successful builds. Clients stage NECD image updates automatically and activate them at normal reboot. A failed build retains the last working release. Rollback, stale-build monitoring and a durable scheduled trigger are implementation requirements.

## System requirements

NECD OS inherits [Aurora's requirements](https://docs.getaurora.dev/guides/system-requirements):

- x86_64 (Intel/AMD) CPU, 2 GHz quad core or better
- UEFI firmware (CSM/Legacy boot will not work)
- 4 GB RAM minimum, 8 GB or more recommended
- SSD with at least 40 GB free for updates (an HDD works but updates are slow)

The pilot PC (Intel Core i3-7100, 8 GB RAM) is below the CPU baseline and its UEFI and SSD status is unconfirmed; see [#1](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/1).

## Shared workstation requirements

- Google Chrome installed and default; Firefox and Brave installed options.
- CareStack Chrome app window: https://necdsa.carestack.com with supplied icons.
- Iris Chrome app window: http://iris-mw.carestack.com/?; verify HTTPS/redirect behavior before changing destination.
- Waydroid included using compatible integration audited from Bazzite.
- Windows 11 fonts from the requested pjobson/Microsoft-Fonts directory, NECD fonts from wp-theme, and Apple emoji as the default emoji font with fallback. See issue #12 for exact sources and font distribution/rendering checks.
- Normal Aurora desktop utilities retained. No extra shared 3D imaging/design suite.

## Living personal setup

`ujust kevcops` will apply the current trusted personal configuration: Aurora developer tools, figma-linux-next, NordVPN and MeshLab Flatpak. The entry point should obtain a verified versioned setup without waiting for an OS rebuild for every personal change.

`ujust removekevcops` will reverse command-owned installations and settings using a persistent ledger, preserving preexisting resources, projects and personal settings/data. Removal is run manually; there is no automatic cleanup on shutdown.

`ujust powerwash` is the factory reset: administrators (wheel group) only, requires the administrator password and typing the computer name, then erases all users' data and settings (everything under /var/home) while keeping the NECD OS image. Restart to finish.

Full DX and host VPN integration may require deployment/reboot transitions. Resolve these in issues #9–10 before promising immediate toggles. Shared fonts/apps remain after personal cleanup.

## Administrator setup

**Name each computer.** NECD OS does not ship a fixed hostname, so a new install shows a generic name (`aurora`). Give every PC its own name, for example one that identifies the room, so it can be told apart on the network:

```bash
sudo hostnamectl set-hostname necd-<room>   # e.g. necd-front-desk
hostnamectl                                  # confirm "Static hostname"
```

`ujust powerwash` asks for this name, so set it first. Reboot or log out and in to see it everywhere.

## Immutable system

NECD OS is an image-based (bootc/ostree) system, not a package-by-package install. `/usr` is read-only and is replaced as a whole by each update; `/etc` and `/var` (including every home under `/var/home`) are writable and carry over between versions. Consequences for admins:

- Don't `dnf install` or edit files under `/usr` on a clinic PC. Changes either fail or vanish on the next image. Put system-wide changes in this repo (`system_files/` or `build_files/build.sh`); put apps in Flatpak.
- Every update is a complete, signed image. A machine is on exactly one version, so two PCs on the same tag are identical.
- The previous image stays on disk next to the new one, which is what makes rollback safe.

Check what a machine is running: `sudo bootc status` (booted, staged and rollback images, with digests).

## How updates work

> **Planned, not active yet.** The `stable`/`testing` promotion, dated `stable-YYYYMMDD` tags and overnight reboot below are the design in [#4](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/4), which has not merged. Today there is no `stable` tag; see the workflow runs and tags on GitHub for what is actually published.

1. The build pipeline rebuilds when Aurora stable or this repo changes, then signs the image and publishes it as `ghcr.io/northeast-childrens-dentistry/necdos`.
2. Only an image that passes the build, signature and boot checks is promoted to the `stable` tag. Clinic PCs follow `stable`. Dated tags `stable-YYYYMMDD` are kept as rollback points.
3. Aurora's updater downloads the new image in the background and **stages** it. Nothing changes for the running session.
4. The staged image takes effect at the next reboot. Planned: an overnight (02:00) reboot, only when nobody is logged in.
5. If a build fails, `stable` doesn't move and PCs stay on the last working release.

Images are signature-checked by the client against `cosign.pub`; a tag that isn't signed by the NECD key won't be accepted.

## Rolling back

> **Untested in a VM.** Rolling back to the previous image is standard bootc behavior, but these steps have not been verified on NECD OS. The `stable-YYYYMMDD` pinning part depends on [#4](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/4) (planned, not active yet).

Reboot into the previous image. Per-user data and settings are untouched.

```bash
sudo bootc status          # confirm a rollback image exists
sudo bootc rollback        # makes the previous image the next boot
systemctl reboot
```

You can also pick the previous entry in the boot menu (GRUB) at startup for a one-off boot.

`bootc rollback` returns to the old image, but the machine will stage the bad `stable` again on its next update. To hold a machine on a known-good release until a fix ships, pin it to a dated tag:

```bash
sudo bootc switch ghcr.io/northeast-childrens-dentistry/necdos:stable-YYYYMMDD
systemctl reboot
```

Return to normal tracking with `sudo bootc switch ghcr.io/northeast-childrens-dentistry/necdos:stable`.

If many PCs are affected, fix the cause instead of rolling each one back: revert the commit on `main` and let the pipeline publish a new `stable`. Open an issue describing what broke either way.

## Remote access with Tailscale (for future admins)

> **Untested.** This is general Tailscale guidance; none of it has been verified on a NECD OS machine yet.

Tailscale is how an admin reaches a clinic PC without opening ports on the clinic network. Confirm it is present on the image with `rpm -q tailscale` and `systemctl status tailscaled` before relying on it; if it isn't, add it in `build_files/build.sh` and a build-time check, not by hand.

- **Join a machine:** `sudo tailscale up --ssh --hostname=necd-<room-or-name>`, then approve the login in the browser. For unattended setup, generate a **reusable, tagged auth key** in the Tailscale admin console and paste it on the machine. Never commit keys to this repo or bake them into the image.
- **Tag clinic PCs** (for example `tag:necd-clinic`) so their node keys don't expire and access is governed by ACLs, not by whichever person logged in. Keep admin devices on a separate tag and only allow admin → clinic SSH.
- **SSH:** with `--ssh`, use `tailscale ssh <hostname>`; no keys to distribute. Restrict who may do this in the tailnet's ACL.
- **Persistence:** Tailscale state lives in `/var/lib/tailscale`, so it survives updates and rollbacks. `ujust powerwash` only erases `/var/home`, so the machine stays on the tailnet. To remove a retired PC, delete it in the Tailscale admin console, and run `sudo tailscale logout` first if you can.
- **Debugging:** `tailscale status`, `tailscale netcheck`, `sudo journalctl -u tailscaled`.
- **Ownership:** keep at least two admins on the tailnet, and record who owns the Tailscale account and its auth-key rotation in the project docs so access isn't lost with one person.
- NordVPN (from `ujust kevcops`) can conflict with Tailscale routing. Keep it off clinic machines.

## Incremental roadmap

| Step | Issue |
| --- | --- |
| 01 — Confirm application manifest and pilot hardware | [#1](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/1) |
| 02 — Establish repository, roadmap and project documentation | [#2](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/2) |
| 03 — Prove minimal Aurora stable image and trusted delivery | [#3](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/3) |
| 04 — Automate Aurora tracking, validation and stable promotion | [#4](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/4) |
| 05 — Install Chrome, Firefox and Brave; default to Chrome | [#5](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/5) |
| 06 — Add CareStack and Iris Chrome app windows and icons | [#6](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/6) |
| 07 — Complete shared app provisioning and update paths | [#7](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/7) |
| 08 — Port and validate Bazzite Waydroid integration | [#8](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/8) |
| 09 — Prototype reversible Aurora developer tooling | [#9](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/9) |
| 10 — Implement living ujust kevcops and removekevcops | [#10](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/10) |
| 10b — Add shared Windows/NECD fonts and Apple emoji default | [#12](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/12) |
| 11 — Pilot installation, clinical workflows, updates and rollback | [#13](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/13) |
| 12 — Roll out NECD OS and isolate future CarestackOS profile | [#14](https://github.com/Northeast-Childrens-Dentistry/necdos/issues/14) |

Board workflow: Backlog → Ready → In Progress → Validation → Done; Blocked for unresolved requirements/access/architecture. Issue bodies contain phase, priority, variant, dependencies, task checklists and acceptance criteria.

Start with manifest/pilot hardware reconciliation (#1) and minimal trusted Aurora build (#3), then update automation (#4). Work is complete only after relevant validation passes.

## Documentation

[NECD OS docs](https://northeast-childrens-dentistry.github.io/necdos-docs/) are rebuilt daily from the Aurora docs ([necdos-docs](https://github.com/Northeast-Childrens-Dentistry/necdos-docs)). Staff open them from **NECD OS Help** in the app menu.

## Upstream references

- [Aurora](https://github.com/ublue-os/aurora) and [documentation](https://docs.getaurora.dev/)
- [Universal Blue image template](https://github.com/ublue-os/image-template)
- [Bazzite Waydroid integration reference](https://github.com/ublue-os/bazzite)

This repository was generated from the Universal Blue image template. Its Apache-2.0 license is retained; third-party software/font assets retain their own terms.
