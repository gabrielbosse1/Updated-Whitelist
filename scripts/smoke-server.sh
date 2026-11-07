#!/usr/bin/env bash
# Real-server smoke test per mod loader: boot <loader> <mc> with the shaded
# plugin jar and verify the plugin enables and its whitelist commands work end
# to end (list / add / case-sensitive remove), then stop cleanly.
#
# usage: scripts/smoke-server.sh <paper|purpur|folia|spigot> <mc-version>
#
# Server jars: paper + folia come from PaperMC's Fill v3 downloads API (the old
# api.papermc.io/v2 service was sunset in 2026), purpur from api.purpurmc.org,
# and spigot is built with BuildTools (Spigot ships no prebuilt server jars).
# The bukkit loader has no 1.18+ server to boot (upstream stopped at 1.12) — it
# is covered by the shared Bukkit-API suite in plugin/src/test instead.
set -u
cd "$(dirname "$0")/.."

LOADER="${1:-}"
MC="${2:-}"
usage() { echo "usage: $0 <paper|purpur|folia|spigot> <mc-version>" >&2; exit 2; }
[[ -n "$LOADER" && -n "$MC" ]] || usage
case "$LOADER" in paper|purpur|folia|spigot) ;; *) usage ;; esac

UA="simple-whitelist-smoke (github.com/gabrielbosse1/Updated-Whitelist)"
PORT="${SMOKE_PORT:-25599}"
DIR="run/smoke-$LOADER-$MC"
LOG="$DIR/server.log"

die() { echo "smoke($LOADER $MC): FAIL: $*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"
command -v python3 >/dev/null || die "python3 is required"
command -v java >/dev/null || die "java is required"

# --- the plugin jar (build it if it is not there yet) -----------------------
JAR="$(find plugin/build/libs -name 'simple-whitelist-plugin-*.jar' ! -name '*-sources.jar' 2>/dev/null | head -1)"
if [[ -z "$JAR" ]]; then
    echo "smoke($LOADER $MC): building the plugin jar..."
    ./gradlew -p plugin shadowJar --console=plain || die "plugin build failed"
    JAR="$(find plugin/build/libs -name 'simple-whitelist-plugin-*.jar' ! -name '*-sources.jar' 2>/dev/null | head -1)"
fi
[[ -n "$JAR" ]] || die "no plugin jar in plugin/build/libs"

# --- java level: 26.x servers need Java 25, older ones Java 17+ ------------
need_java=17
case "$MC" in 26.*|27.*) need_java=25 ;; esac
have_java="$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')"
[[ "$have_java" =~ ^[0-9]+$ ]] || die "cannot parse 'java -version'"
(( have_java >= need_java )) || die "Minecraft $MC needs Java $need_java+, java on PATH is $have_java"

rm -rf "$DIR"
mkdir -p "$DIR/plugins"
# Absolute from here on: the server runs with $DIR as its CWD (it looks for
# eula.txt, server.properties and plugins/ in the CWD, not next to the jar).
DIR="$(cd "$DIR" && pwd)"
LOG="$DIR/server.log"
cp "$JAR" "$DIR/plugins/"
echo "eula=true" > "$DIR/eula.txt"
cat > "$DIR/server.properties" <<EOF
online-mode=false
white-list=false
enforce-whitelist=false
level-type=minecraft:flat
view-distance=4
simulation-distance=4
spawn-protection=0
server-port=$PORT
motd=SimpleWhitelist smoke test
EOF

