# Automatic Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clinic PCs track a signed `stable` tag that follows Aurora stable after a 5-day soak, is promoted only after automated checks pass, and alerts the admin on failure or silence.

**Architecture:** The Aurora base is pinned by digest in `Containerfile`; Renovate bumps it after 5 days and automerges on a green PR build. Every push to `main` builds a `testing-*` image, signs it, verifies the signature, boot-tests it in QEMU, then retags the same digest as `stable-<date>` and `stable`. A daily heartbeat workflow checks staleness and pings healthchecks.io. Clients reboot into staged updates at 02:00 only when nobody is logged in.

**Tech Stack:** GitHub Actions, podman, skopeo, cosign v3.1.2 (key pair), bootc-image-builder, QEMU/KVM, Renovate, healthchecks.io, systemd timers, bash, jq.

**Spec:** https://github.com/Northeast-Childrens-Dentistry/necdos/issues/4#issuecomment-6174680195

## Global Constraints

- Tags: clinic PCs track `stable`; rollback points `stable-<YYYYMMDD>`; main builds publish `testing`, `testing-<date>`, `testing-<sha>`, `testing-<date>-<sha>`; feature dispatches publish `candidate*`. No other tag families.
- Promotion retags the same digest (`skopeo copy --preserve-digests`). Never rebuild to promote.
- Nothing secret ever goes in the image (the package becomes public).
- Soak: `minimumReleaseAge: "5 days"` on Aurora digest bumps. Own merges to `main` promote without soak.
- Gates, all required before `stable` moves: build + `bootc container lint` + identity assertions (`build_files/build.sh`); `cosign verify` of the pushed digest against `cosign.pub`; QEMU boot test reaching Graphical Interface with no failed units.
- A failure at any gate leaves `stable` and `stable-*` untouched.
- Signing: keep the cosign key pair, existing sign flags (`--new-bundle-format=false --use-signing-config=false`), cosign `v3.1.2`. Secrets live in GitHub environments `release` (branch `main` only) and `candidate` (any branch, required reviewer kevcops).
- **Every signing, key, secret or trust-policy step is done with the admin, one step at a time: explain, run, verify, before the next.**
- Client reboot: 02:00 local, only when an update is staged AND no `user`-class login session exists. On by default. `Persistent=` stays off.
- Alerting: failure issue label `update-failure` (opened/closed by build runs); staleness issue label `update-stale` (opened/closed by heartbeat) when `stable` lags an Aurora digest that is ≥19 days old (5 soak + 14 grace); healthchecks.io check with 1-day period, 1-day grace.
- Actions stay pinned by commit SHA; runners stay `ubuntu-26.04`.

## Review Focus

1. `bootc status` or `loginctl` fails on a client at 02:00 → the machine must not reboot (Task 5 test `bootc-error`).
2. Staff leave a session logged in (locked) overnight → no reboot, update waits for the next manual restart. Known ceiling; marked with a `ponytail:` comment and stated in README (Task 5 test `user-session`).
3. Machine is powered off at 02:00 → the timer must not fire at the next morning's boot (Task 5 build assertion on `Persistent`).
4. Heartbeat runs before any labeled `stable` exists → it must skip staleness and still ping healthchecks.io (Task 7 step 4).
5. Aurora `:stable` is a manifest list → staleness must compare the top-level digest (`skopeo inspect --raw | sha256sum`), not the per-platform digest, or it false-alarms daily (Task 7 step 4).

---

## Merge points

Work on branch `feat/auto-updates`. Tasks 1, 2 and 4-step-1 are GitHub settings (no code). Merge PR A after Task 5 (image changes; no automatic build yet). Merge PR B after Task 7 (workflows; **this merge itself triggers the first automatic `stable` promotion**). PR C after Task 9 (docs).

---

### Task 1: Make the package public (guided)

**Files:**
- Modify: `docs/first-build.md` (paragraph starting "Private GHCR pull access")

**Interfaces:**
- Produces: the exact working `cosign verify` command line, used verbatim in Task 6 step 6 and Task 8.

- [ ] **Step 1: Check the org allows public packages**

GitHub → Organization *Northeast-Childrens-Dentistry* → Settings → Packages → "Package creation": **Public** must be ticked. Admin ticks it if not.

- [ ] **Step 2: Change visibility**

GitHub → Organization → Packages → `necdos` → Package settings → Danger Zone → Change visibility → **Public** → type `necdos` to confirm.

- [ ] **Step 3: Verify anonymous pull works**

```bash
curl -s "https://ghcr.io/token?scope=repository:northeast-childrens-dentistry/necdos:pull" | jq -r '.token | length > 0'
```
Expected: `true` (a private package returns an error object instead).

- [ ] **Step 4: Verify the signature anonymously and lock in the verify command**

```bash
DOCKER_CONFIG=$(mktemp -d) cosign verify --key cosign.pub --new-bundle-format=false \
  ghcr.io/northeast-childrens-dentistry/necdos:candidate
```
Expected: `The cosign claims were validated` and JSON. If cosign reports `unknown flag: --new-bundle-format`, re-run without that flag. Record whichever form succeeds; it is THE verify command for Task 6 and Task 8.

