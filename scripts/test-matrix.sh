#!/usr/bin/env bash
# Test every supported Minecraft version x mod loader and print a pass/fail table.
#
# Mirrors the CI `test-matrix` job (see .github/workflows/build.yml):
#   fabric x each game version   -> ./gradlew :<mc>:build
#                                    (compile + unit tests; in-game gametests on
#                                     the anchors that configure the harness)
#   bukkit/spigot/paper/purpur/
#   folia (one shared jar)       -> ./gradlew -p plugin build
#                                    (compile + unit + MockBukkit tests, incl.
#                                     the per-loader manifest contract)
#
# The 26.x nodes are unobfuscated and only registered when the running JDK is
# 25+ (see settings.gradle.kts); on older JDKs those cells report SKIP.
#
# Usage: scripts/test-matrix.sh
set -u
cd "$(dirname "$0")/.."

FABRIC_VERSIONS=(1.18.2 1.19.4 1.20.1 1.20.6 1.21.10 26.1.2 26.2 26.3)
FABRIC_26=(26.1.2 26.2 26.3)
PLUGIN_LOADERS=(bukkit spigot paper purpur folia)

java_major() {
    local v
    v="$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')" || return 1
    [[ "$v" =~ ^[0-9]+$ ]] || return 1
    echo "$v"
}

declare -a ROWS=()
FAILED=0

run_cell() { # loader mc gradle-args...
    local loader="$1" mc="$2"; shift 2
    printf '\n=== [%s %s] ./gradlew %s ===\n' "$loader" "$mc" "$*"
    if ./gradlew "$@" --console=plain; then
        ROWS+=("PASS  $loader  $mc")
    else
        ROWS+=("FAIL  $loader  $mc")
        FAILED=1
    fi
}

if ! command -v java >/dev/null 2>&1; then
    echo "error: no 'java' on PATH — a JDK (21+, or 25+ for the 26.x nodes) is required" >&2
    FAILED=1
else
    JAVA_MAJOR="$(java_major || echo 0)"
    echo "java major version: $JAVA_MAJOR"
fi

for mc in "${FABRIC_VERSIONS[@]}"; do
    if [[ " ${FABRIC_26[*]} " == *" $mc "* ]] && { [[ "${JAVA_MAJOR:-0}" -lt 25 ]]; }; then
        ROWS+=("SKIP  fabric  $mc   (needs JDK 25+; node not registered)")
        continue
    fi
    run_cell fabric "$mc" ":$mc:build"
done

for loader in "${PLUGIN_LOADERS[@]}"; do
    run_cell "$loader" "1.18-26.3" -p plugin build
done

printf '\n================ test matrix summary ================\n'
printf '%s\n' "${ROWS[@]}" | sort -k2,2 -k3,3
printf '====================================================\n'
exit "$FAILED"
