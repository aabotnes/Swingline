<p align="center"><img src="Media/Logo.png" width="128" alt="Swingline icon"></p>

# Swingline

Modern, fully customizable weapon swing timers for **WoW Forever**. Each bar has its own settings. Bars can float anywhere on screen or dock to your unit frames.

## Install
- **CurseForge app**: search for *Swingline*.
- **Manual**: download the zip from [Releases](https://github.com/aabotnes/Swingline/releases). Extract it into the Forever client's `Interface\AddOns` folder, so you end up with `AddOns\Swingline\Swingline.toc`.

## Use
- `/swl` opens the settings window. It also opens from the AddOns compartment button by the minimap, or Options > AddOns > Swingline.
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
- **Look**: Modern, Minimal Line, Classic, Neon Glow or Centered
- **Size and colour**: width, height, colour and background opacity
- **Text**: time remaining, weapon label and spark, each on or off
- **Fill direction**: fill up or drain

Settings for each bar's position:
- **Anchor to**: free, Player unit frame, Target unit frame, or a custom frame name. Unit frames are detected in this order: ElvUI, Shadowed Unit Frames, PitBull4, oUF, then Blizzard's own frames.
- **Placement**: which side of the frame the bar attaches to, plus X/Y offsets. Dragging a docked bar updates its offsets from the frame it's docked to.

## Group
Set a bar's **Anchor to** to *Swingline group* to make it a member of the group. Member bars keep their own offsets from the group, and the group has its own anchor and X/Y offset. Moving the group moves every member with it.
- **Group settings page**: choose the group's anchor and offset, and which bars are members.
- **Adding or removing a bar**: the bar stays where it is on screen; only its offsets change.
- **Moving the group**: unlock bars, then drag the group by its tab, or Shift-drag any member bar.

## Profiles
Profiles are shared by all your characters, and each character remembers which one it uses. On the **Profiles** page you can create, duplicate, rename, copy from, reset or delete profiles. You can also switch with `/swl profile <name>`.

Built-in profiles:
| Profile | Look |
|---|---|
| Default | Labelled bars below your player and target frames |
| Frame Lines | Hair-thin 2px lines across the top of your unit frames |
| Center Stack | One group under your character, with target bars above yours |
| Neon | Glowing slim bars below your unit frames |
| Classic | Blizzard-style bars with borders, labels and timers |

Built-in profiles can be edited freely. **Reset** brings back the original look, and **Restore built-in profiles** re-adds any you deleted.

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
   git tag v1.0.1 && git push origin v1.0.1
   ```

## License
MIT. See [LICENSE](LICENSE).
