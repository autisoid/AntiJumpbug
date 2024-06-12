# AntiJumpbug
This plugin works very similar as `https://github.com/wootguy/AntiCheat`'s jumpbug detection does, but with some differences and without needing to have metamod installed.

This plugin also gets in count `mp_falldamage` ConVar values, so if it's `-1` the jumpbug check won't kick in and if it's `2` only `10` damage will be applied, otherwise we calculate the falldamage on our own instead of killing the player, unlike wootguy's anticheat.
