#!/usr/bin/env bash
# Run: bash tests/heartbeat-stale.test.sh
set -euo pipefail
script=$(realpath "$(dirname "$0")/../.github/scripts/heartbeat-stale.sh")
stub=$(mktemp -d); trap 'rm -rf "$stub"' EXIT
MANIFEST='{"manifests":[]}'
LATEST="sha256:$(printf '%s' "$MANIFEST" | sha256sum | cut -d' ' -f1)"
OLD=sha256:0000000000000000000000000000000000000000000000000000000000000000
days_ago() { date -u -d "@$(( $(date +%s) - $1 * 86400 ))" +%Y-%m-%dT%H:%M:%SZ; }

# run <our-base-digest|none> <latest-age-days> <base-age-days|pruned> <open-issue|""> -> prints gh actions taken
run() {
  cat > "$stub/skopeo" <<SH
#!/usr/bin/env bash
case "\$*" in
  *necdos:stable*) [[ "$1" == none ]] && exit 1; echo '{"Labels":{"io.necdos.base-image":"ghcr.io/ublue-os/aurora:stable@$1"}}' ;;
  *--raw*aurora:stable*) printf '%s' '$MANIFEST' ;;
  *aurora:stable*) echo '{"Created":"$(days_ago "$2")"}' ;;
  *aurora@*) [[ "$3" == pruned ]] && exit 1; echo '{"Created":"$(days_ago "${3/pruned/0}")"}' ;;
  *) exit 2 ;;
esac
SH
  cat > "$stub/gh" <<SH
#!/usr/bin/env bash
case "\$1 \$2" in
  "issue list") echo "$4" ;;
  "label create") ;;
  *) echo "\$1 \$2" >> "$stub/log" ;;
esac
SH
  chmod +x "$stub/skopeo" "$stub/gh"; : > "$stub/log"
  PATH="$stub:$PATH" bash "$script" >/dev/null 2>&1 || echo "script-error" >> "$stub/log"
  tr '\n' ',' < "$stub/log"
}
[[ $(run none 1 1 "") == "" ]]                         || { echo "FAIL no-stable-skips"; exit 1; }
[[ $(run "$LATEST" 1 1 "") == "" ]]                    || { echo "FAIL current-no-issue"; exit 1; }
[[ $(run "$OLD" 1 10 "") == "" ]]                      || { echo "FAIL normal-lag-no-issue"; exit 1; }
[[ $(run "$OLD" 1 40 "") == "issue create," ]]         || { echo "FAIL old-base-while-aurora-weekly"; exit 1; }
[[ $(run "$OLD" 1 pruned "") == "issue create," ]]     || { echo "FAIL pruned-base-is-stale"; exit 1; }
[[ $(run "$OLD" 1 40 7) == "issue comment," ]]         || { echo "FAIL stale-comments-existing"; exit 1; }
[[ $(run "$LATEST" 1 1 7) == "issue close," ]]         || { echo "FAIL caught-up-closes"; exit 1; }
echo PASS
