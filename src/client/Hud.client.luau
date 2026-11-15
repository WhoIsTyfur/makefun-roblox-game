--!strict
-- Client: sends input and draws the server's snapshots as neon GUI shapes. Behind the menus an attract-mode
-- demo plays so the title and end screens show the real game. No game rules live here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local C = Config.COLORS
local W, H = Config.ARENA_W, Config.ARENA_H
local CENTER = Vector2.new(0.5, 0.5)
local FULL = UDim2.fromScale(1, 1)
local ARENA_HOME = UDim2.fromScale(0.5, 0.56)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startEvent = remotes:WaitForChild("Start") :: RemoteEvent
local inputEvent = remotes:WaitForChild("Input") :: RemoteEvent
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local rng = Random.new()

local gui = Instance.new("ScreenGui")
gui.Name = "VoidBloom"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Building blocks ------------------------------------------------------------------------------

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst: any = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(inst, info, props):Play()
end

local function glow(parent: Instance, thickness: number, transparency: number, from: Color3, to: Color3): any
	local stroke = make("UIStroke", { Color = C.white, Thickness = thickness, Transparency = transparency }, parent)
	make("UIGradient", { Color = ColorSequence.new(from, to) }, stroke)
	return stroke
end

local function label(text: string, size: number, color: Color3, pos: UDim2, parent: Instance, box: UDim2?): any
	return make("TextLabel", {
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		BackgroundTransparency = 1,
		AnchorPoint = CENTER,
		Position = pos,
		Size = box or UDim2.fromScale(0.9, 0.1),
		TextWrapped = true,
		TextStrokeTransparency = 0.5,
	}, parent)
end

local function buildShip(parent: Instance, size: UDim2, color: Color3): any
	local root = make("Frame", { AnchorPoint = CENTER, BackgroundTransparency = 1, Size = size }, parent)
	local wing = color:Lerp(C.bg, 0.45)
	local parts = {
		{ 0.22, 0.66, 0.34, 0.56, -22, wing },
		{ 0.78, 0.66, 0.34, 0.56, 22, wing },
		{ 0.5, 0.5, 0.34, 0.92, 0, color },
		{ 0.5, 0.36, 0.18, 0.26, 0, C.white },
	}
	for _, p in parts do
		local f = make("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(p[1], p[2]),
			Size = UDim2.fromScale(p[3], p[4]),
			Rotation = p[5],
			BackgroundColor3 = p[6],
		}, root)
		make("UICorner", { CornerRadius = UDim.new(0.4, 0) }, f)
	end
	return root
end

local function buildEnemy(kind: string, parent: Instance): any
	local color = Config.KINDS[kind].color
	local root = make("Frame", { AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 3 }, parent)
	local parts = if kind == "hunter"
		then { { 0.66, 0, color, 0 }, { 0.66, 45, color, 0 }, { 0.3, 0, C.magenta, 1 } }
		else { { 0.7, 45, color, 0 }, { 0.3, 45, C.bg, 0 } }
	for _, p in parts do
		local f = make("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(p[1], p[1]),
			Rotation = p[2],
			BackgroundColor3 = p[3],
		}, root)
		make("UICorner", { CornerRadius = UDim.new(p[4] * 0.5, 0) }, f)
		if p[3] == color then
			make("UIStroke", { Color = C.white, Thickness = 2, Transparency = 0.5 }, f)
		end
	end
	return root
end

-- Background: starfield, arena grid, vignette -----------------------------------------------------

make("Frame", { Size = FULL, BackgroundColor3 = C.bg }, gui)
local stars: { any } = {}
for i = 1, 70 do
	local layer = (i % 3) + 1
	local star = {
		x = rng:NextNumber(),
		y = rng:NextNumber(),
		speed = layer * 0.012,
		frame = make("Frame", {
			AnchorPoint = CENTER,
			BackgroundColor3 = if layer == 3 then C.cyan elseif layer == 2 then C.magenta else C.white,
			BackgroundTransparency = 0.7 - layer * 0.12,
			Size = UDim2.fromOffset(layer * 2, layer * 2),
		}, gui),
	}
	table.insert(stars, star)
end

