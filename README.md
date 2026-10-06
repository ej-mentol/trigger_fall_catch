# trigger_fall_catch

Sven Co-op point entity. Catches players that fall below a reference point: fires a target and/or respawns them.

## Install

1. Copy `fall_catch.as` to `scripts/maps/`.
2. In the map `.cfg` add `map_script <path without extension>`.
3. Add `fall_catch.fgd` to your Hammer game configuration.

## How it works

Every `scantime` seconds each alive player is checked. A player is fallen when `feet.z < reference.z + offset`, where `feet.z = origin.z + mins.z`. The reference is the `watch` entity, otherwise the trigger itself.

For a fallen player: `target` is fired (the player is the activator), then the player is respawned if the flag is set, then the sound plays. After that the player is ignored for `cooldown` seconds.

## Keys

| Key | Default | Description |
|---|---|---|
| `targetname` | | Needed to turn the entity On/Off with Use. |
| `initial_state` | `1` | State at map start: `0` Off, `1` On. |
| `target` | | Fired with the fallen player as activator. A delay in between replaces the activator. |
| `watch` | | Entity used as the reference point instead of this one, for example a train. Brushes use their center. |
| `offset` | `-8` | Added to the reference Z. A player is fallen when their feet are below the result. Use a negative value. |
| `radius` | `0` | Horizontal radius around the reference. Players farther away are ignored. `0` = unlimited. |
| `cooldown` | `0.5` | Seconds before the same player can be caught again. Without it a player still below the line would trigger on every check. |
| `scantime` | `0.1` | Seconds between checks. Lower = faster reaction, more load. Below `0.01` falls back to `0.1`. |
| `sound` | | Path relative to `sound/`. Empty = no sound. Custom sounds must be in the map `.res`. |
| `health` | `10` | Sound volume, 1-10. `0` or unset = 10. |
| `pitch` | `100` | Sound pitch, 1-255. Above 100 = higher. |

## Flags

| Value | Name | Effect |
|---|---|---|
| 1 | Respawn Player | Respawn the player on an active spawn point. |
| 2 | Debug Log | Print `[fall_catch]` diagnostics to the console. |

`On` enables, `Off` disables, anything else toggles.

## Notes

- Z-only check, meant for flat floors. On a slope a player can end up below the reference and gets caught.
- `Respawn Player` does not move spawn points. For a train or platform the spawn point has to follow it, for example with `trigger_setorigin`.
- Players only. Noclip players are not excluded.
- The sound is meant to be heard only by the fallen player (`target_ent_unreliable`). Not verified in-game.
