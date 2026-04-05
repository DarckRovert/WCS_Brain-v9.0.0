# API Guide — WCS_Brain 🛠️

> **Technical integration guide for the Warlock Control System ecosystem.**

WCS_Brain exposes a public API for inter-addon communication via global functions and protected table structures.

---

## Global Access Table 🌐

The main API is accessible through the `WCS_API` global table.

```lua
-- Example: Check if WCS_Brain is ready
if WCS_API and WCS_API.IsReady() then
    print("WCS_Brain core is active.")
end
```

---

## Player State & IA 🧠

### `WCS_API.GetOptimalAction()`
Returns the name of the spell or action suggested by the DQN engine for the current combat state.

- **Returns**: `string` (Spell Name) or `nil` (No suggestion).

### `WCS_API.SetReward(value)`
Sends a reward signal (numerical) to the learning engine. Useful for external modules (e.g., threat meters) to influence AI training.

- **Parameters**: `value` (Number, -1.0 to 1.0).

---

## Clan & Social 👥

### `WCS_API.GetClanRank(playerName)`
Returns the current rank within the El Séquito del Terror hierarchy.

- **Parameters**: `playerName` (String).
- **Returns**: `string` (Rank Name) or `nil`.

### `WCS_API.BroadcastSync(prefix, data)`
Sends a payload via the P2P sync channel (`WCS_SYNC`) to all clan members in the current group/raid.

- **Parameters**: 
    - `prefix` (String, 4 chars max).
    - `data` (Table, serializable).

---

## Events Manager 📡

Instead of registering raw WoW events, addons should use the prioritized WCS Event Manager to minimize CPU impact.

```lua
WCS_API.RegisterEvent("UNIT_HEALTH", function(unit)
    WCS_API.LogDebug("Unit health changed: " .. unit)
end, "PRIORITY_HIGH")
```

---

## Constants Reference 📜

| Constant | Description |
|---|---|
| `WCS_V_MAJOR` | Current Major Version |
| `WCS_V_MINOR` | Current Minor Version |
| `WCS_CORE_CHANNEL` | `"WCS_SYNC"` |
| `WCS_SHARD_ID` | `6265` (Soul Shard Item ID) |

---
*Technical English — Standard Lua 5.0 for Turtle WoW.*
© 2026 **DarckRovert**.
