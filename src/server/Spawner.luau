--!strict
-- Enemy waves: queues a wave's enemies, releases them from the arena edge, and moves them each tick.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Spawner = {}
local rng = Random.new()

function Spawner.spawnWave(session: any, wave: number)
	local queue = {}
	for _ = 1, 4 + wave * 2 do
		table.insert(queue, "drifter")
	end
	for _ = 1, wave - 1 do
		table.insert(queue, "hunter")
	end
	for i = #queue, 2, -1 do
		local j = rng:NextInteger(1, i)
		queue[i], queue[j] = queue[j], queue[i]
	end
	session.queue = queue
	session.spawnCd = 0.5
end

local function placeAtEdge(kind: string)
	local w, h = Config.ARENA_W, Config.ARENA_H
	local side = rng:NextInteger(1, 4)
	local x, y = rng:NextNumber(0, w), rng:NextNumber(0, h)
	if side == 1 then
		y = -20
	elseif side == 2 then
		y = h + 20
	elseif side == 3 then
		x = -20
	else
		x = w + 20
	end
	return { kind = kind, x = x, y = y, hp = Config.KINDS[kind].hp, vx = 0, vy = 0 }
end

function Spawner.stepEnemies(session: any, dt: number)
	session.spawnCd -= dt
	if session.spawnCd <= 0 and #session.queue > 0 then
		local kind = table.remove(session.queue) :: string
		local enemy = placeAtEdge(kind)
		-- drifters aim at a point near the player when spawned and keep going straight
		local dx, dy = session.p.x - enemy.x, session.p.y - enemy.y
		local len = math.max(math.sqrt(dx * dx + dy * dy), 1)
		enemy.vx, enemy.vy = dx / len, dy / len
		table.insert(session.enemies, enemy)
		session.spawnCd = Config.SPAWN_GAP
	end
	for _, e in session.enemies do
		local def = Config.KINDS[e.kind]
		if def.homing then
			local dx, dy = session.p.x - e.x, session.p.y - e.y
			local len = math.max(math.sqrt(dx * dx + dy * dy), 1)
			e.vx, e.vy = dx / len, dy / len
		end
		e.x += e.vx * def.speed * dt
		e.y += e.vy * def.speed * dt
	end
end

return Spawner
