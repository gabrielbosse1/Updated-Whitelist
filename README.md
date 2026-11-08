# Simple Whitelist — updated fork

This is **just a fork** of [iSlavok/Simple-Whitelist](https://github.com/iSlavok/Simple-Whitelist) that updates faster — I need it for my own server, so newer Minecraft versions get picked up here quickly. Almost all of the code is the original author's work, not mine. Whenever there's something worth keeping, I send pull requests back to the original project, so the official version stays the source of truth.

It's a simple whitelist system based on usernames, available as a Fabric mod and as a server plugin (Bukkit/Spigot/Paper/Purpur/Folia).

## Features

- **Whitelist based on usernames:** The whitelist system is based on usernames, not UUIDs. Names are case-sensitive — `Steve` and `steve` are treated as different players.
- **Database storage:** You can choose between storing the whitelist data in a JSON file or a MySQL database.
- **Supported versions:** Minecraft **1.18 → 26.3** on Fabric — one jar per version band.
- **ModMenu screen (client, 1.21.x):** With ModMenu installed, a minimal config screen lets you toggle the whitelist — handy when you open a singleplayer world to LAN.

## Server plugin (Bukkit/Spigot/Paper/Purpur/Folia)

The same whitelist is also available as a **server plugin** — one jar for Spigot, Paper,
Purpur and Folia (Folia-supported). It reuses the mod's JSON/MySQL storage and the same
case-sensitive, username-based rules, and needs no client mod.

- **Config:** `plugins/SimpleWhitelist/config.json` — same schema as the mod (see below).
- **Commands:** `/simplewhitelist add|remove|list|on|off` with aliases `swl`, `swh`,
  `swhitelist`; permission `simplewhitelist.command` (default: op — grant it via any
  permissions plugin, e.g. LuckPerms).
- **Supported versions:** Minecraft **1.18 → 26.3** (Java 17+ servers) — one jar, thanks
  to the stable Bukkit API.
- **Build locally:** `./gradlew -p plugin build` → `plugin/build/libs/*.jar`.
- **Try it on a real server:** `./gradlew -p plugin runServer` (override the version with
  `-Prun_mc=1.21.8`).

The plugin lives in a standalone Gradle build under `plugin/`. Client-only features (the
ModMenu config screen) are mod-only and have no plugin equivalent.

## Dependencies

Required (mod):

- Fabric API
- Fabric Language Kotlin

Optional (mod):

- A fabric-permissions-api provider (e.g. LuckPerms) for permission-based command access.
  Without it, commands fall back to vanilla operator level 4.

## Installation

**Download the ready jar for the newest Minecraft version (26.3):**
[`simple-whitelist-1.0.4+mc26.3.jar`](https://github.com/gabrielbosse1/Updated-Whitelist/releases/download/v1.0.4/simple-whitelist-1.0.4+mc26.3.jar)
— jars for every other supported Minecraft version (the `+mc<version>` files) and the
Bukkit plugin jar are on the [Releases page](https://github.com/gabrielbosse1/Updated-Whitelist/releases).
Pick the jar matching your server's version, then drop it into your `mods` folder (mod) or
`plugins` folder (plugin).

| Your server runs | Grab this jar |
|---|---|
| 26.3 | `simple-whitelist-1.0.4+mc26.3.jar` |
| 26.2 | `simple-whitelist-1.0.4+mc26.2.jar` |
| 26.1.x | `simple-whitelist-1.0.4+mc26.1.2.jar` |
| 1.21.x (incl. 1.21.11) | `simple-whitelist-1.0.4+mc1.21.10.jar` |
| 1.20.5 – 1.20.6 | `simple-whitelist-1.0.4+mc1.20.6.jar` |
| 1.20 – 1.20.4 | `simple-whitelist-1.0.4+mc1.20.1.jar` |
| 1.19.x | `simple-whitelist-1.0.4+mc1.19.4.jar` |
| 1.18.x | `simple-whitelist-1.0.4+mc1.18.2.jar` |

Or build from source — `./gradlew build` for the mod, `./gradlew -p plugin build` for the
plugin.

## Configuration

The default configuration file is `config\SimpleWhitelist\config.json`:

```json
{
    "whitelist": true,
    "databaseType": "json",
    "mysqlUrl": "jdbc:mysql://<username>:<password>@<host>:<port>/<database>",
    "jsonFileName": "whitelist.json"
}
```

**Configuration options:**

- `whitelist`: Enable or disable the whitelist.
- `databaseType`: The type of database to use. Can be either `json` or `mysql`.
- `mysqlUrl`: The connection string for the MySQL database.
- `jsonFileName`: The name of the JSON file to store the whitelist data.

## Commands

- **`simplewhitelist list`:** List all players on the whitelist.
- **`simplewhitelist add <player>`:** Add a player to the whitelist.
- **`simplewhitelist remove <player>`:** Remove a player from the whitelist.
- **`simplewhitelist on`:** Enable the whitelist.
- **`simplewhitelist off`:** Disable the whitelist.

**`simplewhitelist` aliases:** `swl`, `swh`, `swhitelist`

## Permissions

- **`simplewhitelist.command`:** Allows players to use the whitelist commands.

## Testing

Every supported Minecraft version and mod loader has its own test cell:

- **Fabric mod, each game version:** `./gradlew build` — unit tests run on every
  version node (1.18.2, 1.19.4, 1.20.1, 1.20.6, 1.21.10, 26.1.2, 26.2, 26.3), and
  in-game gametests (booted server) additionally run on the anchors that support
  the gametest harness. The 26.x nodes need JDK 25+ — they are only registered
  when the running JDK can build them.
- **Bukkit/Spigot/Paper/Purpur/Folia:** `./gradlew -p plugin build` — unit +
  MockBukkit tests, including the per-loader manifest contract
  (`LoaderSupportTest`).
- **Real servers:** `./scripts/smoke-server.sh <paper|purpur|folia|spigot> <mc>` boots
  that server with the shaded plugin jar and verifies in-server that the plugin
  enables and `swl add/remove/list` behave (including case sensitivity). CI runs
  a smoke cell per loader across the version range (Folia currently tops out at
  26.2; the `bukkit` loader has no 1.18+ server to boot — upstream stopped at
  1.12 — so it is covered by the shared Bukkit-API suite).
- **Whole matrix at once:** `./scripts/test-matrix.sh` runs every
  (Minecraft version × loader) cell and prints a pass/fail table; CI runs the
  same matrix in the `test-matrix` job of the build workflow.

## Credits

Almost all of the code is by **iSlavok**, the original author of Simple Whitelist — this
fork is only here so the versions I need for my server get updated faster. Improvements go
back to the original project as pull requests.
