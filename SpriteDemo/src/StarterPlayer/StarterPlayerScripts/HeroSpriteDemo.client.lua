-- MapleStory-style side-scroller action RPG client — full rewrite per the
-- approved server-authoritative multiplayer plan, Phases 1-8 + the
-- client-side prediction amendment (input lag fix).
--
-- Responsibilities left on the client: capture input (keyboard/gamepad/
-- touch, via InputController), predict the LOCAL player's own movement
-- immediately (PhysicsStep, reconciled against server snapshots), interpolate
-- every OTHER entity from the server's interest-filtered WorldSnapshot, and
-- render all of it through pooled GUI instances (EntityPool). All game-state
-- truth (positions, hp, AI, combat, spawning) lives on the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local CharacterAnimator = require(ReplicatedStorage.Shared.CharacterAnimator)
local PhysicsStep = require(ReplicatedStorage.Shared.PhysicsStep)
local Camera = require(script.Parent.Render.Camera)
local EntityPool = require(script.Parent.Render.EntityPool)
local InputController = require(script.Parent.Input.InputController)
local TouchControls = require(script.Parent.Input.TouchControls)
local NetworkClient = require(script.Parent.Net.NetworkClient)

local CELL = GameConfig.CELL_WIDTH
local WORLD = GameConfig.World
local playerCfg = GameConfig.Player
local enemyCfg = GameConfig.Enemy

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local cameraObj = workspace.CurrentCamera

-- ===== Root GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpriteDemoGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ViewportSize can briefly report a stale/tiny value on the very first tick
-- of a LocalScript; wait for a real one before laying out screen-space UI.
-- Bounded by wall-clock time via task.wait, not by counting RenderStepped
-- events: RenderStepped only fires once real frames are being presented, and
-- some window states never reach that point (observed ViewportSize stuck at
-- (1,1) with zero RenderStepped firings for the whole session) — waiting on
-- RenderStepped:Wait() in that case blocks forever, since the loop can never
-- re-check its own exit condition. task.wait is driven by the task
-- scheduler/Heartbeat instead, which keeps running regardless.
do
	local start = os.clock()
	while (cameraObj.ViewportSize.X < 100 or cameraObj.ViewportSize.Y < 100) and os.clock() - start < 2 do
		task.wait(0.1)
	end
end
local viewport = cameraObj.ViewportSize
if viewport.X < 100 or viewport.Y < 100 then
	viewport = Vector2.new(1280, 720)
end

-- designHeight = WORLD.height: the game's vertical extent (sky to ground)
-- always maps to exactly the device's actual viewport height, uniformly
-- scaling X, Y, and sprite sizes together (see Camera.lua) — this is the fix
-- for landscape-mobile viewports being too short to show the 720-world-px
-- design height 1:1, which previously pushed the ground/characters below
-- the visible area entirely.
local camera = Camera.new(WORLD.width, WORLD.height, viewport, WORLD.height)
cameraObj:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	camera:setViewport(cameraObj.ViewportSize)
end)