local arena = make("Frame", {
	AnchorPoint = CENTER,
	Position = ARENA_HOME,
	Size = UDim2.fromScale(0.96, 0.84),
	BackgroundColor3 = C.arena,
	BackgroundTransparency = 0.15,
	ClipsDescendants = true,
}, gui)
make("UIAspectRatioConstraint", { AspectRatio = W / H }, arena)
local border = make("UIStroke", { Color = C.cyan, Thickness = 3 }, arena)
for i = 1, 9 do
	make("Frame", {
		Position = UDim2.fromScale(i / 10, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = C.cyan,
		BackgroundTransparency = 0.88,
		ZIndex = 1,
	}, arena)
end
for j = 1, 5 do
	make("Frame", {
		Position = UDim2.fromScale(0, j / 6),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.cyan,
		BackgroundTransparency = 0.88,
		ZIndex = 1,
	}, arena)
end

local vignette = {
	{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), 90 },
	{ UDim2.fromScale(0, 0.8), UDim2.fromScale(1, 0.2), 270 },
	{ UDim2.fromScale(0, 0), UDim2.fromScale(0.14, 1), 0 },
	{ UDim2.fromScale(0.86, 0), UDim2.fromScale(0.14, 1), 180 },
}
for _, v in vignette do
	local edge = make("Frame", { Position = v[1], Size = v[2], BackgroundColor3 = Color3.fromRGB(3, 2, 12) }, gui)
	make("UIGradient", { Rotation = v[3], Transparency = NumberSequence.new(0.1, 1) }, edge)
end

-- Arena actors: ship, pickup, pools, particles ------------------------------------------------------

local ship = buildShip(arena, UDim2.fromScale(Config.PLAYER_RADIUS * 2.6 / W, Config.PLAYER_RADIUS * 2.6 / H), C.cyan)
ship.ZIndex = 5
local pickup = make("Frame", {
	AnchorPoint = CENTER,
	BackgroundColor3 = C.yellow,
	Size = UDim2.fromScale(34 / W, 34 / H),
	Visible = false,
	ZIndex = 2,
}, arena)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, pickup)
make("UIStroke", { Color = C.white, Thickness = 3, Transparency = 0.2 }, pickup)

local enemyPools: { [string]: { any } } = { drifter = {}, hunter = {} }
local bulletPool: { any } = {}
local particles: { any } = {}
local freeParticles: { any } = {}

local function emit(x: number, y: number, vx: number, vy: number, size: number, color: Color3, life: number)
	local p = table.remove(freeParticles)
	if not p then
		p = { frame = make("Frame", { AnchorPoint = CENTER, ZIndex = 6 }, arena) }
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, p.frame)
	end
	p.x, p.y, p.vx, p.vy, p.size, p.life, p.max = x, y, vx, vy, size, life, life
	p.frame.BackgroundColor3 = color
	p.frame.Visible = true
	table.insert(particles, p)
end

local function burst(x: number, y: number, color: Color3, count: number)
	for _ = 1, count do
		local angle, speed = rng:NextNumber(0, math.pi * 2), rng:NextNumber(120, 380)
		emit(x, y, math.cos(angle) * speed, math.sin(angle) * speed, 13, color, 0.5)
	end
end

local function popScore(x: number, y: number, points: number, color: Color3)
	local text = make("TextLabel", {
		Text = "+" .. points,
		TextSize = 34,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		BackgroundTransparency = 1,
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(x / W, y / H),
		Size = UDim2.fromOffset(160, 44),
		ZIndex = 7,
	}, arena)
	tween(text, 0.7, { Position = UDim2.fromScale(x / W, (y - 70) / H), TextTransparency = 1, TextStrokeTransparency = 1 })
	Debris:AddItem(text, 0.8)
end

local function acquire(pool: { any }, index: number, build: () -> any): any
	local shape = pool[index]
	if not shape then
		shape = build()
		pool[index] = shape
	end
	shape.Visible = true
	return shape
end

local function hideFrom(pool: { any }, from: number)
	for i = from, #pool do
		pool[i].Visible = false
	end
end

