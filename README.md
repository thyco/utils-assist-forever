# Utils Assist Forever

A home for class-independent WoW Forever utilities. Range checks tint spell icons **desaturated red when WoW explicitly reports them out of range**. Queued next-swing attacks gain a bright moving border. Cooldown checks grey actions on a real cooldown or when WoW reports them unusable. Action-bar click-through can disable mouse clicks on chosen bars. A graphics control adjusts grass and ground-effect density. Supports every class and all eight default Blizzard action bars. Version 0.5.1 targets interface **16001**.

## Install

Extract `dist/UtilsAssistForever-0.5.1.zip` into `Interface/AddOns`, producing:

```text
Interface/AddOns/UtilsAssistForever/UtilsAssistForever.toc
```

Enable **Utils Assist Forever** in the AddOns menu. Remove the old Range Assist Forever, GreyOnCooldown and BarNoClicky folders when switching to this combined addon, so they do not manage the same bars. The old repositories remain untouched. Restart the client if the newly installed addon does not appear.

## Settings

Open **Settings → AddOns → Utils Assist Forever**, or `/uaf config`.

The settings groups sit in a scrollable pane, so the lower click-through controls remain reachable even in a smaller Settings window.

The spanner-and-gear icon appears in the AddOns list and beside the settings title.

The **Range checks** group contains two checkboxes, both enabled by default:

- **Check ranged abilities**
- **Check melee abilities**

The **Queued attacks** group has **Highlight queued next-swing attacks**, enabled by default. It adds a cyan moving border when Blizzard marks a supported next-swing button as active. The group also has **Use glow's native color** and a **Custom glow color** swatch. The swatch opens Blizzard's color picker, as in Warrior Assist Forever. Its native option leaves LibCustomGlow's Pixel Glow color untinted, which is yellow; this differs from Blizzard's checked-button texture. Turn off the highlight checkbox to keep only that original Blizzard indicator. Both color choices and the highlight checkbox are saved per character and are independent of range checking.

The **Cooldown greying** group contains four checkboxes:

- **Grey actions on cooldown** — enabled by default; skips the global cooldown.
- **Grey unusable actions** — enabled by default.
- **Grey actions without resources** — disabled by default; extends unusable greying to insufficient resources.
- **Grey pet actions** — enabled by default.

The **Action bar click-through** group contains one checkbox for each of the eight default bars. All are off by default, so bars remain clickable. Enabling a checkbox disables mouse clicks on that bar; key bindings still work. Hold Shift outside combat to temporarily click, move spells or view tooltips on selected bars. Releasing Shift restores each bar's saved choice. Changes made during combat are saved immediately and applied when combat ends.

The **Graphics settings** group contains **Grass & ground-effect density** and its own **Reset to default** button. The slider adjusts WoW's `groundEffectDensity` CVar from 16 to 256 in steps of 8. The displayed current value is read back from the client. Reset restores the default reported by this client for that CVar alone; no default number is hard-coded. The controls are disabled when the CVar is absent, locked, read-only or unavailable for writing in combat. A manual override is reapplied after login and after Blizzard's Ground Clutter preset changes. Until a value is chosen or reset, the addon leaves the client's existing graphic setting alone.

If KelaGraphics remains enabled and also manages `groundEffectDensity`, the last addon to write that CVar determines its live value. Choose the density in one addon.

The utility checkboxes are saved per character in `UtilsAssistForeverDB`. Graphics overrides are saved account-wide in `UtilsAssistForeverGraphicsDB`, as a separate entry for each graphics control. Reset writes the client's default and removes only that control's override. Existing Range Assist Forever, GreyOnCooldown and BarNoClicky settings are not imported; each character starts with the utility defaults above. Changes apply immediately outside combat; protected click-through changes wait until combat ends. Disabling both range checks, queued-attack glow, cooldown greying and all click-through bars stops polling. Each checkbox affects only its category.

## Action bar click-through and combat macros

