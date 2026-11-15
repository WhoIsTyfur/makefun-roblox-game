--!strict
-- Shared constants: arena size, tuning numbers, enemy kinds and the neon palette.

local Config = {
	ARENA_W = 1000,
	ARENA_H = 600,
	PLAYER_SPEED = 380,
	PLAYER_RADIUS = 16,
	BULLET_SPEED = 720,
	BULLET_RADIUS = 6,
	FIRE_DELAY = 0.2,
	RAPID_DELAY = 0.08,
	RAPID_TIME = 6,
	LIVES = 3,
	INVULN_TIME = 1.6,
	FINAL_WAVE = 6,
	SPAWN_GAP = 0.45,
	INTERMISSION = 1.8,
	SNAPSHOT_RATE = 1 / 30,

	KINDS = {
		drifter = { hp = 1, speed = 150, radius = 18, score = 10, homing = false, color = Color3.fromRGB(255, 45, 170) },
		hunter = { hp = 3, speed = 105, radius = 24, score = 30, homing = true, color = Color3.fromRGB(255, 225, 60) },
	},

	COLORS = {
		bg = Color3.fromRGB(10, 7, 28),
		arena = Color3.fromRGB(18, 12, 46),
		cyan = Color3.fromRGB(0, 229, 255),
		magenta = Color3.fromRGB(255, 45, 170),
		yellow = Color3.fromRGB(255, 225, 60),
		white = Color3.fromRGB(240, 240, 255),
		green = Color3.fromRGB(80, 255, 150),
	},
}

return Config
