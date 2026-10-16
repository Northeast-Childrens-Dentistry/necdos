# First NECD OS foundation build

This stage proves that a minimal NECD layer can be built on Aurora stable. It does not install the approved browser/app/font suite yet, and is not ready for practice deployment.

## Contents

- Base: ghcr.io/ublue-os/aurora:stable, pinned by digest in Containerfile (Renovate bumps it after a 5-day soak).
- Name: necdos; stable, stable-<date>, testing-* and candidate-* tags (see README).
- Identity: /usr/share/necdos/release.json, with ready_for_practice=false.
- Preserve Aurora packages, services and OS identity. Remove inherited example tmux installation and Podman socket enablement.
- Retain bootc container lint. Mark image metadata as prerelease.

## Build validation

The pull-request workflow runs Just syntax checks, builds the container, runs the Containerfile bootc lint and rechunks the result. Pull requests do not log into GHCR, push or sign. Review the actual Actions result; a submitted workflow is not a successful build.

For a local Aurora development environment with Podman and Just:

```bash
just check
bash -n build_files/build.sh
just build necdos candidate
podman run --rm --entrypoint /usr/bin/cat localhost/necdos:candidate /usr/share/necdos/release.json
```

These commands build/inspect a container only. They do not install or switch the workstation OS. A successful build/lint is not proof that the image boots.

## Publication and signing

Automatic builds, promotion and signing are described in the README ("How updates reach the clinic"). Signing secrets live in the release (main only) and candidate (approval required) GitHub environments; pull requests never receive them. No signing key is committed.

A missing secret guard cannot validate whether a supplied key is correct. Before any installation, verify the signature against the actual published digest and check the client signature policy. Published candidate tags remain experimental.

The image package is public, so clients need no registry token. Integrity comes from the enforced cosign signature, not from privacy: never put a secret in the image. Secure Boot kernel trust is separate from OCI signing. Do not disable Secure Boot or image verification as a shortcut.

## Client signature policy

The image ships `/etc/pki/containers/necd.pub` (the cosign public key) and a `sigstoreSigned` entry for `ghcr.io/northeast-childrens-dentistry/necdos` in `/etc/containers/policy.json`, with `use-sigstore-attachments` set in `/etc/containers/registries.d/necdos.yaml`. The policy is only applied when the machine pulls the image through the signed transport. Switch with:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/northeast-childrens-dentistry/necdos:candidate
```

A plain `bootc switch` (without the flag) does not verify signatures. After a signed switch, `bootc status` and the terminal image line show the lock. Negative test: switching with the flag to an unsigned digest must be refused.

## Remaining acceptance gates for issue #3

- [ ] Successful candidate CI container build/lint/rechunk.
- [ ] Signing configuration, public key and client signature policy reviewed and tested.
- [ ] Published candidate signature verifies against its digest.
- [ ] VM boots to KDE, including reboot and kernel/desktop checks.

Only after these gates is the foundation ready for further app customization. The pilot PC inventory remains in docs/requirements.md; no disk changes are part of this stage.
