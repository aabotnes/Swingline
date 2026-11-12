<p align="center"><img src="Media/Logo.png" width="128" alt="Swingline icon"></p>

# Swingline

*by Soeta*

Modern, fully customizable weapon swing timers for **WoW Forever**. Each bar has its own settings. Bars can float anywhere on screen, or dock to your unit frames either on their own or in groups.

## Install
- **CurseForge app**: search for *Swingline*.
- **Manual**: download the zip from [Releases](https://github.com/aabotnes/Swingline/releases). Extract it into the Forever client's `Interface\AddOns` folder, so you end up with `AddOns\Swingline\Swingline.toc`.

## Use
- `/swl` opens the settings window. It also opens from Swingline's minimap button, the AddOns compartment, or Options > AddOns > Swingline.
- Minimap button: left-click opens the settings, right-click locks or unlocks the bars, and you can drag it around the minimap. Hide it on the General page or with `/swl minimap`.
- `/swl unlock` and `/swl lock` turn dragging on and off. `/swl test` shows every bar.
- `/swl profile <name>` switches profile. `/swl reset` resets the active profile.
- While the bars are unlocked, drag one to move it, or right-click it to open its settings.

## Bars
| Player | Target |
|---|---|
| Main Hand (labelled *Two-Hand* when a two-hander is equipped) | Main Hand |
| Off Hand (shown only while dual-wielding) | Off Hand |
| Ranged (including Auto Shot and wands) | Ranged (Auto Shot or Shoot) |

Settings for each bar:
- **Look**: WoW Forever (the game's own swing bar art), Classic, Modern, Minimal Line, Neon Glow or Centered
- **Size and colour**: width, height, colour and background opacity
- **Text**: time remaining, weapon label and spark, each on or off
- **Fill direction**: fill up or drain

Settings for each bar's position:
- **Anchor to**: Player group, Target group, free, Player unit frame, Target unit frame, or a custom frame name. Unit frames are detected in this order: ElvUI, Shadowed Unit Frames, PitBull4, oUF, then Blizzard's own frames.
- **Placement**: which side the bar attaches on, plus X/Y offsets. Dragging a bar updates its offsets from whatever it's anchored to.

## Groups
There are two groups: one for your bars and one for your target's. Out of the box, each unit's bars sit in its group and each group is anchored to its unit frame, so moving a group moves those three bars together.
- **Offsets**: each member bar keeps its own offsets from its group. Each group has its own anchor (free, unit frame or custom frame), attachment point and X/Y offset.
- **Group pages**: the *Group* entry under PLAYER or TARGET in the sidebar sets that group's anchor and which bars are members. Any bar can also join either group from its own **Anchor to** setting.
- **Adding or removing a bar**: the bar stays where it is on screen; only its offsets change.
- **Moving a group**: unlock bars, then drag the group by its tab, or Shift-drag any member bar.

## Nameplate swing lines
Optional thin swing timers on your current target's nameplate. Turn them on under **Nameplate** in the sidebar.
- **Lines & look:**
  - which of the six timers to show
  - style: Flat, Gradient, Classic, Neon Glow or WoW Forever art
  - border, spark and fill direction
  - colours: the bars' own, or one colour for your lines and one for your target's
  - optional time text and background opacity
- **Position & visibility:**
  - width (0 = match the plate), line height and gap
  - above or below the health bar, with X/Y offsets
  - separate on/off settings for **solo**, **in a party** and **in a raid**
- **All nearby enemies (optional):** every enemy nameplate gets that enemy's own melee and ranged lines.
  - Ranged comes from each enemy's Auto Shot or Shoot.
  - Melee: the game doesn't say which enemy landed a hit. With one attacker, the hit is credited to it. With several, it goes to the enemy whose next swing is due right then, so a pack can be followed once each mob has swung once. A hit that matches nobody is ignored.
  - A line disappears shortly after its swing is due if no new swing is seen, so it never freezes.
  - Switching target carries that enemy's timers over to your target bars.

## Profiles
Profiles are shared by all your characters, and each character remembers which one it uses. New characters start on **WoW Forever**. On the **Profiles** page you can create, duplicate, rename, copy from, reset or delete profiles. You can also switch with `/swl profile <name>`.

Built-in profiles (all anchor bars to the player and target groups):
| Profile | Look |
|---|---|
| WoW Forever *(default)* | The game's own swing bar art (213x30), below your unit frames |
| Classic | Blizzard-style bars with borders, labels and timers, below your unit frames |
| Minimalistic | Hair-thin 2px lines across the top of your unit frames |
| Center Stack | Both groups under your character, with target bars above yours |
| Neon | Glowing slim bars below your unit frames |

Built-in profiles can be edited freely. **Reset** brings back the original look, and **Restore built-in profiles** re-adds any you deleted.

## WoW Forever look and the game's own bars
The *WoW Forever* look uses the same art, insets, pip and font as the game's built-in swing timer. Like the game's bars, it dims and turns its labels red when you're out of range, and bar colour doesn't apply to it. **Use the game's bar size** on a bar's page sets its width and height to match the art.

If you'd rather see only Swingline, turn on **Hide the game's own swing bars** on the General page. It turns off the game's `showSwingTimer` setting for every character.

## How timing works
- **Your swings** come from Forever's native `PLAYER_SWING` event. Haste changes during a swing rescale the time left. Bars dim when your target is out of range, using `C_SwingTimer` range checks.
- **Target swings** are estimates. Forever closes the combat log to addons, so Swingline times the melee hits your target lands on you (`UNIT_COMBAT`). Attack speed comes from `UnitAttackSpeed("target")` when the game allows reading it; otherwise Swingline measures the time between hits. Target ranged timing comes from the target's Auto Shot or Shoot casts.

## Releasing (maintainers)
Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) in `.github/workflows/release.yml`.

One-time setup:
1. Create the project on CurseForge and upload `Media/Logo.png` as its avatar.
2. Add the project ID to `Swingline.toc` as `## X-Curse-Project-ID: <id>`.
3. Add a CurseForge API token as the repository secret `CF_API_KEY`.

For each release:
1. Update `CHANGELOG.md`.
2. Push a tag:
   ```bash
   git tag v1.5.0 && git push origin v1.5.0
   ```

## License
MIT. See [LICENSE](LICENSE).
