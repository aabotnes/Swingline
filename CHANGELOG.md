# Swingline

## v1.3.1

- **WoW Forever is now the default look and profile** for new characters and "New (defaults)". Clients without the game's swing bar art fall back to Classic.
- **WoW Forever profile retuned** to match the game's own bars, the same for player and target:
  - each group sits directly below its unit frame
  - bars are 213x30, attached below the group at Y -70, -100 and -130
- Classic, Minimalistic, Center Stack and Neon keep their own sizes and spacing.
- If you already have a WoW Forever profile, choose *Reset current profile* to pick up the new layout.

## v1.3.0

- **New look: WoW Forever.** Uses the game's own swing timer art (`ui-swingtimerbar-*`) with the same insets, pip and font as the built-in bars. Like the game's bars, it dims and turns red when you're out of range. A button sets a bar to the game's own size.
- **New option: Hide the game's own swing bars.** It's on the General page and controls the `showSwingTimer` setting.
- **Two groups:** one for player bars and one for target bars, each anchored to its unit frame. Each has a *Group* page in the sidebar. Shift-drag moves a bar's own group.
- **Profiles:**
  - Every built-in profile now anchors bars to the player and target groups.
  - **Classic** is the default for new characters and for "New (defaults)".
  - *Frame Lines* is renamed **Minimalistic**.
  - New **WoW Forever** profile.
- Bar labels use the game's own (localized) swing timer names.
- **Upgrading:**
  - A v1.1/1.2 single group becomes the player group.
  - Built-in profiles are rebuilt for the new layout. If a character was using one, the old version is kept as "*name* (backup)".

## v1.2.0

- **New: profiles.** Profiles are shared account-wide, and each character remembers which one it uses. You can create a new profile, duplicate, rename, copy from another profile, reset or delete. Switch profiles on the Profiles page, from General, or with `/swl profile <name>`.
- **Built-in profiles:**
  - *Default*
  - *Frame Lines*: 2px lines across the top of your unit frames
  - *Center Stack*: one group under your character
  - *Neon*
  - *Classic*

  Resetting a built-in profile brings back its original look. *Restore built-in profiles* re-adds any you deleted.
- Your existing settings carry over as the *Default* profile.
- The settings header now shows the active profile.
- `/swl reset` now resets only the active profile.

## v1.1.0

- **New: Swingline group.** Any bar can anchor to the group. The group has its own anchor (free, player frame, target frame or a custom frame), its own attachment point and an X/Y offset, so moving the group moves all its members together.
- Member bars keep their own offsets from the group.
- When bars are unlocked, the group shows an outline and a drag tab. You can also Shift-drag any member bar to move the whole group.
- New **Group** settings page: group anchor, a toggle for each bar's membership, and Add all / Remove all buttons.
- Changing what a bar is anchored to no longer moves it on screen. Its offsets are recalculated from where it currently sits.

## v1.0.0

First release.

- Swing timers for your main hand (or two-hander), off hand and ranged weapon, driven by WoW Forever's native `PLAYER_SWING` event.
- Estimated swing timers for your target's main hand, off hand and ranged attacks.
- Five looks: Modern, Minimal Line, Classic, Neon Glow and Centered.
- Each bar has its own width, height, colour, background opacity, fill direction, text, label and spark settings.
- Bars can be docked to the player or target unit frame. ElvUI, Shadowed Unit Frames, PitBull4 and oUF are detected, and any other frame can be named. Each docked bar has a side setting and X/Y offsets, or can be dragged by hand.
- Bars dim when your target is out of swing range.
- New settings window: open it with `/swl`, from the AddOns compartment, or from Options > AddOns.