- [ ] **Step 5: Update docs**

In `docs/first-build.md`, replace the paragraph
`Private GHCR pull access must be resolved for the pilot before installing. Secure Boot kernel trust is separate from OCI signing. Do not disable Secure Boot or image verification as a shortcut.`
with
`The image package is public, so clients need no registry token. Integrity comes from the enforced cosign signature, not from privacy: never put a secret in the image. Secure Boot kernel trust is separate from OCI signing. Do not disable Secure Boot or image verification as a shortcut.`

- [ ] **Step 6: Commit**

```bash
git add docs/first-build.md
git commit -m "docs: package is public; no client registry token"
```

---

### Task 2: Signing environments (guided)

**Files:** none (GitHub settings).

**Interfaces:**
- Produces: environments `release` and `candidate`, each with secrets `SIGNING_SECRET` and `COSIGN_PASSWORD`. Task 6 selects them per job.

- [ ] **Step 1: Locate the private key**

Admin confirms where the original `cosign.key` file and its password are kept (password manager / offline). Check it matches the repo public key:
```bash
cosign public-key --key /path/to/cosign.key | diff - cosign.pub && echo MATCH
```
Expected: `MATCH` (prompts for the password). **If the key is lost, STOP: this becomes a key rotation, done separately with the admin.**

- [ ] **Step 2: Create `release` (main only, no approval)**

```bash
R=repos/Northeast-Childrens-Dentistry/necdos
gh api -X PUT $R/environments/release --input - <<'JSON'
{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
JSON
gh api -X POST $R/environments/release/deployment-branch-policies -f name=main -f type=branch
```

- [ ] **Step 3: Create `candidate` (any branch, admin approves each run)**

```bash
ID=$(gh api users/kevcops --jq .id)
gh api -X PUT $R/environments/candidate --input - <<JSON
{"reviewers":[{"type":"User","id":$ID}],"prevent_self_review":false,"deployment_branch_policy":null}
JSON
```

- [ ] **Step 4: Add secrets to both environments**

```bash
for env in release candidate; do
  gh secret set SIGNING_SECRET --env $env < /path/to/cosign.key
  gh secret set COSIGN_PASSWORD --env $env   # paste password at the prompt
done
```

- [ ] **Step 5: Verify**

```bash
gh api $R/environments --jq '.environments[] | {name, rules: [.protection_rules[].type]}'
gh secret list --env release; gh secret list --env candidate
```
Expected: `release` has `branch_policy`; `candidate` has `required_reviewers`; both list `SIGNING_SECRET` and `COSIGN_PASSWORD`. Repo-level secrets stay until Task 6 step 11 proves the environments work.

---

### Task 3: Pin the base and record provenance and channel in the image

**Files:**
- Modify: `Containerfile` (base `FROM`, add ARGs/LABEL)
- Modify: `build_files/build.sh` (image-info tag, release.json, checks)
- Modify: `Justfile` (`build` recipe BUILD_ARGS)

**Interfaces:**
- Produces: image label `io.necdos.base-image` = full pinned ref `ghcr.io/ublue-os/aurora:stable@sha256:<digest>` (read by Task 7). `/usr/share/necdos/release.json` key `base` = same value. `image-info.json` `image-tag` = `stable` for main builds, `candidate` otherwise.

- [ ] **Step 1: Write the failing checks** — append to the "Identity and trust checks" block in `build_files/build.sh`:

```bash
[[ "$BASE_IMAGE" == ghcr.io/ublue-os/aurora:stable@sha256:* ]] || { echo "base not pinned: $BASE_IMAGE" >&2; exit 1; }
test "$(jq -r .base /usr/share/necdos/release.json)" = "$BASE_IMAGE"
test "$(jq -r '."image-tag"' /usr/share/ublue-os/image-info.json)" = "$IMAGE_TAG"
```

- [ ] **Step 2: Run to verify it fails**

```bash
bash -n build_files/build.sh && BASE_IMAGE= bash -c '[[ "$BASE_IMAGE" == ghcr.io/ublue-os/aurora:stable@sha256:* ]]' ; echo $?
```
Expected: `1` (unpinned base is rejected).

- [ ] **Step 3: Resolve the current Aurora digest**

```bash
TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:ublue-os/aurora:pull" | jq -r .token)
curl -sI -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json" \
  https://ghcr.io/v2/ublue-os/aurora/manifests/stable | grep -i '^docker-content-digest'
```
Expected: `docker-content-digest: sha256:<64 hex>`.

- [ ] **Step 4: Pin in `Containerfile`**

Add as the first line of the file (before `FROM scratch AS ctx`), using the digest from step 3:
```dockerfile
ARG BASE_IMAGE=ghcr.io/ublue-os/aurora:stable@sha256:<digest-from-step-3>
```
Replace `FROM ghcr.io/ublue-os/aurora:stable` with:
```dockerfile
FROM ${BASE_IMAGE}
ARG BASE_IMAGE
ARG IMAGE_TAG=candidate
LABEL io.necdos.base-image="${BASE_IMAGE}"
```

- [ ] **Step 5: Use the values in `build_files/build.sh`**