-- Opaque full-screen backdrop (sky fallback color, shows through if the
-- background art hasn't loaded yet, or above/beyond its top edge).
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(120, 170, 220)
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = screenGui

-- Desert canyon backdrop art, tiled across the world width, scrolling
-- slower than the foreground (backgroundParallaxFactor) for a basic depth
-- cue. Sized/positioned every frame alongside ground — see the main loop.
local background = Instance.new("ImageLabel")
background.Name = "Background"
background.Image = WORLD.backgroundAssetId
background.ScaleType = Enum.ScaleType.Tile
background.BackgroundTransparency = 1
background.BorderSizePixel = 0
background.ZIndex = 1
background.Parent = screenGui

-- One ImageLabel per standable surface in WORLD.platforms (base ground +
-- elevated one-way platforms, each a dedicated rock-chunk piece from
-- WORLD.platformTextures). Count is small and fixed, so plain instances
-- created once up front are simpler than pooling.
local platformLabels = {}
for _, platform in ipairs(WORLD.platforms) do
	local tex = WORLD.platformTextures[platform.texture]
	local label = Instance.new("ImageLabel")
	label.Name = "Platform"
	label.Image = tex.assetId
	label.ScaleType = tex.tile and Enum.ScaleType.Tile or Enum.ScaleType.Fit
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ZIndex = 1
	label.Parent = screenGui
	table.insert(platformLabels, label)
end

-- Purely cosmetic set dressing on top of the platforms (crates, barrels,
-- banners, ...) — same instancing pattern as platforms, never touched by
-- physics, just drawn above the terrain (ZIndex 2 > platforms' 1).
local decorationLabels = {}
for _, deco in ipairs(WORLD.decorations) do
	local tex = WORLD.decorationTextures[deco.texture]
	local label = Instance.new("ImageLabel")
	label.Name = "Decoration"
	label.Image = tex.assetId
	label.ScaleType = Enum.ScaleType.Fit
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ZIndex = 2
	label.Parent = screenGui
	table.insert(decorationLabels, label)
end

-- Sized/positioned entirely with Scale-relative UDim2 components anchored to
-- the PARENT sprite's current (dynamically-scaled) size — this is what lets
-- the health bar auto-track the sprite's size every frame without needing
-- its own per-frame update code. topPadRatio is the same visualTopPad ratio
-- GameConfig already tracks (fraction of the sprite box's height down to the
-- drawn character's head), reused directly as a Y-scale offset.
local function createHealthBar(parent, topPadRatio)
	local barHeight = 6
	local bg = Instance.new("Frame")
	bg.Name = "HealthBar"
	bg.Size = UDim2.new(1, 0, 0, barHeight)
	bg.Position = UDim2.new(0, 0, topPadRatio, -barHeight - 6)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.ZIndex = 6
	bg.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	fill.Parent = bg

	return fill
end

-- worldX/worldY -> this sprite's screen Position (top-left) AND Size, via
-- the camera's uniform scale. Size is recomputed every frame (not just set
-- once at creation) because the scale itself can change — window resize on
-- PC, or an orientation change on mobile.
local function setSpriteWorldCenter(imageLabel, worldX, worldY, baseSize)
	local scale = camera:getScale()
	local displaySize = baseSize * scale
	local screenX, screenY = camera:worldToScreen(worldX, worldY)
	imageLabel.Size = UDim2.new(0, displaySize, 0, displaySize)
	imageLabel.Position = UDim2.new(0, screenX - displaySize / 2, 0, screenY - displaySize / 2)
end

-- ===== Local player sprite =====
local heroSprite = Instance.new("ImageLabel")
heroSprite.Name = "HeroSprite"
heroSprite.Image = playerCfg.assetId
heroSprite.ScaleType = Enum.ScaleType.Crop
heroSprite.BackgroundTransparency = 1
heroSprite.Size = UDim2.new(0, playerCfg.displaySize, 0, playerCfg.displaySize)
heroSprite.ZIndex = 10
heroSprite.Parent = screenGui

local heroHealthFill = createHealthBar(heroSprite, playerCfg.visualTopPad)
local heroAnimator = CharacterAnimator.new(heroSprite, playerCfg.states, playerCfg.assetId, CELL, CELL)

-- ===== Pooled visuals for other players/enemies (Phase 7) =====
local function createPlayerBundle()
	local sprite = Instance.new("ImageLabel")
	sprite.Image = playerCfg.assetId
	sprite.ScaleType = Enum.ScaleType.Crop
	sprite.BackgroundTransparency = 1
	sprite.Size = UDim2.new(0, playerCfg.displaySize, 0, playerCfg.displaySize)
	sprite.ZIndex = 9
	sprite.Parent = screenGui

	local healthFill = createHealthBar(sprite, playerCfg.visualTopPad)
	local animator = CharacterAnimator.new(sprite, playerCfg.states, playerCfg.assetId, CELL, CELL)
	return { sprite = sprite, animator = animator, healthFill = healthFill }
end

local function createEnemyBundle()
	local sprite = Instance.new("ImageLabel")
	sprite.Image = enemyCfg.assetId
	sprite.ScaleType = Enum.ScaleType.Crop
	sprite.BackgroundTransparency = 1
	sprite.Size = UDim2.new(0, enemyCfg.displaySize, 0, enemyCfg.displaySize)
	sprite.ZIndex = 5
	sprite.Parent = screenGui

	local healthFill = createHealthBar(sprite, enemyCfg.visualTopPad)
	local animator = CharacterAnimator.new(sprite, enemyCfg.states, enemyCfg.assetId, CELL, CELL)
	return { sprite = sprite, animator = animator, healthFill = healthFill, lastAttackTick = 0 }
end

local playerPool = EntityPool.new(createPlayerBundle)
local enemyPool = EntityPool.new(createEnemyBundle)

-- ===== HUD (driven by the server-replicated local player state) =====
local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 16)
hud.Size = UDim2.new(0, 280, 0, 50)
hud.BackgroundTransparency = 1
hud.ZIndex = 20
hud.Parent = screenGui

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, 0, 0, 20)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "Lv.1"
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextSize = 18
levelLabel.ZIndex = 20
levelLabel.Parent = hud

