# NV Relight

Dark caves, fixed without torches. NV Relight gives every node a minimum light
level, so caves and tunnels stay readable, and it automatically relights map
blocks you generated *before* installing it (the engine never does this on its
own, which is why most "ambient light" mods seem to do nothing in old worlds).

Developed and used in **Mineclonia** on **Luanti 5.17.0**. Should work in any game.

## Settings

| Setting | Default | Range | Meaning |
|---|---|---|---|
| `nv_relight.level` | 8 | 0 to 14 | Minimum light every node emits. 0 = off. |
| `nv_relight.spawn_safe` | true | true/false | Make game logic (mob spawning) ignore light that comes only from the glow. The screen still shows it lit. |

Set it in the mod settings menu or in `minetest.conf`:

    nv_relight.level = 8

Light spreads from every surface and loses 1 level per node, so the glow reaches
about `level - 1` nodes into open space. Big caverns need higher values.
Changing the level automatically triggers a fresh relight as you walk around.

## Screenshots

### Before NV Relight
![Before NV Relight](screenshots/before.png)

### After NV Relight
![After NV Relight](screenshots/after.png)

## Spawn-safe light

`spawn_safe` replaces `core.get_artificial_light` with a wrapper: any value up to
`level - 1` (the most the glow can add to air) is returned as 0. Disable it with
`nv_relight.spawn_safe = false` if another mod misbehaves.

## Commands

`/nvdiag` prints the active level, whether spawn-safe light is active, and the stored
light around you. Useful for bug reports. No privileges needed.

`/nvlevel` shows the current level. `/nvlevel <0-14>` changes it while you play, saves it
to `minetest.conf`, and relights around you right away; other areas update as you walk
into them. In single-player anyone may use it, otherwise it needs the `server` privilege.
`/nvlevel 0` turns the glow off and restores every node's original light value.
Changing the level live was tested on Luanti 5.6.1; if the new level does not show up on
your version, restart the world, because the saved value is read at startup.

## How it works

1. At startup, every registered node (except `air`, `ignore`, `unknown`) with a
   `light_source` below the level is raised to that level.
2. Each second, if the map block around a player has not yet been relit since the
   level last changed, the mod runs `core.fix_light` on the 3x3x3 blocks around
   the player (about 20 ms) and remembers it in mod storage.

It changes light data only, never nodes, items or inventories.

## Limitations (please read)

* The glow is real stored light, so games that check light see it. In Mineclonia,
  hostile mobs only spawn where artificial light is 0 (`core.get_artificial_light`),
  which the glow blocks completely. With `nv_relight.spawn_safe = true` (default) the mod
  reports glow-only light as 0 to that function. Light from real sources (torches etc.)
  above `level - 1` still counts, so torches protect a smaller radius than in vanilla.
  Confirmed in play on Luanti 5.17.0 with Mineclonia (macOS): dungeon spawners, night
  surface spawns and natural cave spawns all keep working with the glow on. Also tested
  on Luanti 5.6.1 with a simulated game check.
  Games that check light another way (for example `core.get_node_light`) are not covered.
* Every solid surface glows, so night above ground is also brighter near terrain.
* Mod storage keeps one entry per relit map block, so it grows with the explored
  area. Not yet tuned for very large multiplayer servers.
* Do not enable it together with `k_ambient_light`; one of them is enough.
* Tested headless on Luanti 5.6.1 with Minetest Game, and in real play on
  Luanti 5.17.0 with Mineclonia (macOS). Other games and platforms are untested.

## Credits

The idea of raising node `light_source` for ambient light comes from
[K Ambient Light](https://content.luanti.org/packages/ketwaroo/k_ambient_light/)
by ketwaroo (GPL-3.0-or-later). NV Relight is a separate rewrite that adds
automatic relighting and diagnostics.


## Installation

1. Download the latest release ZIP.
2. Extract the `nv_relight` folder.
3. Place the folder in the appropriate Luanti mods directory.
4. Enable NV Relight for your world.
5. Configure the mod settings if needed.

## Compatibility

- Tested with: Mineclonia on Luanti 5.17.0
- Other games and versions: Not yet verified

## License

Copyright (C) 2026 Hari Prasadh

GPL-3.0-or-later. See `LICENSE`.