Replace the image-info jq call's `| ."image-tag"="candidate"'` line so the block reads:
```bash
jq --arg tag "$IMAGE_TAG" '."image-name"="necdos" | ."image-vendor"="northeast-childrens-dentistry"
    | ."image-ref"="ostree-image-signed:docker://ghcr.io/northeast-childrens-dentistry/necdos"
    | ."image-tag"=$tag' "$IMG" > /tmp/image-info.json
```
Replace the `cat > /usr/share/necdos/release.json <<'JSON' ... JSON` heredoc with:
```bash
jq -n --arg base "$BASE_IMAGE" '{name: "NECD OS", stage: "foundation", base: $base,
  ready_for_practice: false,
  requirements: "https://github.com/Northeast-Childrens-Dentistry/necdos/blob/main/docs/requirements.md"}' \
  > /usr/share/necdos/release.json
```

- [ ] **Step 6: Pass the channel from `Justfile`**

In the `build` recipe, after `BUILD_ARGS=()`:
```bash
    # main builds are pushed as testing and promoted to stable unchanged, so they carry the stable name.
    BUILD_ARGS+=("--build-arg" "IMAGE_TAG=${tag/testing/stable}")
```

- [ ] **Step 7: Verify locally**

```bash
bash -n build_files/build.sh && just check
```
Expected: no output from `bash -n`; `just check` passes. The full build runs in the PR (step 8).

- [ ] **Step 8: Commit and check the PR build**

```bash
git add Containerfile build_files/build.sh Justfile
git commit -m "feat: pin Aurora by digest; record base and channel in image"
git push -u origin feat/auto-updates && gh pr create --draft --fill && gh pr checks --watch
```
Expected: "Build and push image" passes (the build.sh checks ran inside it).

---

### Task 4: Renovate soak for Aurora digest bumps

**Files:**
- Modify: `.github/renovate.json5` (replace the `ghcr.io/ublue-os/aurora` packageRule)

**Interfaces:**
- Consumes: `ARG BASE_IMAGE=…@sha256:…` in `Containerfile` (Task 3).
- Produces: automerged PRs that change only that digest, ≥5 days after Aurora publishes it.

- [ ] **Step 1: Install the Renovate app**

Org owner: https://github.com/apps/renovate → Configure → Northeast-Childrens-Dentistry → Only select repositories → `necdos`.

- [ ] **Step 2: Replace the Aurora rule** — in `.github/renovate.json5`, replace the block commented "prevents the default demo image … from being pinned" with:

```json5
    // NECD soak: take a new Aurora stable digest only after it has been published 5 days,
    // and merge it automatically when the PR build passes.
    {
      "matchDatasources": ["docker"],
      "matchPackageNames": ["ghcr.io/ublue-os/aurora"],
      "matchUpdateTypes": ["digest"],
      "minimumReleaseAge": "5 days",
      "automerge": true,
    },
```

- [ ] **Step 3: Validate the config**

```bash
npx --yes --package renovate@41 renovate-config-validator .github/renovate.json5
```
Expected: `Config validated successfully`.

- [ ] **Step 4: Commit**

```bash
git add .github/renovate.json5
git commit -m "chore: soak Aurora digest bumps 5 days, then automerge"
```

- [ ] **Step 5: Observe after PR A merges (acceptance, runs in background of later tasks)**

Open the "Dependency Dashboard" issue Renovate creates. Expected: `ghcr.io/ublue-os/aurora` listed under `Containerfile` (detected through the `ARG BASE_IMAGE` default). **If it is not listed, STOP: Renovate is not seeing the pin, and the soak does nothing.** When Aurora publishes a new digest, expected: an "awaiting release age" entry, then a PR about 5 days later that automerges on a green build. **If the dashboard shows the update blocked because no release timestamp is available, STOP and bring it back to design** (fallback: a scheduled job that records first-seen dates).

---

### Task 5: Overnight reboot into staged updates

**Files:**
- Create: `system_files/usr/libexec/necd-update-reboot`
- Create: `system_files/usr/lib/systemd/system/necd-update-reboot.service`
- Create: `system_files/usr/lib/systemd/system/necd-update-reboot.timer`
- Create: `tests/necd-update-reboot.test.sh`
- Modify: `build_files/build.sh` (enable timer + checks)

**Interfaces:**
- Produces: `necd-update-reboot.timer` (enabled by default; admins opt a machine out with `sudo systemctl disable --now necd-update-reboot.timer`).

- [ ] **Step 1: Write the failing test** — `tests/necd-update-reboot.test.sh`:

```bash
#!/usr/bin/env bash
# Run: bash tests/necd-update-reboot.test.sh
set -euo pipefail
script=$(realpath "$(dirname "$0")/../system_files/usr/libexec/necd-update-reboot")
stub=$(mktemp -d); trap 'rm -rf "$stub"' EXIT