local function buildBullet(): any
	local b = make("Frame", {
		AnchorPoint = CENTER,
		BackgroundColor3 = C.white,
		Size = UDim2.fromScale(Config.BULLET_RADIUS * 2.8 / W, Config.BULLET_RADIUS * 2.8 / H),
		ZIndex = 4,
	}, arena)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	make("UIStroke", { Color = C.cyan, Thickness = 3, Transparency = 0.2 }, b)
	return b
end

-- HUD (play only), banner, flashes ---------------------------------------------------------------------

local hud = make("Frame", { Size = FULL, BackgroundTransparency = 1, Visible = false }, gui)
local scoreText = label("SCORE 0", 48, C.white, UDim2.fromScale(0.5, 0.05), hud, UDim2.fromScale(0.4, 0.08))
local scoreScale = make("UIScale", {}, scoreText)
local waveText = label("WAVE 1 / 6", 30, C.cyan, UDim2.fromScale(0.5, 0.108), hud, UDim2.fromScale(0.4, 0.05))
local livesBox = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0.97, 0.062),
	Size = UDim2.fromScale(0.3, 0.09),
	BackgroundTransparency = 1,
}, hud)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
}, livesBox)
local lifeIcons = {}
for i = 1, Config.LIVES do
	lifeIcons[i] = buildShip(livesBox, UDim2.fromOffset(46, 46), C.cyan)
end
local rapidText = label("", 28, C.yellow, UDim2.fromScale(0.82, 0.125), hud, UDim2.fromScale(0.3, 0.05))
rapidText.TextXAlignment = Enum.TextXAlignment.Right

local hitFlash = make("Frame", { Size = FULL, BackgroundColor3 = C.magenta, BackgroundTransparency = 1 }, gui)
local banner = label("", 120, C.white, UDim2.fromScale(0.5, 0.5), gui, UDim2.fromScale(0.9, 0.25))
banner.TextTransparency = 1
banner.TextStrokeTransparency = 1
local bannerScale = make("UIScale", {}, banner)
make("UIGradient", { Color = ColorSequence.new(C.cyan, C.magenta) }, banner)
local bannerStroke = glow(banner, 7, 1, C.magenta, C.cyan)
local bannerToken = 0

local function showBanner(text: string)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextTransparency = 0
	bannerStroke.Transparency = 0.25
	bannerScale.Scale = 2.4
	tween(bannerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.2, function()
		if token == bannerToken then
			tween(banner, 0.4, { TextTransparency = 1 })
			tween(bannerStroke, 0.4, { Transparency = 1 })
		end
	end)
end

-- Menus: title and end screens share one panel ------------------------------------------------------------

