<p align="center"><img src="Media/Logo.png" width="128" alt="Swingline icon"></p>

# Swingline

Modern, fully customizable weapon swing timers for **WoW Forever**. Each bar has its own settings. Bars can float anywhere on screen or dock to your unit frames.

## Install
- **CurseForge app**: search for *Swingline*.
- **Manual**: download the zip from [Releases](https://github.com/aabotnes/Swingline/releases). Extract it into the Forever client's `Interface\AddOns` folder, so you end up with `AddOns\Swingline\Swingline.toc`.

## Use
- `/swl` opens the settings window. It also opens from the AddOns compartment button by the minimap, or Options > AddOns > Swingline.
- `/swl unlock` and `/swl lock` turn dragging on and off. `/swl test` shows every bar. `/swl reset` restores the defaults.
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
