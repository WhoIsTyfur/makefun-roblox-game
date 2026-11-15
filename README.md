[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![rank](https://make.fun/badge/roblox-game-01/WhoIsTyfur/makefun-roblox-game/rank.svg)](https://make.fun/bounty/roblox-game-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![reward](https://make.fun/badge/roblox-game-01/WhoIsTyfur/makefun-roblox-game/reward.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

Entry for the [make.fun "Make the best Roblox game" bounty](https://make.fun/bounty/roblox-game-01).
# Void Bloom

A neon arcade shooter for Roblox, drawn entirely with GUI shapes. Survive six waves: dodge drifters, shoot down tougher hunters, and grab rapid-fire pickups between waves.

- `src/shared/Config.luau`: tuning numbers and palette.
- `src/server/Round.server.luau`: authoritative game state (movement, shots, collisions, lives, score, win/loss).
- `src/server/Spawner.luau`: wave queues and enemy movement.
- `src/client/Hud.client.luau`: input, HUD, title and end screens, feedback.

Scoring: the entry is a published Roblox place judged by make.fun's AI judge on screenshots and script outline.

Run locally: `rojo build -o game.rbxl`, then `MAKEFUN_OUTPUT_DIR=out node main.ts`.
