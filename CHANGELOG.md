# Swingline

## v1.5.0

- **New: nameplate swing lines.** Thin swing timers on your current target's nameplate. It's off by default; turn it on under *Nameplate* in the sidebar.
  - **Lines:** any of the six timers (yours and your target's), each on or off.
  - **Look:** Flat, Gradient, Classic, Neon Glow or WoW Forever art, with an optional border and spark, filling up or draining.
  - **Colours:** the bars' colours, or your own colour for your lines and one for your target's.
  - **Text:** optional time remaining, with its own font size, plus background opacity.
  - **Size and position:** width (or match the plate), line height, gap, above or below the health bar, and X/Y offsets.
  - **Visibility:** separate on/off settings for solo, in a party and in a raid.
  - **All nearby enemies (optional):** every enemy nameplate gets its own melee and ranged lines. Ranged comes from each enemy's Auto Shot or Shoot. Melee hits are credited to the enemy whose next swing is due, so a pack can be followed once each mob has swung once. A hit that matches nobody is ignored rather than guessed, and lines disappear shortly after a swing is due instead of freezing. Switching target carries that enemy's timers over to the target bars.
- **New: minimap button.** Left-click opens the settings, right-click locks or unlocks the bars, and you can drag it around the minimap. Show or hide it on the General page or with `/swl minimap`.
- Swingline now carries the **[Soeta's]** tag in the AddOns list, the settings window and chat, like the other Soeta addons.
- The settings window is a little taller to fit the new pages.

## v1.3.2

- **New addon icon** in the style of WoW Forever's own swing timer: three beveled bars with stone-bronze fills and bright pips, on a starry night sky with constellations, a blue nebula and a gold rim.
- The CurseForge logo (`Media/Logo.png`) is updated to match.

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