local overlay = make("Frame", { Size = FULL, BackgroundTransparency = 1 }, gui)
local panel = make("Frame", {
	AnchorPoint = CENTER,
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(0.72, 0.8),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.3,
}, overlay)
make("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
glow(panel, 3, 0.15, C.cyan, C.magenta)
local panelScale = make("UIScale", {}, panel)

local title = label("VOID BLOOM", 96, C.white, UDim2.fromScale(0.5, 0.36), panel, UDim2.fromScale(0.9, 0.2))
local titleGradient = make("UIGradient", { Color = ColorSequence.new(C.cyan, C.magenta) }, title)
glow(title, 6, 0.35, C.magenta, C.cyan)

local titleGroup = make("Frame", { Size = FULL, BackgroundTransparency = 1 }, panel)
local emblem = buildShip(titleGroup, UDim2.fromOffset(120, 120), C.cyan)
label("SURVIVE " .. Config.FINAL_WAVE .. " WAVES OF NEON", 34, C.white, UDim2.fromScale(0.5, 0.5), titleGroup)
label("WASD MOVE  -  MOUSE AIM  -  AUTO FIRE", 28, C.yellow, UDim2.fromScale(0.5, 0.6), titleGroup)
local bestText = label("BEST: 0", 32, C.cyan, UDim2.fromScale(0.5, 0.91), titleGroup, UDim2.fromScale(0.5, 0.07))

local endGroup = make("Frame", { Size = FULL, BackgroundTransparency = 1, Visible = false }, panel)
local card = make("Frame", {
	AnchorPoint = CENTER,
	Position = UDim2.fromScale(0.35, 0.47),
	Size = UDim2.fromScale(0.5, 0.44),
	BackgroundColor3 = C.arena,
}, endGroup)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
glow(card, 2, 0.3, C.cyan, C.magenta)
local statValues = {}
for i, name in { "SCORE", "WAVES CLEARED", "KILLS", "BEST" } do
	local y = 0.15 + (i - 1) * 0.23
	label(name, 30, C.white, UDim2.fromScale(0.3, y), card, UDim2.fromScale(0.55, 0.2)).TextXAlignment = Enum.TextXAlignment.Left
	local value = label("0", 34, C.yellow, UDim2.fromScale(0.75, y), card, UDim2.fromScale(0.4, 0.2))
	value.TextXAlignment = Enum.TextXAlignment.Right
	statValues[name] = value
end
local gradeText = label("S", 150, C.yellow, UDim2.fromScale(0.82, 0.44), endGroup, UDim2.fromScale(0.25, 0.3))
glow(gradeText, 5, 0.3, C.white, C.magenta)
label("GRADE", 30, C.cyan, UDim2.fromScale(0.82, 0.66), endGroup, UDim2.fromScale(0.25, 0.07))

local button = make("TextButton", {
	Text = "PLAY",
	TextSize = 44,
	Font = Enum.Font.GothamBlack,
	TextColor3 = C.bg,
	BackgroundColor3 = C.magenta,
	AnchorPoint = CENTER,
	Position = UDim2.fromScale(0.5, 0.77),
	Size = UDim2.fromScale(0.34, 0.12),
	AutoButtonColor = false,
}, panel)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, button)
local buttonStroke = glow(button, 5, 0.1, C.cyan, C.white)
local buttonScale = make("UIScale", {}, button)
button.MouseEnter:Connect(function()
	tween(buttonScale, 0.12, { Scale = 1.08 })
	tween(buttonStroke, 0.12, { Thickness = 9 })
end)
button.MouseLeave:Connect(function()
	tween(buttonScale, 0.12, { Scale = 1 })
	tween(buttonStroke, 0.12, { Thickness = 5 })
end)
button.MouseButton1Down:Connect(function()
	tween(buttonScale, 0.06, { Scale = 0.94 })
end)
button.MouseButton1Up:Connect(function()
	tween(buttonScale, 0.1, { Scale = 1.08 })
end)

-- Attract mode: a client-only demo drawn behind the menus --------------------------------------------------

local attract: any = { t = 0, px = W / 2, py = H / 2, spawn = 0, fire = 0, enemies = {}, bullets = {} }

local function near(ax: number, ay: number, bx: number, by: number, r: number): boolean
	local dx, dy = ax - bx, ay - by
	return dx * dx + dy * dy < r * r
end

local function stepAttract(dt: number): any
	local a = attract
	a.t += dt
	a.px, a.py = W / 2 + 340 * math.sin(a.t * 0.55), H / 2 + 200 * math.sin(a.t * 0.83 + 1)
	a.spawn -= dt
	if a.spawn <= 0 and #a.enemies < 11 then
		a.spawn = 0.7
		local side = rng:NextInteger(1, 4)
		local x, y = rng:NextNumber(0, W), rng:NextNumber(0, H)
		if side == 1 then
			y = -30
		elseif side == 2 then
			y = H + 30
		elseif side == 3 then
			x = -30
		else
			x = W + 30
		end
		local dx, dy = rng:NextNumber(200, 800) - x, rng:NextNumber(150, 450) - y
		local len = math.sqrt(dx * dx + dy * dy)
		local kind = if rng:NextNumber() < 0.3 then "hunter" else "drifter"
		local speed = Config.KINDS[kind].speed * 0.8
		table.insert(a.enemies, { x, y, kind, dx / len * speed, dy / len * speed, Config.KINDS[kind].hp })
	end
	for i = #a.enemies, 1, -1 do
		local e = a.enemies[i]
		e[1] += e[4] * dt
		e[2] += e[5] * dt
		if e[1] < -120 or e[1] > W + 120 or e[2] < -120 or e[2] > H + 120 then
			table.remove(a.enemies, i)
		end
	end
	a.fire -= dt
	if a.fire <= 0 then
		local target: any, bestDist = nil, 1e9
		for _, e in a.enemies do
			local d = (e[1] - a.px) ^ 2 + (e[2] - a.py) ^ 2
			if d < bestDist and e[1] > 0 and e[1] < W and e[2] > 0 and e[2] < H then
				target, bestDist = e, d
			end
		end
		if target then
			local len = math.max(math.sqrt(bestDist), 1)
			local vx, vy = (target[1] - a.px) / len * Config.BULLET_SPEED, (target[2] - a.py) / len * Config.BULLET_SPEED
			table.insert(a.bullets, { a.px, a.py, vx, vy })
			a.fire = 0.22
		end
	end
	for i = #a.bullets, 1, -1 do
		local b = a.bullets[i]
		b[1] += b[3] * dt
		b[2] += b[4] * dt
		local dead = b[1] < -20 or b[1] > W + 20 or b[2] < -20 or b[2] > H + 20
		for j = #a.enemies, 1, -1 do
			local e = a.enemies[j]
			local def = Config.KINDS[e[3]]
			if not dead and near(b[1], b[2], e[1], e[2], def.radius + Config.BULLET_RADIUS) then
				dead = true
				e[6] -= 1
				if e[6] <= 0 then
					burst(e[1], e[2], def.color, 10)
					table.remove(a.enemies, j)
				end
			end
		end
		if dead then
			table.remove(a.bullets, i)
		end
	end
	return { px = a.px, py = a.py, invuln = false, enemies = a.enemies, bullets = a.bullets }
