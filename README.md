# NECD OS

An Aurora-based workstation image for Northeast Children’s Dentistry and a precursor to CarestackOS.

**Status: planning and template scaffolding. No validated NECD OS release is available yet.** The copied template build configuration has not yet been converted to Aurora or configured for signed NECD releases.

[Project board](https://github.com/orgs/Northeast-Childrens-Dentistry/projects/2) · [Implementation issues](https://github.com/Northeast-Childrens-Dentistry/necdos/issues)

## Architecture and updates

Keep a small customization layer on Aurora stable using the Universal Blue image template. No full Aurora fork or routine upstream source merges. Standard and, if needed for reversible personal tooling, DX variants share the same NECD layer.

The planned pipeline checks upstream stable image digests daily, rebuilds on base/configuration changes, records provenance, validates/signs candidates and promotes only successful builds. Clients stage NECD image updates automatically and activate them at normal reboot. A failed build retains the last working release. Rollback, stale-build monitoring and a durable scheduled trigger are implementation requirements.

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

## Upstream references

- [Aurora](https://github.com/ublue-os/aurora) and [documentation](https://docs.getaurora.dev/)
- [Universal Blue image template](https://github.com/ublue-os/image-template)
- [Bazzite Waydroid integration reference](https://github.com/ublue-os/bazzite)

This repository was generated from the Universal Blue image template. Its Apache-2.0 license is retained; third-party software/font assets retain their own terms.
