# Utils Assist Forever

A home for class-independent WoW Forever utilities. Its first feature is a range check that tints spell icons **desaturated red when WoW explicitly reports them out of range**, whether too close or too far. Supports every class and all eight default Blizzard action bars. Version 0.1.0 targets interface **16001**.

## Install

Extract `dist/UtilsAssistForever-0.1.0.zip` into `Interface/AddOns`, producing:

```text
Interface/AddOns/UtilsAssistForever/UtilsAssistForever.toc
```

Enable **Utils Assist Forever** in the AddOns menu. Replace the old Range Assist Forever folder rather than loading both addons together: each would otherwise inspect and color the same buttons. The old repository remains untouched. Restart the client if the newly installed addon does not appear.

## Settings

Open **Settings → AddOns → Utils Assist Forever**, or `/uaf config`.

The **Range checks** group contains exactly two checkboxes, both enabled by default:

- **Check ranged abilities**
- **Check melee abilities**

Preferences are saved separately for each character in `UtilsAssistForeverDB`. Existing Range Assist Forever settings are not imported; each character starts with both checks enabled. Changes apply immediately; disabling both stops polling and restores icons. Each checkbox affects only its category.

The melee category includes learned harmful spells whose minimum range is zero and maximum range is at most 5 yards, including zero/zero melee candidates. Other valid learned harmful spells use the ranged setting. This is range-based grouping, not weapon type or class: caster attacks with no minimum range still count as ranged. A spell reported above 5 yards uses the ranged setting even if its combat role is melee. See [classification investigation](docs/design.md) for findings and limitations.

## Range and appearance

A **living attackable selected target** takes priority. Only when **no target is selected** does the addon use a living attackable mouseover. Friendly/dead selected targets block mouseover fallback. Attackable neutral units are eligible.

Each spell is checked by player spellbook slot first, then spell ID if the book check is unavailable, restricted or errors. A readable book result is authoritative. Only explicit `false`/`0` tints an icon. Unknown or restricted final results leave native appearance unchanged, clearing any previous tint. Zero-range metadata alone never produces a tint.

The addon preserves Blizzard's latest native icon color, alpha and desaturation when removing its tint, including changes made while tinted. Prepared buttons work in combat; new buttons first encountered in combat wait until combat ends for preparation.

All eight default bars are covered, including live main-bar paging. Direct spell actions and macros with a client-exposed displayed spell are supported. Ordinary macros use the displayed spell against the chosen target/mouseover. Next-swing macros additionally support body detection as described below; cast sequences are not simulated. Items, pet actions, flyouts, unlearned spells, custom bars and unidentified macros remain native.

There is no deadzone proximity inference, ammo indicator, reactive glow or distance estimate. This is not a facing, line-of-sight, resource or overall castability check. Invalid spell metadata is skipped. Spellbook membership and range metadata are refreshed on relevant events, including talent and form changes.

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

## Diagnostics

Run `/uaf` for the current unit, enabled categories, button counts, each checked spell's category/range metadata and the status of both range APIs. For next-swing buttons, diagnostics identify the action slot, whether recognition came from the macro body or displayed/direct spell, and the selected reference spell’s API statuses. Diagnostics use safe text status labels and do not print restricted values or raw errors. When both categories are disabled, stale range checks are not printed.

## Development

The range feature, secure icon hooks, API test doubles and manifest-based ZIP packaging were migrated from Range Assist Forever. The addon namespace, settings, command, and package now belong to Utils Assist Forever. The feature registry in `Core.lua` permits later utility features; only range checks are present today.

```sh
lua tests/run.lua
lua tests/integration.lua
lua tests/next_swing.lua
python3 scripts/package.py
```

Lua tests require Lua 5.4; packaging requires Python 3.9+. The addon itself uses WoW-compatible Lua syntax. Polling runs every 0.1 seconds; default-button discovery runs every 0.5 seconds and on relevant bar events. Duplicate spell buttons share one query per refresh. No range queries run without an eligible unit.

## In-game acceptance

Local tests cannot establish actual Forever spell metadata, rendering or secure combat behavior. Verify in the client:

1. Enable Lua errors, reload, and open `/uaf config`. Confirm both checkboxes persist across reloads.
2. With a ranged spell and a melee spell on default bars, move from beyond maximum range into valid range and, for minimum-range spells, too close. Red should follow the spell's explicit range result on either side.
3. Toggle each category independently. Check native low-resource shading and desaturation return when tint clears.
4. Test each class, melee/zero-bound spells, shapeshift forms and changed talents. Use `/uaf` to inspect classification if an individual toggle behaves unexpectedly.
5. Test all eight bars, paging, moved abilities, hidden bars and displayed-spell macros.
6. Check target priority, target clearing, enemy mouseover arrival/departure, and selected friendly/dead targets blocking mouseover fallback.
7. Repeat in combat and watch for Lua errors or blocked-action messages. Verify unknown/restricted range checks restore the native icon.

For the new reference check, put Raptor Strike or Heroic Strike on a bar directly and in a uniquely named combined macro. Run `/uaf` near and far from an enemy, before and after queuing the attack. Confirm diagnostics show `Wing Clip reference` on a hunter or `Hamstring reference` on a warrior (localized on other clients) and, for the combined macro, `macro body`. Repeat in combat and with no selected target plus an enemy mouseover. Edit the macro and verify detection refreshes. If the selected reference is unavailable or does not change with distance, send the `/uaf` output; icons intentionally remain native when the result is unknown.