# run <bootc-json> <sessions-json> [bootc-exit] -> prints reboot|none
run() {
  printf '%s' "$1" > "$stub/bootc.json"; printf '%s' "$2" > "$stub/sessions.json"
  printf '#!/bin/sh\ncat %s/bootc.json\nexit %s\n' "$stub" "${3:-0}" > "$stub/bootc"
  printf '#!/bin/sh\ncat %s/sessions.json\n' "$stub" > "$stub/loginctl"
  printf '#!/bin/sh\necho "$@" >> %s/log\n' "$stub" > "$stub/systemctl"
  chmod +x "$stub/bootc" "$stub/loginctl" "$stub/systemctl"; : > "$stub/log"
  PATH="$stub:$PATH" bash "$script" >/dev/null 2>&1 || true
  grep -q reboot "$stub/log" && echo reboot || echo none
}
staged='{"status":{"staged":{"image":{}}}}'
idle='{"status":{"staged":null}}'
[[ $(run "$idle" '[]') == none ]]                         || { echo "FAIL no-staged"; exit 1; }
[[ $(run "$staged" '[{"class":"user"}]') == none ]]       || { echo "FAIL user-session"; exit 1; }
[[ $(run "$staged" '[{"class":"greeter"}]') == reboot ]]  || { echo "FAIL greeter-only"; exit 1; }
[[ $(run "$staged" '[]') == reboot ]]                     || { echo "FAIL no-sessions"; exit 1; }
[[ $(run "$staged" '[]' 1) == none ]]                     || { echo "FAIL bootc-error"; exit 1; }
echo PASS
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/necd-update-reboot.test.sh`
Expected: fails (`realpath` error: script does not exist).

- [ ] **Step 3: Write the script** — `system_files/usr/libexec/necd-update-reboot`:

```bash
#!/usr/bin/bash
# Reboot into a staged NECD OS update, only when nobody is logged in. Any error means no reboot.
# ponytail: a locked session left overnight blocks the reboot; the update then waits for the next manual restart.
set -euo pipefail
if ! bootc status --format=json | jq -e '.status.staged != null' >/dev/null; then
    echo "No staged update."
    exit 0
fi
if loginctl list-sessions -o json | jq -e 'any(.[]; .class | startswith("user"))' >/dev/null; then
    echo "Update staged, but a user is logged in. Not rebooting."
    exit 0
fi
echo "Rebooting into the staged update."
systemctl reboot
```

Then: `chmod +x system_files/usr/libexec/necd-update-reboot`

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/necd-update-reboot.test.sh`
Expected: `PASS`

- [ ] **Step 5: Add the units**

`system_files/usr/lib/systemd/system/necd-update-reboot.service`:
```ini
[Unit]
Description=Reboot into a staged NECD OS update if nobody is logged in

[Service]
Type=oneshot
ExecStart=/usr/libexec/necd-update-reboot
```

`system_files/usr/lib/systemd/system/necd-update-reboot.timer`:
```ini
[Unit]
Description=Nightly check for a staged NECD OS update

[Timer]
# No Persistent=: a PC that was off at 02:00 must not reboot when staff turn it on.
OnCalendar=*-*-* 02:00

[Install]
WantedBy=timers.target
```

- [ ] **Step 6: Enable and assert in `build_files/build.sh`**

After `cp -avf /ctx/system_files/. /` add:
```bash
systemctl enable necd-update-reboot.timer
```
In the checks block add:
```bash
test -e /usr/lib/systemd/system/uupd.timer   # Aurora's updater stages the updates this timer activates
test -L /etc/systemd/system/timers.target.wants/necd-update-reboot.timer
if grep -q '^Persistent=' /usr/lib/systemd/system/necd-update-reboot.timer; then exit 1; fi   # `! grep` would not fail under set -e
test -x /usr/libexec/necd-update-reboot
```

- [ ] **Step 7: Commit and check the PR build**

```bash
bash -n build_files/build.sh
git add system_files/usr/libexec/necd-update-reboot system_files/usr/lib/systemd/system/necd-update-reboot.* tests/necd-update-reboot.test.sh build_files/build.sh
git commit -m "feat: reboot into staged updates at 02:00 when nobody is logged in"
git push && gh pr checks --watch
```
Expected: build passes. Mark PR ready and merge (**PR A**).

---

### Task 6: Build workflow: channels, signing, verify, boot test, promote, report

**Files:**
- Modify: `.github/workflows/build.yml`
- Create: `disk_config/ci-boot.toml`

**Interfaces:**
- Consumes: environments `release`/`candidate` (Task 2); verify command (Task 1 step 4).
- Produces: job outputs `build_push.outputs.image` (lowercase `ghcr.io/northeast-childrens-dentistry/necdos`) and `build_push.outputs.digest` (`sha256:…`); tags `stable`, `stable-<YYYYMMDD>`; label `update-failure` issues.

- [ ] **Step 1: Triggers, inputs, concurrency** — replace the top of `build.yml` (through `concurrency:` block) with:

