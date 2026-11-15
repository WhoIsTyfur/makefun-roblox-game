--!strict
-- Client: reads input, sends it to the server, and draws each snapshot as neon GUI shapes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local C = Config.COLORS
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startEvent = remotes:WaitForChild("Start") :: RemoteEvent
local inputEvent = remotes:WaitForChild("Input") :: RemoteEvent
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "VoidBloom"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function label(text: string, size: number, color: Color3, pos: UDim2, parent: Instance): TextLabel
	return make("TextLabel", {
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromScale(0.9, 0.1),
		TextStrokeTransparency = 0.4,
	}, parent)
end

make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg }, gui)
local arena = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromScale(0.96, 0.84),
	BackgroundColor3 = C.arena,
	ClipsDescendants = true,
}, gui)
make("UIAspectRatioConstraint", { AspectRatio = Config.ARENA_W / Config.ARENA_H }, arena)
local border = make("UIStroke", { Color = C.cyan, Thickness = 3 }, arena)

-- HUD: top centre and top right, clear of Roblox's top-left menu buttons.
local scoreText = label("SCORE 0", 44, C.white, UDim2.fromScale(0.5, 0.045), gui)
scoreText.Size = UDim2.fromScale(0.4, 0.08)
local waveText = label("WAVE 1", 30, C.cyan, UDim2.fromScale(0.5, 0.115), gui)
waveText.Size = UDim2.fromScale(0.4, 0.06)
local livesText = label("", 40, C.magenta, UDim2.fromScale(0.86, 0.05), gui)
livesText.Size = UDim2.fromScale(0.25, 0.08)
livesText.TextXAlignment = Enum.TextXAlignment.Right
local rapidText = label("", 26, C.yellow, UDim2.fromScale(0.86, 0.115), gui)
rapidText.Size = UDim2.fromScale(0.25, 0.05)
rapidText.TextXAlignment = Enum.TextXAlignment.Right

local overlay = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.25,
	ZIndex = 10,
}, gui)
local titleText = label("VOID BLOOM", 96, C.cyan, UDim2.fromScale(0.5, 0.3), overlay)
titleText.Size = UDim2.fromScale(0.9, 0.2)
titleText.ZIndex = 11
local subText = label("", 36, C.white, UDim2.fromScale(0.5, 0.47), overlay)
subText.ZIndex = 11
local helpText = label("WASD to move  -  aim with the mouse  -  your ship fires on its own", 28, C.yellow, UDim2.fromScale(0.5, 0.6), overlay)
helpText.ZIndex = 11
local button = make("TextButton", {
	Text = "PLAY",
	TextSize = 48,
	Font = Enum.Font.GothamBlack,
	TextColor3 = C.bg,
	BackgroundColor3 = C.magenta,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.78),
	Size = UDim2.fromScale(0.26, 0.12),
	ZIndex = 11,
}, overlay)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, button)

local pools = { enemy = {}, bullet = {} } :: { [string]: { any } }
local function placeShape(pool: { any }, index: number, x: number, y: number, r: number, color: Color3)
	local shape = pool[index]
	if not shape then
		shape = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5) }, arena)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, shape)
		pool[index] = shape
	end
	shape.Visible = true
	shape.BackgroundColor3 = color
	shape.Position = UDim2.fromScale(x / Config.ARENA_W, y / Config.ARENA_H)
	shape.Size = UDim2.fromScale(r * 2 / Config.ARENA_W, r * 2 / Config.ARENA_H)
end

local function hideFrom(pool: { any }, from: number)
	for i = from, #pool do
		pool[i].Visible = false
	end
end

local ship = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = C.cyan,
	Size = UDim2.fromScale(Config.PLAYER_RADIUS * 2 / Config.ARENA_W, Config.PLAYER_RADIUS * 2 / Config.ARENA_H),
}, arena)
make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, ship)
local pickup = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = C.yellow,
	Size = UDim2.fromScale(0.04, 0.066),
	Visible = false,
}, arena)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, pickup)

local FX_COLORS: { [string]: Color3 } = {
	hit = C.magenta,
	kill = C.green,
	pickup = C.yellow,
	wave = C.cyan,
	win = C.green,
	lose = C.magenta,
}
local lastFx = 0
local function playFeedback(kind: string)
	border.Color = FX_COLORS[kind] or C.cyan
	border.Thickness = 10
	TweenService:Create(border, TweenInfo.new(0.35), { Thickness = 3, Color = C.cyan }):Play()
end

local function render(s: any)
	local playing = s.phase == "play"
	overlay.Visible = not playing
	if s.phase == "title" then
		titleText.Text = "VOID BLOOM"
		subText.Text = "Survive " .. s.finalWave .. " waves of drifting neon"
		button.Text = "PLAY"
	elseif s.phase == "over" then
		titleText.Text = if s.won then "BLOOM CLEARED" else "SIGNAL LOST"
		titleText.TextColor3 = if s.won then C.green else C.magenta
		subText.Text = "Final score " .. s.score
		button.Text = "PLAY AGAIN"
	end
	scoreText.Text = "SCORE " .. s.score
	waveText.Text = "WAVE " .. math.max(s.wave, 1) .. " / " .. s.finalWave
	livesText.Text = string.rep("<3 ", math.max(s.lives, 0))
	rapidText.Text = if s.rapid > 0 then string.format("RAPID FIRE %.0fs", s.rapid) else ""

	ship.Position = UDim2.fromScale(s.px / Config.ARENA_W, s.py / Config.ARENA_H)
	ship.BackgroundColor3 = if s.invuln then C.white else C.cyan
	ship.BackgroundTransparency = if s.invuln then 0.5 else 0
	for i, e in s.enemies do
		local def = Config.KINDS[e[3]]
		placeShape(pools.enemy, i, e[1], e[2], def.radius, if def.homing then C.yellow else C.magenta)
	end
	hideFrom(pools.enemy, #s.enemies + 1)
	for i, b in s.bullets do
		placeShape(pools.bullet, i, b[1], b[2], Config.BULLET_RADIUS, C.white)
	end
	hideFrom(pools.bullet, #s.bullets + 1)
	pickup.Visible = s.pickup ~= nil
	if s.pickup then
		pickup.Position = UDim2.fromScale(s.pickup.x / Config.ARENA_W, s.pickup.y / Config.ARENA_H)
	end
	if s.fx ~= lastFx then
		lastFx = s.fx
		playFeedback(s.fxKind)
	end
end

stateEvent.OnClientEvent:Connect(render)
button.Activated:Connect(function()
	startEvent:FireServer()
end)

local function readInput()
	local mx, my = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then mx -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then mx += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then my -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then my += 1 end
	local mouse = UserInputService:GetMouseLocation()
	local rel = (mouse - arena.AbsolutePosition) / arena.AbsoluteSize
	return mx, my, rel.X * Config.ARENA_W, rel.Y * Config.ARENA_H
end

RunService.RenderStepped:Connect(function()
	local mx, my, ax, ay = readInput()
	inputEvent:FireServer(mx, my, ax, ay)
end)
