# trigger_fall_catch

Sven Co-op AngelScript point entity. Detects players that fall below a reference point and then teleports them, fires a target, or kills them.

Originally written to catch players falling off a moving train. Nothing in it is train-specific.

## Files

| File | Purpose |
|---|---|
| `fall_catch.as` | Map script. Registers the entity `trigger_fall_catch`. |
| `fall_catch.fgd` | Hammer definition for the entity. |

## Install

1. Copy `fall_catch.as` to `scripts/maps/` (a subfolder is fine).
2. In the map's `.cfg` add `map_script <path without extension>`, for example `map_script mymap/fall_catch`.
3. Add `fall_catch.fgd` to the FGD list of your Hammer game configuration.
4. Place `trigger_fall_catch` in the map and set its keys.

## How it works

Every 0.1 s the entity checks all alive, connected players. A player counts as fallen when:

```
feet.z < reference.z + offset      where feet.z = origin.z + mins.z
```

`offset` is normally negative. `-8` means the line is 8 units below the reference point.

The reference point is chosen in this order:

1. `watch` entity, if set.
2. The destination entity, if the flag `Reference = Destination` is set.
3. The trigger itself.

For brush entities the center of the bounding box is used, not the bottom.

When a player is fallen, one action runs (first match wins):

1. Flag `Kill Instead of Teleport`: the player is killed.
2. `fire_target` is set: targets are fired with the player as activator.
3. Otherwise: the player is teleported to the destination.

After any action the same player is ignored for `teleport_cooldown` seconds.

## Keys

| Key | Default | Description |
|---|---|---|
| `targetname` | | Name, needed for `Use`. |
| `fire_target` | | Fired with the fallen player as activator. If empty, the player is teleported. |
| `dest_target1` | | Targetname of the destination. If several entities share the name, one is picked at random per teleport. |
| `watch` | | Reference point entity, instead of the trigger itself. |
| `offset` | `-8` | Added to the reference Z. See above. |
| `radius` | `0` | Horizontal radius around the reference point. Players outside it are ignored. `0` = unlimited. |
| `teleport_cooldown` | `0.5` | Per-player cooldown in seconds. Applies to all three actions. |

## Flags

| Value | Name | Effect |
|---|---|---|
| 1 | Start Off | Disabled until triggered. |
| 2 | Kill Instead of Teleport | Kills the player. Takes priority over `fire_target`. |
| 4 | Keep Angles | Teleport only. Do not change view angles. |
| 8 | Keep Velocity | Teleport only. Do not reset velocity. |
| 16 | Reference = Destination | Use the destination as the reference point. |
| 32 | Debug Log | Print diagnostics to the console and server log. |

`Keep Angles` and `Keep Velocity` have no effect in `fire_target` or kill mode.

## Use

Triggering the entity: `On` enables it, `Off` disables it, any other use type toggles it.

## Teleport details

- Position: destination origin, plus `FC_DEST_LIFT`, minus the player's `mins.z`. With the default lift of 16 and a standing player, the player origin ends up 52 units above the destination origin. This assumes the destination is at floor level.
- If the destination is at player-center height, lower `FC_DEST_LIFT`. A value of `-35` puts the origin 1 unit above the destination (standing hull).
- If the spot is blocked, the position is raised by 24 units, up to 4 times.
- Velocity is zeroed. View angles are set to the destination yaw with pitch 0.
- The sound is played on the player.

## Fire target notes

- The player is passed as activator. An entity with a delay between this trigger and the final target replaces the activator by default, so `!activator` may no longer refer to the player. Connect `fire_target` directly to the entity that needs the player.
- `trigger_respawn` as the target: set the flag `Respawn Target` and use `!activator` as its target. Without that flag it respawns all players. By the wiki, living players are moved to active spawn points and healed to full health. `!activator` support in that key is not documented; test it.
- A respawn needs a free active spawn point. If it is blocked, the respawn may not happen and the trigger will fire again after the cooldown.

## Settings in the script

Constants at the top of `fall_catch.as`:

| Constant | Default | Description |
|---|---|---|
| `FC_SOUND_FILE` | `debris/alien_teleport.wav` | Sound path, relative to `sound/`. Custom sounds must be added to the map `.res` file. |
| `FC_SOUND_CHANNEL` | `CHAN_AUTO` | Sound channel. |
| `FC_THINK_INTERVAL` | `0.1` | Seconds between checks. |
| `FC_DEST_LIFT` | `16` | Vertical lift at teleport. |
| `FC_DEBUG_INTERVAL` | `5` | Seconds between debug summaries. |

## Debugging

Set the flag `Debug Log`. Lines are prefixed with `[fall_catch]`:

- `spawned`: entity created, with its keys.
- Summary every `FC_DEBUG_INTERVAL` seconds: reference point, limit Z, lowest player feet Z, whether the destination was found. Also `disabled`, `watch entity not found`, `reference = destination, but ... not found`.
- `fall`, `teleport`, `no destination found`: printed when they happen.

No `spawned` line: the script is not loaded or the entity was not created. Check the `map_script` path, the classname in the map and the console for script errors.

## Limitations

- Players only. Monsters are not checked.
- The check is vertical, with an optional horizontal radius. There is no volume or brush trigger.
- Not every key and flag combination has been tested in-game.