# --- fetch the server jar ---------------------------------------------------
fetch_fill() { # paper | folia
    local project="$1"
    local api="https://fill.papermc.io/v3/projects/$project/versions/$MC/builds"
    curl -fsSL -A "$UA" "$api" -o "$DIR/builds.json" || die "Fill v3 API request failed: $api"
    local picked url name sha
    picked="$(python3 - "$DIR/builds.json" <<'PY'
import json, sys
builds = json.load(open(sys.argv[1]))
if not isinstance(builds, list) or not builds:
    sys.exit("no builds in API response")
# newest first; prefer the STABLE channel (folia only ships BETA)
build = next((b for b in builds if b.get("channel") == "STABLE"), builds[0])
dl = build["downloads"]["server:default"]
print(dl["url"])
print(dl["name"])
print(dl["checksums"]["sha256"])
PY
)" || die "no downloadable build for $project $MC"
    url="$(sed -n 1p <<<"$picked")"
    name="$(sed -n 2p <<<"$picked")"
    sha="$(sed -n 3p <<<"$picked")"
    echo "smoke($LOADER $MC): downloading $name"
    curl -fsSL -A "$UA" -o "$DIR/server.jar" "$url" || die "download failed: $url"
    echo "$sha  $DIR/server.jar" | sha256sum -c - >/dev/null || die "sha256 mismatch for $name"
}

fetch_spigot() {
    command -v git >/dev/null || die "git is required to build Spigot"
    command -v mvn >/dev/null || die "maven is required to build Spigot"
    echo "smoke(spigot $MC): building with BuildTools (this takes a while)..."
    curl -fsSL -o "$DIR/BuildTools.jar" \
        "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" \
        || die "BuildTools download failed"
    (cd "$DIR" && timeout 1800 java -jar BuildTools.jar --rev "$MC" > BuildTools.log 2>&1) \
        || { tail -20 "$DIR/BuildTools.log"; die "BuildTools failed"; }
    [[ -f "$DIR/spigot-$MC.jar" ]] || die "BuildTools did not produce spigot-$MC.jar"
    cp "$DIR/spigot-$MC.jar" "$DIR/server.jar"
}

case "$LOADER" in
    paper|folia) fetch_fill "$LOADER" ;;
    purpur)
        echo "smoke(purpur $MC): downloading latest build"
        curl -fsSL -A "$UA" -o "$DIR/server.jar" \
            "https://api.purpurmc.org/v2/purpur/$MC/latest/download" \
            || die "purpur download failed for $MC"
        ;;
    spigot) fetch_spigot ;;
esac

# --- boot the server, drive its console, check the transcript ---------------
FEEDER="$DIR/console.in"
mkfifo "$FEEDER"
FEEDER_PID=""
cleanup() { [[ -n "$FEEDER_PID" ]] && kill "$FEEDER_PID" 2>/dev/null; }
trap cleanup EXIT

(
    for _ in $(seq 1 150); do grep -q "Done (" "$LOG" 2>/dev/null && break; sleep 2; done
    echo "swl list"; sleep 3
    echo "swl add SmokeUser"; sleep 3
    echo "swl remove smokeuser"; sleep 3
    echo "swl list"; sleep 3
    echo "stop"
) > "$FEEDER" &
FEEDER_PID=$!

echo "smoke($LOADER $MC): booting (port $PORT)..."
# Run from $DIR so the server picks up eula.txt/server.properties/plugins/;
# the FIFO and log stay on absolute paths set up by the outer shell.
( cd "$DIR" && exec timeout 600 java -Xms512M -Xmx2G -jar server.jar nogui ) < "$FEEDER" > "$LOG" 2>&1
rc=$?

expect() {
    grep -qF "$1" "$LOG" || { echo "--- log tail ---"; tail -30 "$LOG"; die "missing expected log line: $1"; }
}
expect "Enabling SimpleWhitelist"
expect "Done ("
expect "SmokeUser added to whitelist"
# "SmokeUser" is in the whitelist, so removing the lowercase form must fail —
# the in-server proof that lookups are case-sensitive.
expect "smokeuser not found on the whitelist"
expect "Players on the whitelist: SmokeUser"
expect "Disabling SimpleWhitelist"

[[ $rc -eq 0 ]] || { echo "--- log tail ---"; tail -30 "$LOG"; die "server exited with code $rc"; }

echo "smoke($LOADER $MC): PASS"