local hpBarBg = Instance.new("Frame")
hpBarBg.Size = UDim2.new(1, 0, 0, 14)
hpBarBg.Position = UDim2.new(0, 0, 0, 22)
hpBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
hpBarBg.BorderSizePixel = 0
hpBarBg.ZIndex = 20
hpBarBg.Parent = hud
local hpBarFill = Instance.new("Frame")
hpBarFill.Size = UDim2.new(1, 0, 1, 0)
hpBarFill.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
hpBarFill.BorderSizePixel = 0
hpBarFill.ZIndex = 21
hpBarFill.Parent = hpBarBg

local xpBarBg = Instance.new("Frame")
xpBarBg.Size = UDim2.new(1, 0, 0, 8)
xpBarBg.Position = UDim2.new(0, 0, 0, 40)
xpBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
xpBarBg.BorderSizePixel = 0
xpBarBg.ZIndex = 20
xpBarBg.Parent = hud
local xpBarFill = Instance.new("Frame")
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = Color3.fromRGB(90, 160, 230)
xpBarFill.BorderSizePixel = 0
xpBarFill.ZIndex = 21
xpBarFill.Parent = xpBarBg

-- ===== Input + networking (Phase 8: keyboard/gamepad/touch all funnel
-- through InputController's signals — this script never touches
-- UserInputService directly) =====
local inputController = InputController.new()
local networkClient = NetworkClient.new(inputController)
TouchControls.setup(screenGui, inputController)

inputController.JumpPressed.Event:Connect(function()
	heroAnimator:playOnce("jump")
end)
inputController.AttackPressed.Event:Connect(function()
	heroAnimator:playOnce("attack")
	networkClient:requestAttack() -- server enforces cooldown/range; this is fire-and-forget
end)
inputController.WavePressed.Event:Connect(function()
	heroAnimator:playOnce("wave")
	networkClient:requestWave()
end)

-- ===== Local player prediction state =====
-- Matches ServerScriptService/Simulation/PlayerState.create's initial values
-- so there's no visible snap on the very first frame before any snapshot
-- has arrived.
local half = playerCfg.displaySize / 2
local groundOffset = playerCfg.displaySize * playerCfg.visualBottomPad
local predicted = {
	x = WORLD.width / 2,
	y = WORLD.groundY - half + groundOffset,
	velocityY = 0,
	grounded = true,
	facingLeft = false,
	moveX = 0,
	jumpRequested = false,
}

-- Reconciliation tuning: small drift is pulled back gently (invisible);
-- anything larger than RECONCILE_SNAP_DISTANCE (bigger than prediction error
-- should ever realistically get under normal latency) snaps immediately —
-- that's a real desync (initial sync, respawn, packet loss burst), not
-- something worth smoothing over.
local RECONCILE_PULL_RATE = 0.15
local RECONCILE_SNAP_DISTANCE = 150