The click-through feature adapts **BarNoClicky 1.0.6** by mostlyharmlessx. It changes only mouse input on the selected default bars, never their key bindings. Shift temporarily restores mouse interaction outside combat. For the reported stale icon on `[combat]` and `[nocombat]` macros, Utils Assist Forever samples the current action texture while a bar is click-through and refreshes the icon on combat transitions and subsequent polls. It checks the button's live action slot, so paging and moved macros are covered. Non-macro icons and unreadable texture results are left alone. The addon does not parse or execute macro commands for this visual refresh.

Use `/uaf config` to change bars, `/uaf clicky 1-8|all` or `/uaf noclicky 1-8|all` for commands, and `/uaf status` to list every bar. The original `/bnc` and `/barnoclicky` aliases also work (`c`, `nc`, `s` and `o`).

## Cooldown greying

Cooldown greying adapts the behavior of **GreyOnCooldown 2.0.2** by Millán - Sanguino to the Utils Assist Forever settings and icon handling. It checks Blizzard's eight default action bars, extra/override/stance/possess and flyout buttons, Blizzard pet buttons, LibActionButton buttons, Dominos registered buttons, and Bartender4 pet buttons. It uses action cooldown and usability APIs when available, including duration objects on newer clients. When the client explicitly reports a cooldown as inactive, the addon skips its duration-object work. An explicit global cooldown is ignored; older APIs use the active global cooldown or a conservative short-duration threshold. Secret duration objects are requested without the global cooldown and stay grey until the real cooldown expires, including the final second. Unknown or restricted results leave the native icon unchanged. Opaque cooldown curve values are passed through to the icon without comparing them, including when a later update becomes readable. Cooldown and usability events are batched into the next 0.1-second update; a quieter fallback scan runs about every 0.3 seconds.

When both features affect a button, the red range tint takes priority; when range becomes valid, an active cooldown remains grey. The latest native color, alpha and desaturation are restored when both effects clear. Cooldown greying is independent of having a selected target. Pet greying follows its own checkbox and skips short global cooldowns.

The integration uses the attached addon's behavior without its Ace3 libraries, account-wide profiles, addon compartment entry, or separate slash commands. This distribution includes the GPL-3.0 license from the source addon in `LICENSE.txt`.

The melee category includes learned harmful spells whose minimum range is zero and maximum range is at most 5 yards, including zero/zero melee candidates. Other valid learned harmful spells use the ranged setting. This is range-based grouping, not weapon type or class: caster attacks with no minimum range still count as ranged. A spell reported above 5 yards uses the ranged setting even if its combat role is melee. See [classification investigation](docs/design.md) for findings and limitations.

## Range and appearance

A **living attackable selected target** takes priority. Only when **no target is selected** does the addon use a living attackable mouseover. Friendly/dead selected targets block mouseover fallback. Attackable neutral units are eligible.

Each spell is checked by player spellbook slot first, then spell ID if the book check is unavailable, restricted or errors. A readable book result is authoritative. Only explicit `false`/`0` tints an icon. Unknown or restricted final results leave native appearance unchanged, clearing any previous tint. Zero-range metadata alone never produces a tint.

The addon preserves Blizzard's latest native icon color, alpha and desaturation when removing its tint, including changes made while tinted. Prepared buttons work in combat; new buttons first encountered in combat wait until combat ends for preparation.

All eight default bars are covered, including live main-bar paging. Direct spell actions and macros with a client-exposed displayed spell are supported. Ordinary macros use the displayed spell against the chosen target/mouseover. Next-swing macros additionally support body detection as described below; cast sequences are not simulated. Items, pet actions, flyouts, unlearned spells, custom bars and unidentified macros remain native.

Range checking has no deadzone proximity inference, ammo indicator, reactive glow or distance estimate. This is not a facing, line-of-sight, resource or overall castability check. Invalid spell metadata is skipped. Spellbook membership and range metadata are refreshed on relevant events, including talent and form changes.

## Next-swing melee attacks

Next-swing abilities use a class-specific melee range reference, controlled by **Check melee abilities**:

- **Hunter:** Wing Clip, including Raptor Strike buttons and supported combined macros.
- **Warrior:** Hamstring, including Heroic Strike and Cleave buttons and supported combined macros.
- Other classes retain the existing Auto Attack reference (including Maul); its usability as a range reference remains client-dependent.