```yaml
---
name: Build container image
on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
    paths-ignore:
      - "**.md"
      - "docs/**"
  workflow_dispatch:
    inputs:
      force_fail:
        description: "Fail the verify job on purpose (proves stable does not move)"
        type: boolean
        default: false

env:
  IMAGE_REGISTRY: "ghcr.io/${{ github.repository_owner }}"  # do not edit

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  # main runs queue instead of cancelling, so promotions never overlap or run out of order.
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- [ ] **Step 2: Job header** — `build_push` gets an environment and outputs:

```yaml
  build_push:
    name: Build and push image
    runs-on: ubuntu-26.04
    # PRs get no environment, so they can never read the signing key.
    environment: ${{ github.event_name != 'pull_request' && (github.ref == 'refs/heads/main' && 'release' || 'candidate') || '' }}
    permissions:
      contents: read
      packages: write
      id-token: write
    outputs:
      image: ${{ steps.push-image.outputs.image }}
      digest: ${{ steps.push-image.outputs.digest }}
```

- [ ] **Step 3: Publish on any non-PR event** — in every step `if:` that reads
`github.event_name != 'pull_request' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`
replace it with `github.event_name != 'pull_request'` (signing guard, login, push, cosign install, sign). Update the guard's error text to: `Configure SIGNING_SECRET in the release and candidate environments before publishing.`

- [ ] **Step 4: Channel instead of Default Tag** — replace the `Default Tag` step with:

```yaml
      - name: Channel
        run: |
          # main becomes testing (promoted to stable after checks); every other ref is feature work.
          if [[ "${GITHUB_REF}" == refs/heads/main ]]; then TAG=testing; else TAG=candidate; fi
          echo "DEFAULT_TAG=${TAG}" >> "$GITHUB_ENV"
```

- [ ] **Step 5: Push one digest, sign it, then add the other tags** — replace `Push To GHCR` and `Sign container image` with (keep `Install Cosign` between them unchanged):

```yaml
      - name: Push To GHCR
        if: github.event_name != 'pull_request'
        id: push-image
        env:
          ALIAS_TAGS: ${{ steps.gen-build-tags.outputs.alias_tags }}
        run: |
          set -euox pipefail
          # Push once to the unique <tag>-<sha> tag; nobody tracks it, so it is safe before signing.
          set -- ${ALIAS_TAGS}
          podman push --digestfile=/tmp/digest "${IMAGE_NAME}:$1" "${IMAGE_REGISTRY}/${IMAGE_NAME}:$1"
          echo "digest=$(cat /tmp/digest)" >> "$GITHUB_OUTPUT"
          echo "image=${IMAGE_REGISTRY}/${IMAGE_NAME}" >> "$GITHUB_OUTPUT"

      - name: Install Cosign
        # (unchanged)

      - name: Sign container image
        if: github.event_name != 'pull_request'
        env:
          COSIGN_EXPERIMENTAL: false
          COSIGN_PRIVATE_KEY: ${{ secrets.SIGNING_SECRET }}
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
          DIGEST: ${{ steps.push-image.outputs.digest }}
        run: |
          # https://github.com/containers/container-libs/issues/388
          # https://github.com/coreos/rpm-ostree/issues/5509
          # use old bundle format, so we can use newer cosign 3.X.X instead of 2.X.X
          cosign sign -y --new-bundle-format=false --use-signing-config=false --key env://COSIGN_PRIVATE_KEY ${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}

      - name: Add remaining tags to the signed digest
        if: github.event_name != 'pull_request'
        env:
          ALIAS_TAGS: ${{ steps.gen-build-tags.outputs.alias_tags }}
          DIGEST: ${{ steps.push-image.outputs.digest }}
        run: |
          set -euox pipefail
          command -v skopeo || { sudo apt-get update && sudo apt-get install -y skopeo; }
          set -- ${ALIAS_TAGS}; shift
          for tag in "$@"; do
            skopeo copy --all --preserve-digests "docker://${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}" "docker://${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}"
          done
```

- [ ] **Step 6: Create `disk_config/ci-boot.toml`**

```toml
# CI boot test only: print systemd status on the serial console so the workflow can read it.
[customizations.kernel]
append = "console=ttyS0,115200 systemd.show_status=1 plymouth.enable=0"