-- ===== Main loop =====
RunService.RenderStepped:Connect(function(dt)
	networkClient:update(dt)

	-- 1) advance local prediction immediately from current input
	predicted.moveX = inputController:GetMoveAxis()
	predicted.jumpRequested = inputController:PollJumpForPrediction()
	PhysicsStep.update(predicted, dt)

	-- 2) reconcile against the server's last known truth for us
	local serverState = networkClient:getLocalState()
	if serverState then
		local errX = serverState.x - predicted.x
		local errY = serverState.y - predicted.y
		local errMag = math.sqrt(errX * errX + errY * errY)
		if errMag > RECONCILE_SNAP_DISTANCE then
			predicted.x, predicted.y, predicted.velocityY = serverState.x, serverState.y, 0
		else
			predicted.x += errX * RECONCILE_PULL_RATE
			predicted.y += errY * RECONCILE_PULL_RATE
		end
	end

	-- 3) render local player from the (now-corrected) prediction — zero
	-- input-to-screen latency regardless of network conditions
	heroAnimator:setFacing(predicted.facingLeft)
	if predicted.grounded then
		heroAnimator:setLoopState("idle") -- no dedicated walk cycle yet
	end
	camera:follow(predicted.x)
	setSpriteWorldCenter(heroSprite, predicted.x, predicted.y, playerCfg.displaySize)

	if serverState then
		heroHealthFill.Size = UDim2.new(math.clamp(serverState.hp / serverState.maxHp, 0, 1), 0, 1, 0)
		levelLabel.Text = string.format("Lv.%d", serverState.level)
		hpBarFill.Size = UDim2.new(math.clamp(serverState.hp / serverState.maxHp, 0, 1), 0, 1, 0)
		xpBarFill.Size = UDim2.new(math.clamp(serverState.xp / serverState.xpToNext, 0, 1), 0, 1, 0)
	end

	do
		local scale = camera:getScale()
		for i, platform in ipairs(WORLD.platforms) do
			local tex = WORLD.platformTextures[platform.texture]
			local label = platformLabels[i]
			local worldWidth = platform.x2 - platform.x1
			local screenX, screenY = camera:worldToScreen(platform.x1, platform.y)
			label.Position = UDim2.new(0, screenX, 0, screenY)
			if tex.tile then
				label.Size = UDim2.new(0, worldWidth * scale, 0, WORLD.groundThickness * scale)
				local tileSize = tex.tileWorldSize * scale
				label.TileSize = UDim2.new(0, tileSize, 0, tileSize)
			else
				-- Aspect-preserving: derive height from the piece's native
				-- aspect ratio so the rock art isn't stretched/squashed.
				label.Size = UDim2.new(0, worldWidth * scale, 0, (worldWidth / tex.aspectRatio) * scale)
			end
		end
	end

	do
		local scale = camera:getScale()
		for i, deco in ipairs(WORLD.decorations) do
			local tex = WORLD.decorationTextures[deco.texture]
			local label = decorationLabels[i]
			local worldWidth = deco.x2 - deco.x1
			local screenX, screenY = camera:worldToScreen(deco.x1, deco.y)
			label.Position = UDim2.new(0, screenX, 0, screenY)
			label.Size = UDim2.new(0, worldWidth * scale, 0, (worldWidth / tex.aspectRatio) * scale)
		end
	end

	do
		-- Parallax: same uniform Y-scale as everything else, but X uses only
		-- a fraction of the camera's offset, so the backdrop art scrolls
		-- slower than the foreground — reads as "further away."
		local scale = camera:getScale()
		local bgScreenX = (0 - camera.x * WORLD.backgroundParallaxFactor) * scale + camera.viewport.X / 2
		local bgScreenY = 0
		background.Position = UDim2.new(0, bgScreenX, 0, bgScreenY)
		background.Size = UDim2.new(0, WORLD.width * scale, 0, WORLD.height * scale)
		local tileHeight = WORLD.height * scale
		local tileWidth = tileHeight * WORLD.backgroundAspectRatio
		background.TileSize = UDim2.new(0, tileWidth, 0, tileHeight)
	end

	-- other players (interpolated, pooled)
	local now = os.clock()
	local localUserIdStr = tostring(player.UserId)
	local interpolatedPlayers = networkClient:getInterpolatedPlayers(now)
	local seenPlayers = {}
	for userIdStr, state in pairs(interpolatedPlayers) do
		if userIdStr ~= localUserIdStr then
			seenPlayers[userIdStr] = true
			local bundle = playerPool:acquire(userIdStr)
			bundle.animator:setFacing(state.facingLeft)
			bundle.animator:setLoopState("idle") -- jump anim for remote players deferred to a later polish pass
			bundle.healthFill.Size = UDim2.new(math.clamp(state.hp / state.maxHp, 0, 1), 0, 1, 0)
			setSpriteWorldCenter(bundle.sprite, state.x, state.y, playerCfg.displaySize)
		end
	end
	playerPool:releaseUnseen(seenPlayers)

	-- enemies (interpolated, pooled)
	local interpolatedEnemies = networkClient:getInterpolatedEnemies(now)
	local seenEnemies = {}
	for idStr, enemy in pairs(interpolatedEnemies) do
		seenEnemies[idStr] = true
		local bundle = enemyPool:acquire(idStr)
		bundle.animator:setFacing(enemy.facingLeft)
		bundle.healthFill.Size = UDim2.new(math.clamp(enemy.hp / enemy.maxHp, 0, 1), 0, 1, 0)
		setSpriteWorldCenter(bundle.sprite, enemy.x, enemy.y, enemyCfg.displaySize)

		if enemy.attackTick and enemy.attackTick ~= bundle.lastAttackTick then
			bundle.lastAttackTick = enemy.attackTick
			bundle.animator:playOnce("attack")
		else
			bundle.animator:setLoopState("idle")
		end
	end
	enemyPool:releaseUnseen(seenEnemies)
end)
