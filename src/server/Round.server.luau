--!strict
-- Authoritative game state. One session per player: input in, snapshots out. The client only draws.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Spawner = require(script.Parent.Spawner)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local startEvent = Instance.new("RemoteEvent")
startEvent.Name = "Start"
startEvent.Parent = remotes
local inputEvent = Instance.new("RemoteEvent")
inputEvent.Name = "Input"
inputEvent.Parent = remotes
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State"
stateEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

local sessions: { [Player]: any } = {}

local function newSession(): any
	return {
		phase = "title", -- title | play | over
		won = false,
		p = { x = Config.ARENA_W / 2, y = Config.ARENA_H / 2 },
		input = { mx = 0, my = 0, ax = Config.ARENA_W / 2, ay = 0 },
		enemies = {},
		bullets = {},
		pickup = nil,
		queue = {},
		spawnCd = 0,
		fireCd = 0,
		rapid = 0,
		invuln = 0,
		intermission = 0,
		score = 0,
		lives = Config.LIVES,
		wave = 0,
		fx = 0,
		fxKind = "",
		sendCd = 0,
	}
end

local function flash(s: any, kind: string)
	s.fx += 1
	s.fxKind = kind
end

local function startRun(s: any)
	local fresh = newSession()
	for k, v in fresh do
		s[k] = v
	end
	s.phase = "play"
	s.wave = 1
	Spawner.spawnWave(s, 1)
	flash(s, "wave")
end

local function awardScore(s: any, points: number)
	s.score += points
end

local function endRound(s: any, won: boolean)
	s.phase = "over"
	s.won = won
	flash(s, won and "win" or "lose")
end

local function loseLife(s: any)
	s.lives -= 1
	s.invuln = Config.INVULN_TIME
	flash(s, "hit")
	if s.lives <= 0 then
		endRound(s, false)
	end
end

local function nextWave(s: any)
	if s.wave >= Config.FINAL_WAVE then
		endRound(s, true)
		return
	end
	s.wave += 1
	Spawner.spawnWave(s, s.wave)
	s.pickup = {
		x = math.random(80, Config.ARENA_W - 80),
		y = math.random(80, Config.ARENA_H - 80),
	}
	flash(s, "wave")
end

local function fireBullet(s: any)
	local dx, dy = s.input.ax - s.p.x, s.input.ay - s.p.y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1 then
		return
	end
	table.insert(s.bullets, {
		x = s.p.x,
		y = s.p.y,
		vx = dx / len * Config.BULLET_SPEED,
		vy = dy / len * Config.BULLET_SPEED,
	})
	s.fireCd = if s.rapid > 0 then Config.RAPID_DELAY else Config.FIRE_DELAY
end

local function near(ax: number, ay: number, bx: number, by: number, r: number): boolean
	local dx, dy = ax - bx, ay - by
	return dx * dx + dy * dy < r * r
end

local function stepBullets(s: any, dt: number)
	for i = #s.bullets, 1, -1 do
		local b = s.bullets[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		local dead = b.x < -20 or b.x > Config.ARENA_W + 20 or b.y < -20 or b.y > Config.ARENA_H + 20
		for j = #s.enemies, 1, -1 do
			local e = s.enemies[j]
			local def = Config.KINDS[e.kind]
			if not dead and near(b.x, b.y, e.x, e.y, def.radius + Config.BULLET_RADIUS) then
				dead = true
				e.hp -= 1
				if e.hp <= 0 then
					awardScore(s, def.score)
					table.remove(s.enemies, j)
					flash(s, "kill")
				end
			end
		end
		if dead then
			table.remove(s.bullets, i)
		end
	end
end

local function stepCollisions(s: any)
	if s.invuln <= 0 then
		for _, e in s.enemies do
			if near(e.x, e.y, s.p.x, s.p.y, Config.KINDS[e.kind].radius + Config.PLAYER_RADIUS) then
				loseLife(s)
				break
			end
		end
	end
	if s.pickup and near(s.pickup.x, s.pickup.y, s.p.x, s.p.y, 34) then
		s.pickup = nil
		s.rapid = Config.RAPID_TIME
		awardScore(s, 50)
		flash(s, "pickup")
	end
end

local function stepSession(s: any, dt: number)
	local i = s.input
	s.p.x = math.clamp(s.p.x + i.mx * Config.PLAYER_SPEED * dt, 20, Config.ARENA_W - 20)
	s.p.y = math.clamp(s.p.y + i.my * Config.PLAYER_SPEED * dt, 20, Config.ARENA_H - 20)
	s.invuln = math.max(s.invuln - dt, 0)
	s.rapid = math.max(s.rapid - dt, 0)
	s.fireCd -= dt
	if s.fireCd <= 0 then
		fireBullet(s)
	end
	Spawner.stepEnemies(s, dt)
	stepBullets(s, dt)
	stepCollisions(s)
	if s.phase == "play" and #s.queue == 0 and #s.enemies == 0 then
		s.intermission += dt
		if s.intermission >= Config.INTERMISSION then
			s.intermission = 0
			nextWave(s)
		end
	end
end

local function sendSnapshot(player: Player, s: any)
	local enemies = {}
	for _, e in s.enemies do
		table.insert(enemies, { math.round(e.x), math.round(e.y), e.kind })
	end
	local bullets = {}
	for _, b in s.bullets do
		table.insert(bullets, { math.round(b.x), math.round(b.y) })
	end
	local snapshot = {
		phase = s.phase,
		won = s.won,
		score = s.score,
		lives = s.lives,
		wave = s.wave,
		finalWave = Config.FINAL_WAVE,
		px = math.round(s.p.x),
		py = math.round(s.p.y),
		invuln = s.invuln > 0,
		rapid = s.rapid,
		enemies = enemies,
		bullets = bullets,
		pickup = s.pickup,
		fx = s.fx,
		fxKind = s.fxKind,
	}
	local ok, err = pcall(function()
		stateEvent:FireClient(player, snapshot)
	end)
	if not ok then
		warn("snapshot failed: " .. tostring(err))
	end
end

local function readNumber(v: any, lo: number, hi: number, fallback: number): number
	if typeof(v) ~= "number" or v ~= v then
		return fallback
	end
	return math.clamp(v, lo, hi)
end

inputEvent.OnServerEvent:Connect(function(player, mx, my, ax, ay)
	local s = sessions[player]
	if not s then
		return
	end
	local x, y = readNumber(mx, -1, 1, 0), readNumber(my, -1, 1, 0)
	local len = math.sqrt(x * x + y * y)
	if len > 1 then
		x, y = x / len, y / len
	end
	s.input.mx, s.input.my = x, y
	s.input.ax = readNumber(ax, 0, Config.ARENA_W, s.p.x)
	s.input.ay = readNumber(ay, 0, Config.ARENA_H, s.p.y)
end)

startEvent.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if s and s.phase ~= "play" then
		startRun(s)
	end
end)

Players.PlayerAdded:Connect(function(player)
	sessions[player] = newSession()
end)
Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
for _, player in Players:GetPlayers() do
	sessions[player] = newSession()
end

RunService.Heartbeat:Connect(function(dt)
	for player, s in sessions do
		if s.phase == "play" then
			stepSession(s, dt)
		end
		s.sendCd -= dt
		if s.sendCd <= 0 then
			s.sendCd = Config.SNAPSHOT_RATE
			sendSnapshot(player, s)
		end
	end
end)