[[customizations.filesystem]]
mountpoint = "/"
minsize = "20 GiB"
```

- [ ] **Step 7: Add the `verify` job** (use the verify command form recorded in Task 1 step 4):

```yaml
  verify:
    name: Verify signature and boot
    needs: build_push
    if: github.event_name != 'pull_request'
    runs-on: ubuntu-26.04
    permissions:
      contents: read
    env:
      IMAGE_REF: ${{ needs.build_push.outputs.image }}@${{ needs.build_push.outputs.digest }}
    steps:
      - name: Force failure
        if: inputs.force_fail
        run: |
          echo "::error::force_fail was set: stopping before promotion on purpose."
          exit 1

      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7

      - name: Maximize build space
        uses: ublue-os/remove-unwanted-software@695eb75bc387dbcd9685a8e72d23439d8686cba6

      - name: Install Cosign
        uses: sigstore/cosign-installer@6f9f17788090df1f26f669e9d70d6ae9567deba6 # v4.1.2
        with:
          cosign-release: 'v3.1.2'

      # No registry login: this also proves anonymous clients can pull and verify.
      - name: Verify signature
        run: cosign verify --key cosign.pub --new-bundle-format=false "${IMAGE_REF}"

      - name: Runner user ids
        run: echo "USER_IDS=$(id -u):$(id -g)" >> "$GITHUB_ENV"

      - name: Build qcow2
        id: bib
        uses: osbuild/bootc-image-builder-action@8661cd3832544ad68c12dcde8681b13ab0f56a8d # main
        with:
          builder-image: quay.io/centos-bootc/bootc-image-builder:latest
          config-file: ./disk_config/ci-boot.toml
          image: ${{ env.IMAGE_REF }}
          chown: ${{ env.USER_IDS }}
          types: qcow2
          additional-args: --use-librepo=True

      - name: Boot in QEMU
        env:
          DISK: ${{ steps.bib.outputs.output-directory }}/qcow2/disk.qcow2
        run: |
          set -euo pipefail
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
          sudo apt-get update && sudo apt-get install -y qemu-system-x86
          qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 6G -display none \
            -drive file="$DISK",if=virtio -serial file:serial.log &
          for _ in $(seq 1 90); do
            grep -q 'Reached target.*Graphical Interface' serial.log && break
            sleep 10
          done
          kill %1 || true
          if ! grep -q 'Reached target.*Graphical Interface' serial.log; then
            tail -n 100 serial.log; echo "::error::VM did not reach the desktop in 15 minutes"; exit 1
          fi
          if grep 'Failed to start' serial.log; then
            echo "::error::units failed during boot"; exit 1
          fi
