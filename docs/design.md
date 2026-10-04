# Utils Assist Forever design

Utils Assist Forever is a class-independent addon container for WoW Forever (interface 16001). It combines the migrated Range Assist Forever checks with cooldown greying adapted from GreyOnCooldown 2.0.2 and bar click-through adapted from BarNoClicky 1.0.6. Future utilities can register as separate features with `addon:RegisterFeature`.

`Core.lua` owns the addon lifecycle and feature registration. `Bootstrap.lua` provides events, throttled updates and `/uaf`. `Services/Config.lua` stores per-character preferences under `UtilsAssistForeverDB`; the native AddOns settings category exposes range, cooldown and click-through groups. Range and cooldown share `Buttons` and `IconTint`, while click-through uses `Buttons` and leaves icon color to the other features.

The runtime checks all eight default Blizzard action bars for learned harmful spells. The selected living attackable target takes priority; only when no target is selected is a living attackable mouseover used. An explicit out-of-range answer from the player spellbook API, or from spell ID fallback, tints an icon desaturated red. Unknown or restricted answers keep its native appearance. Melee and ranged checkboxes are independent. The icon service preserves Blizzard's latest color and desaturation during a tint.

Next-swing attacks use a reference spell: Wing Clip for hunters, Hamstring for warriors, and Auto Attack for other classes. Supported simple macros can expose these attacks even when a different spell appears on the button. This is the existing range policy, not a new class gate on the addon. Missing reference data stays neutral.

Cooldown checks use action, spell and pet usability/cooldown APIs, with duration-object handling on newer clients. They skip the global cooldown and can optionally grey resource shortages or pet actions. Range red has priority over cooldown grey; clearing both layers restores the latest native icon appearance. Default Blizzard bars, extra/override/stance/possess and flyout buttons, LibActionButton, Dominos and Bartender4 pet buttons are discovered independently of the range feature.

Click-through changes mouse input on selected default bars outside combat. Settings changes in combat are saved and applied on `PLAYER_REGEN_ENABLED`. The feature also refreshes macro icon textures from the current action slot on combat transitions and polls while click-through is enabled. It leaves non-macro buttons and unknown textures untouched.

The old range addon and the attached GreyOnCooldown and BarNoClicky addons are left unchanged. The combined addon replaces all three at installation. Old preferences are not imported. Source attribution and GPL-3.0 license text are included with this distribution; Ace3 and its account-wide profiles are not required.

Tests use WoW API/frame doubles and validate classification, eight bars, class behavior, macro parsing, range API fallback, cooldown and usability decisions, click-through behavior, settings and icon restoration. Real Forever rendering, combat restrictions and macro behavior still need in-client validation.