end

-- Drawing ---------------------------------------------------------------------------------------------------

local function drawWorld(view: any, now: number)
	ship.Position = UDim2.fromScale(view.px / W, view.py / H)
	ship.Visible = not view.invuln or math.floor(now * 12) % 2 == 0
	if rng:NextNumber() < 0.7 then
		emit(view.px, view.py + 20, rng:NextNumber(-30, 30), 140, 9, C.cyan, 0.25)
	end
	local used = { drifter = 0, hunter = 0 }
	for i, e in view.enemies do
		local kind: string = e[3]
		local def = Config.KINDS[kind]
		used[kind] += 1
		local shape = acquire(enemyPools[kind], used[kind], function()
			return buildEnemy(kind, arena)
		end)
		shape.Position = UDim2.fromScale(e[1] / W, e[2] / H)
		shape.Size = UDim2.fromScale(def.radius * 2.6 / W, def.radius * 2.6 / H)
		shape.Rotation = (if def.homing then -40 else 60) * now + i * 37
	end
	hideFrom(enemyPools.drifter, used.drifter + 1)
	hideFrom(enemyPools.hunter, used.hunter + 1)
	for i, b in view.bullets do
		local shape = acquire(bulletPool, i, buildBullet)
		shape.Position = UDim2.fromScale(b[1] / W, b[2] / H)
		if rng:NextNumber() < 0.6 then
			emit(b[1], b[2], 0, 0, 10, C.cyan, 0.18)
		end
	end
	hideFrom(bulletPool, #view.bullets + 1)
	pickup.Visible = view.pickup ~= nil
	if view.pickup then
		pickup.Position = UDim2.fromScale(view.pickup.x / W, view.pickup.y / H)
		pickup.Rotation = now * 90
	end
end

local FX_COLORS: { [string]: Color3 } = {
	hit = C.magenta,
	pickup = C.yellow,
	wave = C.cyan,
	win = C.green,
	lose = C.magenta,
}
local GRADE_COLORS: { [string]: Color3 } = { S = C.yellow, A = C.green, B = C.cyan, C = C.magenta }

local latest: any = nil
local phase = "title"
local lastFx, lastWave, lastScore = 0, 0, 0
local shake = 0

local function updateHud(s: any)
	scoreText.Text = "SCORE " .. s.score
	if s.score ~= lastScore then
		lastScore = s.score
		scoreScale.Scale = 1.3
		tween(scoreScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	waveText.Text = "WAVE " .. math.max(s.wave, 1) .. " / " .. s.finalWave
	for i, icon in lifeIcons do
		icon.Visible = i <= s.lives
	end
	rapidText.Text = if s.rapid > 0 then string.format("RAPID FIRE %.0fs", s.rapid) else ""
	if s.wave ~= lastWave then
		lastWave = s.wave
		showBanner(if s.wave == s.finalWave then "FINAL WAVE" else "WAVE " .. s.wave)
	end
end

local function updateMenu(s: any)
	local over = s.phase == "over"
	titleGroup.Visible = not over
	endGroup.Visible = over
	button.Text = if over then "PLAY AGAIN" else "PLAY"
	button.Position = UDim2.fromScale(0.5, if over then 0.86 else 0.77)
	title.Position = UDim2.fromScale(0.5, if over then 0.13 else 0.36)
	if over then
		title.Text = if s.won then "YOU WIN" else "GAME OVER"
		titleGradient.Color = if s.won then ColorSequence.new(C.cyan, C.green) else ColorSequence.new(C.magenta, C.yellow)
		statValues["SCORE"].Text = tostring(s.score)
		statValues["WAVES CLEARED"].Text = s.cleared .. " / " .. s.finalWave
		statValues["KILLS"].Text = tostring(s.kills)
		statValues["BEST"].Text = tostring(s.best)
		gradeText.Text = s.grade
		gradeText.TextColor3 = GRADE_COLORS[s.grade] or C.white
	else
		title.Text = "VOID BLOOM"
		titleGradient.Color = ColorSequence.new(C.cyan, C.magenta)
		bestText.Text = "BEST: " .. s.best
	end
end

local function render(s: any)
	latest = s
	local playing = s.phase == "play"
	hud.Visible = playing
	overlay.Visible = not playing
	if s.phase ~= phase then
		phase = s.phase
		lastWave = 0
		panelScale.Scale = 0.88
		tween(panelScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if playing then
		updateHud(s)
	else
		updateMenu(s)
	end
	if s.fx ~= lastFx then
		lastFx = s.fx
		local color = FX_COLORS[s.fxKind]
		if color then
			border.Color = color
			border.Thickness = 10
			tween(border, 0.35, { Thickness = 3, Color = C.cyan })
		end
		if s.fxKind == "hit" then
			shake = 0.4
			hitFlash.BackgroundTransparency = 0.6
			tween(hitFlash, 0.4, { BackgroundTransparency = 1 })
			burst(s.px, s.py, C.magenta, 18)
		end
	end
	for _, ev in s.events do
		burst(ev[1], ev[2], Config.KINDS[ev[4]].color, 12)
		popScore(ev[1], ev[2], ev[3], C.white)
	end
end

stateEvent.OnClientEvent:Connect(render)
button.Activated:Connect(function()
	startEvent:FireServer()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and phase ~= "play" and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space) then
		startEvent:FireServer()
	end
end)

local function readInput()
	local mx, my = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then mx -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then mx += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then my -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then my += 1 end
	local rel = (UserInputService:GetMouseLocation() - arena.AbsolutePosition) / arena.AbsoluteSize
	return mx, my, rel.X * W, rel.Y * H
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for _, star in stars do
		star.x -= star.speed * dt
		if star.x < -0.02 then
			star.x = 1.02
		end
		star.frame.Position = UDim2.fromScale(star.x, star.y)
	end
	local playing = phase == "play" and latest ~= nil
	if playing then
		inputEvent:FireServer(readInput())
	end
	shake = math.max(shake - dt, 0)
	arena.Position = ARENA_HOME + UDim2.fromOffset(rng:NextNumber(-1, 1) * shake * 40, rng:NextNumber(-1, 1) * shake * 40)
	emblem.Position = UDim2.new(0.5, 0, 0.15, math.sin(now * 2) * 6)
	drawWorld(if playing then latest else stepAttract(dt), now)
	for i = #particles, 1, -1 do
		local p = particles[i]
		p.life -= dt
		if p.life <= 0 then
			p.frame.Visible = false
			table.remove(particles, i)
			table.insert(freeParticles, p)
		else
			p.x += p.vx * dt
			p.y += p.vy * dt
			local a = p.life / p.max
			p.frame.Position = UDim2.fromScale(p.x / W, p.y / H)
			p.frame.Size = UDim2.fromScale(p.size * a / W, p.size * a / H)
			p.frame.BackgroundTransparency = 1 - a * 0.9
		end
	end
end)