The reference must be learned. Localized names identify learned ranks through the player spellbook, independently of harmful-spell classification or numeric range metadata. Hunters and warriors never fall back to Auto Attack when their configured reference is missing or unavailable.

This works for direct spell buttons and for simple macros, even when another spell is displayed:

```text
#showtooltip Mongoose Bite
/cast !Raptor Strike
/cast Mongoose Bite
/startattack
```

The addon reads the macro body and recognizes `/cast` and `/use`, their localized aliases, the optional `!` prefix, and explicit learned rank suffixes. `#showtooltip`, `/startattack` and `/stopcasting` can accompany those commands. Conditional cast/use lines use `SecureCmdOptionParse` on each refresh; only the currently selected branch can trigger body detection, and an explicit unit must match the addon's chosen target/mouseover. As elsewhere in this addon, a cast without an explicit unit uses the chosen range-check unit, including the mouseover fallback.

Macro bodies are cached at login and refreshed after edits and spellbook changes. Buttons resolve their current action slot and macro label, so moving macros and paging bars are supported. **Use unique macro names across account and character macros.** Duplicate names, unreadable bodies and macros containing unsupported commands (including `/run`, `/click`, `/stopmacro`, target-changing commands and `/castsequence`) skip body detection and retain displayed-spell behavior. The addon never executes or edits macro text. Macro commands are inspected for range presentation only; this is not a simulation of successful casts or resources.

Recognized next-swing attacks take precedence over the displayed spell for the whole button. This is intended for combined melee macros; a mixed ranged/melee macro with an active next-swing line will also show the class-specific melee reference. When body detection is unavailable, a displayed next-swing spell is still recognizable on its own. When a supported body is readable, an inactive or differently targeted branch cannot be overridden by a next-swing tooltip.

The reference uses the same spellbook-first API and spell-ID fallback, once per refresh across matching buttons. An explicit out-of-range result turns the icon red. Unknown/restricted results or a missing reference restore native appearance; no other melee spell or interaction distance is substituted. The queued ability's own result is not used to override the reference. The reference spell does not need to occupy an action-bar button.

**Auto Attack returned unavailable through both APIs in the reported Forever test, so hunters use Wing Clip and warriors use Hamstring.** This feature reports its API answer, not whether an attack is queued or whether the next swing will hit.

## Queued-attack glow

Heroic Strike, Cleave, Raptor Strike and Maul buttons can show a moving Pixel Glow while Blizzard's own checked action-button indicator is active. The initial custom color is cyan; the native-color option uses Pixel Glow's built-in yellow. The addon recognizes learned next-swing spells on direct actions and supported macro bodies. It then reads the button's native checked state; it does not infer a queue from range, the target, or the spell's usability. The glow clears when the checked state clears, the button changes to another action, the active macro branch changes, or the highlight setting is disabled. Unknown or restricted checked states do not trigger it.

`ACTIONBAR_UPDATE_STATE` drives queue changes; bar, macro, modifier and combat transitions also refresh eligibility. For a macro such as `/cast [combat] Heroic Strike; Shoot Bow`, only the Heroic Strike branch is eligible. The feature scans on those changes and during the existing button-discovery fallback, rather than checking the queued state every 0.1 seconds. Pixel Glow is precreated on default buttons outside combat and hidden until needed, so showing it during combat does not allocate the effect. The glow is a separate mouse-transparent layer and leaves Blizzard's original border and icon appearance intact. LibCustomGlow-1.0 and LibStub are bundled with their licenses.

## Diagnostics

Run `/uaf` for the current unit, enabled categories, button counts, each checked spell's category/range metadata and the status of both range APIs. For next-swing buttons, diagnostics identify the action slot, whether recognition came from the macro body or displayed/direct spell, and the selected reference spell’s API statuses. Diagnostic records and explanations are built only for `/uaf`, not on every range poll. Diagnostics use safe text status labels and do not print restricted values or raw errors. When both categories are disabled, stale range checks are not printed.