```

- [ ] **Step 8: Add the `promote` and `report` jobs**

```yaml
  promote:
    name: Promote to stable
    needs: [build_push, verify]
    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-26.04
    concurrency:
      group: promote-stable
      cancel-in-progress: false
    permissions:
      contents: read
      packages: write
    steps:
      - name: Retag the verified digest as stable
        env:
          IMAGE: ${{ needs.build_push.outputs.image }}
          DIGEST: ${{ needs.build_push.outputs.digest }}
          TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          command -v skopeo || { sudo apt-get update && sudo apt-get install -y skopeo; }
          echo "$TOKEN" | skopeo login ghcr.io -u "${{ github.actor }}" --password-stdin
          for tag in "stable-$(date -u +%Y%m%d)" stable; do
            skopeo copy --all --preserve-digests "docker://${IMAGE}@${DIGEST}" "docker://${IMAGE}:${tag}"
          done
          test "$(skopeo inspect --raw "docker://${IMAGE}:stable" | sha256sum | cut -d' ' -f1)" = "${DIGEST#sha256:}"

  report:
    name: Report result
    needs: [build_push, verify, promote]
    if: always() && github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-26.04
    permissions:
      issues: write
    steps:
      - name: Open or close the update-failure issue
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          FAILED: ${{ contains(needs.*.result, 'failure') }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: |
          set -euo pipefail
          gh label create update-failure --color B60205 --description "Automatic NECD OS update failed" 2>/dev/null || true
          ISSUE=$(gh issue list --label update-failure --state open --json number --jq '.[0].number // empty')
          if [[ "$FAILED" == true ]]; then
            if [[ -n "$ISSUE" ]]; then
              gh issue comment "$ISSUE" --body "Failed again: $RUN_URL"
            else
              gh issue create --label update-failure --title "NECD OS update failed" \
                --body "stable was not changed; clinic PCs keep the last good image. Run: $RUN_URL"
            fi
          elif [[ -n "$ISSUE" ]]; then
            gh issue close "$ISSUE" --comment "Fixed by $RUN_URL. stable is promoted."
          fi
```

- [ ] **Step 9: Lint**

```bash
podman run --rm -v "$PWD:/repo:Z" -w /repo docker.io/rhysd/actionlint:1.7.7 -color
```
Expected: no errors.

- [ ] **Step 10: Commit and check the PR run**

```bash
git add .github/workflows/build.yml disk_config/ci-boot.toml
git commit -m "feat: build testing, verify, boot-test and promote stable"
git push && gh pr checks --watch
```
Expected: PR run builds; `verify`, `promote`, `report` show as skipped; no deployment to any environment appears on the PR.

- [ ] **Step 11: Test a candidate from the branch (guided: first signing from an environment)**

```bash
gh workflow run build.yml --ref feat/auto-updates
```
Approve the `candidate` deployment in the Actions UI. Expected: `build_push` and `verify` pass; `promote`/`report` skipped; `candidate-<sha>` exists and verifies with the Task 1 command. Only after this passes, delete the repo-level secrets with the admin:
```bash
gh secret delete SIGNING_SECRET; gh secret delete COSIGN_PASSWORD
```

---

### Task 7: Heartbeat, staleness and healthchecks.io

**Files:**
- Create: `.github/workflows/heartbeat.yml`

**Interfaces:**
- Consumes: label `io.necdos.base-image` on `:stable` (Task 3); repo secret `HC_PING_URL`.
- Produces: `update-stale` issues; daily ping.

- [ ] **Step 1: Create the healthchecks.io check**

Sign up at https://healthchecks.io (Hobbyist, free). New check `necdos-heartbeat`, Period **1 day**, Grace **1 day**, email integration on. Copy its ping URL.

- [ ] **Step 2: Store the ping URL**

```bash
gh secret set HC_PING_URL   # paste https://hc-ping.com/<uuid>
```

- [ ] **Step 3: Create `.github/workflows/heartbeat.yml`**

```yaml
---
name: Update heartbeat
on:
  schedule:
    - cron: "23 13 * * *"  # daily, morning US Eastern
  workflow_dispatch:

permissions:
  contents: read
  issues: write

jobs:
  heartbeat:
    runs-on: ubuntu-26.04
    steps:
      - name: Check stable is keeping up with Aurora
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
        run: |
          set -euo pipefail
          command -v skopeo || { sudo apt-get update && sudo apt-get install -y skopeo; }
          OURS=docker://ghcr.io/northeast-childrens-dentistry/necdos:stable
          AURORA=docker://ghcr.io/ublue-os/aurora:stable
          if ! BASE=$(skopeo inspect --no-creds "$OURS" | jq -er '.Labels["io.necdos.base-image"]'); then
            echo "No labeled stable yet; skipping staleness check."
            exit 0
          fi
          # Top-level digest of the tag (Aurora is a manifest list), as pinned in Containerfile.
          LATEST="sha256:$(skopeo inspect --no-creds --raw "$AURORA" | sha256sum | cut -d' ' -f1)"
          CREATED=$(skopeo inspect --no-creds "$AURORA" | jq -r .Created)
          AGE_DAYS=$(( ($(date +%s) - $(date -d "$CREATED" +%s)) / 86400 ))
          gh label create update-stale --color FBCA04 --description "stable is behind Aurora" 2>/dev/null || true
          ISSUE=$(gh issue list --label update-stale --state open --json number --jq '.[0].number // empty')
          # 19 = 5-day soak + 14 days grace.
          if [[ "$BASE" != *"@$LATEST" && $AGE_DAYS -ge 19 ]]; then
            MSG="stable is built on ${BASE#*@}; Aurora stable has been ${LATEST} for ${AGE_DAYS} days. Check the Renovate Dependency Dashboard and the last build run."
            if [[ -n "$ISSUE" ]]; then gh issue comment "$ISSUE" --body "$MSG"
            else gh issue create --label update-stale --title "NECD OS stable is behind Aurora" --body "$MSG"; fi
          elif [[ -n "$ISSUE" && "$BASE" == *"@$LATEST" ]]; then
            gh issue close "$ISSUE" --comment "stable is on the current Aurora digest again."
          fi

      - name: Ping healthchecks.io
        env:
          HC_PING_URL: ${{ secrets.HC_PING_URL }}
        run: curl -fsS -m 10 --retry 5 "$HC_PING_URL"
```

- [ ] **Step 4: Lint and dry-run the staleness logic**

```bash
podman run --rm -v "$PWD:/repo:Z" -w /repo docker.io/rhysd/actionlint:1.7.7 -color
```
Expected: no errors. After PR B merges: `gh workflow run heartbeat.yml && gh run watch`. Expected: passes; healthchecks.io shows the check green; no `update-stale` issue (stable was just built on the current digest). Before any stable exists the log says `No labeled stable yet` and the ping still runs.

- [ ] **Step 5: Commit, merge PR B**

```bash
git add .github/workflows/heartbeat.yml
git commit -m "feat: daily heartbeat, staleness issue and healthchecks.io ping"
git push && gh pr checks --watch
```
Mark ready and merge. Expected: the merge push runs the full main pipeline and creates the first `stable` and `stable-<date>`. Confirm:
```bash
DOCKER_CONFIG=$(mktemp -d) cosign verify --key cosign.pub --new-bundle-format=false ghcr.io/northeast-childrens-dentistry/necdos:stable
```

---

### Task 8: VM tests: deliberate failure, rollback, overnight reboot

**Files:** none (manual tests; results recorded as a comment on issue #4).

- [ ] **Step 1: Deliberate failure must not reach clients**

```bash
stable_digest() {  # anonymous; works because the package is public
  local t; t=$(curl -s "https://ghcr.io/token?scope=repository:northeast-childrens-dentistry/necdos:pull" | jq -r .token)
  curl -sI -H "Authorization: Bearer $t" \
    -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json" \
    https://ghcr.io/v2/northeast-childrens-dentistry/necdos/manifests/stable | grep -i '^docker-content-digest'
}
BEFORE=$(stable_digest)
gh workflow run build.yml --ref main -f force_fail=true && sleep 5 && gh run watch "$(gh run list -w build.yml -L1 --json databaseId --jq '.[0].databaseId')"
AFTER=$(stable_digest); [[ "$BEFORE" == "$AFTER" ]] && echo "stable unchanged"
gh issue list --label update-failure
```
Expected: run fails at `verify`; `promote` skipped; `stable unchanged`; one open `update-failure` issue. Then:
```bash
gh workflow run build.yml --ref main
```
Expected: run passes; the issue is closed with a "Fixed by" comment; a second `stable-<date>` or updated digest now exists.

- [ ] **Step 2: Rollback (needs two different stable digests; step 1 produced the second)**

```bash
just build-qcow2 ghcr.io/northeast-childrens-dentistry/necdos stable-<older-date>
just run-vm-qcow2 ghcr.io/northeast-childrens-dentistry/necdos stable-<older-date>
```
In the VM terminal:
```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/northeast-childrens-dentistry/necdos:stable-<older-date> && sudo reboot
sudo bootc switch --enforce-container-sigpolicy ghcr.io/northeast-childrens-dentistry/necdos:stable && sudo reboot
bootc status   # booted digest = current stable
sudo bootc rollback && sudo reboot
bootc status   # booted digest = stable-<older-date>
```
Expected: digests match at each check; no registry login was needed.

- [ ] **Step 3: Overnight reboot**

In the VM, on `stable` with an older deployment booted (after step 2's rollback, `sudo bootc switch --enforce-container-sigpolicy …:stable` without rebooting stages one):
```bash
systemctl is-enabled necd-update-reboot.timer          # enabled
sudo systemctl start necd-update-reboot.service; journalctl -u necd-update-reboot -n 3
```
Expected: "a user is logged in. Not rebooting." Then:
```bash
sudo systemd-run --on-active=90 systemctl start necd-update-reboot.service
```
Log out of the desktop within 90 s. Expected: the VM reboots into the staged digest (`bootc status` after login).

- [ ] **Step 4: Record results**

```bash
gh issue comment 4 --body "VM tests passed on $(date -I): deliberate failure kept stable; rollback; overnight reboot (logged-in skip + logged-out reboot)."
```

---

### Task 9: README and docs

**Files:**
- Modify: `README.md` ("Architecture and updates" section)
- Modify: `docs/first-build.md` ("Publication and signing" section)
- Modify: `docs/requirements.md:60`

- [ ] **Step 1: Replace the second paragraph of README "Architecture and updates"** (starts "The planned pipeline…") with:

```markdown
### How updates reach the clinic

| Tag | What it is | Who uses it |
| --- | --- | --- |
| `stable` | Last image that passed every check | Clinic PCs |
| `stable-<YYYYMMDD>` | Each promoted stable | Rollback points |
| `testing-*` | A `main` build before checks finish | Nobody |
| `candidate-*` | Feature work dispatched from a branch | Admin testing (VM, USB) |

- The Aurora base is pinned by digest in `Containerfile`. Renovate proposes a new digest 5 days after Aurora publishes it and merges it if the PR build passes.
- Every push to `main` builds `testing`, signs it, verifies the signature, boot-tests it in a VM, then retags the same digest as `stable`. Any failure leaves `stable` unchanged.
- Run a rebuild by hand: `gh workflow run build.yml --ref main`. Publish a candidate: `gh workflow run build.yml --ref <branch>` and approve the `candidate` deployment.
- Failures open an `update-failure` issue; `stable` lagging Aurora by 14 days past the soak opens `update-stale`; healthchecks.io emails if the daily heartbeat stops.
- The package is public and needs no client token. Clients only install images signed with `cosign.pub`. Never put a secret in the image.

### Clients, reboots and rollback

- Updates stage in the background and activate at the next boot. At 02:00 a PC reboots into a staged update **only if nobody is logged in**; a session left logged in overnight delays it to the next manual restart. Opt a PC out: `sudo systemctl disable --now necd-update-reboot.timer`.
- Staff: if something is wrong after a restart, call the administrator.
- Admin, previous image: `sudo bootc rollback && sudo reboot`.
- Admin, a specific older image: `sudo bootc switch --enforce-container-sigpolicy ghcr.io/northeast-childrens-dentistry/necdos:stable-<YYYYMMDD> && sudo reboot`. Return with the same command and `:stable`.

### Signing key rotation (only if the key may have leaked)

Done with the admin step by step: generate a new pair; ship both public keys in the image (policy.json lists both) for one release; switch the `release`/`candidate` secrets to the new key; once all clients run that release, remove the old public key.
```

- [ ] **Step 2: Update `docs/first-build.md` "Publication and signing"**

Replace its first two paragraphs (from "For this foundation stage…" through "…configure client trust verification. No signing key is committed. The existing template permissions and pinned action revisions are retained.") with:
`Automatic builds, promotion and signing are described in the README ("How updates reach the clinic"). Signing secrets live in the release (main only) and candidate (approval required) GitHub environments; pull requests never receive them. No signing key is committed.`

In "Contents", replace `- Name: necdos; candidate tag family. No stable/latest tag is promoted by this configuration.` with `- Name: necdos; stable, stable-<date>, testing-* and candidate-* tags (see README).`

- [ ] **Step 3: Update `docs/requirements.md:60`**

Replace `- Clients retain automatic staging and activate OS updates at normal reboot. No forced reboot during clinical work.` with
`- Clients retain automatic staging and activate OS updates at the next boot, including a 02:00 reboot that only runs when nobody is logged in. No forced reboot during clinical work.`

- [ ] **Step 4: Commit, merge PR C**

```bash
git add README.md docs/first-build.md docs/requirements.md
git commit -m "docs: document update channels, gates, alerting and rollback"
git push && gh pr create --fill && gh pr checks --watch
```
Expected: docs-only push to `main` after merge does not trigger a build (`paths-ignore`).
