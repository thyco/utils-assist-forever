# Utils Assist Forever design

Utils Assist Forever is a class-independent addon container for WoW Forever (interface 16001). Its first module is the proven Range Assist Forever range feature. Future utilities can register as separate features with `addon:RegisterFeature`; no future utility behavior is implemented yet.

`Core.lua` owns the addon lifecycle and feature registration. `Bootstrap.lua` provides events, throttled updates and `/uaf`. `Services/Config.lua` stores per-character range preferences under `UtilsAssistForeverDB`; the native AddOns settings category exposes the two range checkboxes. The range feature and its `Client`, `Range`, `Buttons`, `IconTint`, `Macros`, and `NextSwing` services remain separate modules so later utilities can use or leave them alone.

The runtime checks all eight default Blizzard action bars for learned harmful spells. The selected living attackable target takes priority; only when no target is selected is a living attackable mouseover used. An explicit out-of-range answer from the player spellbook API, or from spell ID fallback, tints an icon desaturated red. Unknown or restricted answers keep its native appearance. Melee and ranged checkboxes are independent. The icon service preserves Blizzard's latest color and desaturation during a tint.

Next-swing attacks use a reference spell: Wing Clip for hunters, Hamstring for warriors, and Auto Attack for other classes. Supported simple macros can expose these attacks even when a different spell appears on the button. This is the existing range policy, not a new class gate on the addon. Missing reference data stays neutral.

The old addon is intentionally left unchanged as source history. Installing both at once would make both inspect and tint the same buttons; use the new addon as the replacement. The new addon has a distinct per-character saved variable, so old preferences are not imported. Its defaults enable both checks.

Tests use WoW API/frame doubles and validate classification, eight bars, class behavior, macro parsing, range API fallback, settings and icon restoration. Real Forever rendering, combat restrictions and macro behavior still need in-client validation.