## Development

The range feature, secure icon hooks, API test doubles and manifest-based ZIP packaging were migrated from Range Assist Forever. The cooldown feature is adapted from GreyOnCooldown 2.0.2. Click-through is adapted from BarNoClicky 1.0.6. The latter two addons are GPL-3.0 licensed; this distribution includes their license text. KelaGraphics was used only as a reference for the public CVar name and its documented range; none of its proprietary code or assets are included. The features retain separate settings and checks.

```sh
lua tests/run.lua
lua tests/integration.lua
lua tests/next_swing.lua
lua tests/cooldown.lua
lua tests/clickthrough.lua
lua tests/graphics.lua
lua tests/queued_glow.lua
python3 scripts/package.py
```

Lua tests require Lua 5.4; packaging requires Python 3.9+. The addon itself uses WoW-compatible Lua syntax. Range and click-through polling runs every 0.1 seconds; cooldown checks run after relevant events or about every 0.3 seconds when quiet. Button discovery runs every 0.5 seconds and on relevant bar events. Queued glow state is checked on action-state changes and button discovery. Duplicate spell buttons share one range query per refresh. No range queries run without an eligible unit.

## In-game acceptance

Local tests cannot establish actual Forever spell metadata, rendering or secure combat behavior. Verify in the client:

1. Enable Lua errors, reload, and open `/uaf config`. Confirm both checkboxes persist across reloads.
2. With a ranged spell and a melee spell on default bars, move from beyond maximum range into valid range and, for minimum-range spells, too close. Red should follow the spell's explicit range result on either side.
3. Toggle each category independently. Check native low-resource shading and desaturation return when tint clears.
4. Test each class, melee/zero-bound spells, shapeshift forms and changed talents. Use `/uaf` to inspect classification if an individual toggle behaves unexpectedly.
5. Test all eight bars, paging, moved abilities, hidden bars and displayed-spell macros.
6. Check target priority, target clearing, enemy mouseover arrival/departure, and selected friendly/dead targets blocking mouseover fallback.
7. Repeat in combat and watch for Lua errors or blocked-action messages. Verify unknown/restricted range checks restore the native icon.
8. Test a real cooldown, a global cooldown, an unusable action, insufficient resources, and a pet action. Toggle each cooldown setting and confirm normal icon color returns after the cooldown. Check a spell that is both out of range and on cooldown: it should be red first, then grey when range becomes valid.
9. Enable click-through on one bar and confirm mouse clicks pass through while key bindings still activate abilities. Put a macro with combat and no-combat spell branches on that bar; its icon should switch on both combat transitions without hovering over it. Check paging and a different bar left clickable. Toggle click-through during combat and confirm the mouse change applies when combat ends.
10. In Graphics settings, change grass and ground-effect density, reload and confirm the value persists. Change Blizzard's Ground Clutter preset and confirm the manual density returns. Press this setting's Reset button and confirm the displayed value returns to the client's reported default without changing other graphic settings. Repeat on another character to confirm the graphic choice is account-wide.
11. Queue a Heroic Strike, Cleave, Raptor Strike or Maul on a default bar. Confirm the moving border follows Blizzard's original checked indicator, including when the queued attack is cancelled or consumed. Change its color with the Blizzard picker, then select the native-color option and confirm the built-in yellow appearance. Test the `/cast [combat] Heroic Strike; Shoot Bow` macro as combat starts and ends, and verify that disabling the highlight setting removes only the extra glow. Repeat during combat and watch for blocked-action messages.

For the new reference check, put Raptor Strike or Heroic Strike on a bar directly and in a uniquely named combined macro. Run `/uaf` near and far from an enemy, before and after queuing the attack. Confirm diagnostics show `Wing Clip reference` on a hunter or `Hamstring reference` on a warrior (localized on other clients) and, for the combined macro, `macro body`. Repeat in combat and with no selected target plus an enemy mouseover. Edit the macro and verify detection refreshes. If the selected reference is unavailable or does not change with distance, send the `/uaf` output; icons intentionally remain native when the result is unknown.
