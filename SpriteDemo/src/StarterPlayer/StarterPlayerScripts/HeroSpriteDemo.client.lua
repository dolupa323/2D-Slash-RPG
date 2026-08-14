-- MapleStory-style side-scroller action RPG client (fully client-authoritative
-- prototype — no server sync). Player has real gravity/jump physics and only
-- moves left/right on a single ground platform. Enemies walk the same ground
-- line toward the player's X and use Nature2D purely for horizontal overlap
-- separation (SetPosition each frame, not ApplyForce — see the note above the
-- Nature2D section for why). Animation is driven by SpriteClip2 through the
-- CharacterAnimator wrapper.
--
-- IMPORTANT: Nature2D writes GuiObject.Position in absolute screen-pixel
-- offsets (UDim2.new(0, x, 0, y)), and only lines up correctly for objects
-- parented DIRECTLY to the ScreenGui (see Nature2D RigidBody:Render()). So
-- every physics-driven sprite (enemies) is a direct child of screenGui, not
-- nested inside the decorative Arena background frame.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local CharacterAnimator = require(ReplicatedStorage.Shared.CharacterAnimator)
local Nature2D = require(ReplicatedStorage.Packages.Nature2D)

local CELL = GameConfig.CELL_WIDTH
local ARENA = GameConfig.Arena
local playerCfg = GameConfig.Player
local enemyCfg = GameConfig.Enemy

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ===== Root GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpriteDemoGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ViewportSize can briefly report a stale/tiny value on the very first tick
-- of a LocalScript; wait for a real one before laying out screen-space UI.
-- Bounded, not infinite: some Studio window states never report a real size
-- (observed stuck at (1,1) in one session), which would otherwise hang the
-- whole script before anything is ever drawn. Fall back to a sane default.
do
	local waited = 0
	while (camera.ViewportSize.X < 100 or camera.ViewportSize.Y < 100) and waited < 3 do
		RunService.RenderStepped:Wait()
		waited += 1
	end
end
local viewport = camera.ViewportSize
if viewport.X < 100 or viewport.Y < 100 then
	viewport = Vector2.new(1280, 720)
end

-- The arena fills the entire screen — this is the whole game, not a HUD
-- panel floating over a 3D world (the 3D world has been removed entirely:
-- no Baseplate/Terrain/character, see the one-time Studio setup).
ARENA.width = viewport.X
ARENA.height = viewport.Y
local arenaTopLeft = Vector2.new(0, 0)

-- Opaque full-screen backdrop so nothing but this 2D game is ever visible.
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(120, 170, 220)
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = screenGui

-- ===== Ground platform =====
local GROUND_THICKNESS = 40
local GROUND_Y = ARENA.height - 100 -- top surface of the ground, in absolute screen px
local GRAVITY = 2200 -- px/sec^2
local JUMP_VELOCITY = -950 -- px/sec (negative = up)

local ground = Instance.new("Frame")
ground.Name = "Ground"
ground.Position = UDim2.new(0, 0, 0, GROUND_Y)
ground.Size = UDim2.new(1, 0, 0, GROUND_THICKNESS)
ground.BackgroundColor3 = Color3.fromRGB(90, 140, 70)
ground.BorderSizePixel = 0
ground.ZIndex = 1
ground.Parent = screenGui

-- headOffsetPx: distance from the sprite box's TOP edge down to the visual
-- character's head (box_size * visualTopPad — see GameConfig). The bar sits
-- just above that, not a fixed distance above the (mostly empty) box top.
local function createHealthBar(parent, width, headOffsetPx)
	local barHeight = 6
	local bg = Instance.new("Frame")
	bg.Name = "HealthBar"
	bg.Size = UDim2.new(0, width, 0, barHeight)
	bg.Position = UDim2.new(0.5, -width / 2, 0, headOffsetPx - barHeight - 6)
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

local function setSpriteCenter(imageLabel, centerX, centerY, size)
	imageLabel.Position = UDim2.new(0, centerX - size / 2, 0, centerY - size / 2)
end

-- How far each sprite box must be pushed DOWN past the naive "box bottom on
-- the ground" position so the visually-drawn feet (not the transparent
-- padding below them) actually touch the ground line.
local playerGroundOffset = playerCfg.displaySize * playerCfg.visualBottomPad
local enemyGroundOffset = enemyCfg.displaySize * enemyCfg.visualBottomPad
local playerHeadOffset = playerCfg.displaySize * playerCfg.visualTopPad
local enemyHeadOffset = enemyCfg.displaySize * enemyCfg.visualTopPad

-- ===== Player sprite (direct child of screenGui, manually positioned) =====
local heroSprite = Instance.new("ImageLabel")
heroSprite.Name = "HeroSprite"
heroSprite.Image = playerCfg.assetId
heroSprite.ScaleType = Enum.ScaleType.Crop
heroSprite.BackgroundTransparency = 1
heroSprite.Size = UDim2.new(0, playerCfg.displaySize, 0, playerCfg.displaySize)
heroSprite.ZIndex = 10
heroSprite.Parent = screenGui

local heroHealthFill = createHealthBar(heroSprite, playerCfg.displaySize, playerHeadOffset)
local heroAnimator = CharacterAnimator.new(heroSprite, playerCfg.states, playerCfg.assetId, CELL, CELL)

-- ===== HUD =====
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

-- ===== Player state (client-authoritative) =====
-- playerX/playerY are the character's CENTER in absolute screen pixels.
local playerX, playerY = ARENA.width / 2, GROUND_Y - playerCfg.displaySize / 2 + playerGroundOffset
local velocityY = 0
local grounded = true
local facingLeft = false
local hp, maxHp = playerCfg.maxHp, playerCfg.maxHp
local level, xp, xpToNext = 1, 0, playerCfg.xpToLevel(1)
local lastAttackTime = 0

local function refreshHud()
	levelLabel.Text = string.format("Lv.%d", level)
	hpBarFill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
	heroHealthFill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
	xpBarFill.Size = UDim2.new(math.clamp(xp / xpToNext, 0, 1), 0, 1, 0)
end
refreshHud()

local function grantXp(amount)
	xp += amount
	while xp >= xpToNext do
		xp -= xpToNext
		level += 1
		maxHp += 15
		hp = maxHp
		xpToNext = playerCfg.xpToLevel(level)
	end
	refreshHud()
end

local function damagePlayer(amount)
	hp = math.max(0, hp - amount)
	if hp <= 0 then
		hp = maxHp -- simple respawn in place
	end
	refreshHud()
end

-- ===== Nature2D engine =====
-- Used ONLY to resolve horizontal overlap between enemies standing on the
-- same ground line (Runner.CollisionResponse nudges vertex positions apart
-- by a bounded penetration-depth amount). Movement itself is computed by us
-- and applied via body:SetPosition() every frame, NOT via ApplyForce:
-- Nature2D's Verlet integration runs on a fixed 60Hz internal step with no dt
-- scaling (RigidBody:Update ignores its dt argument), so any continuously
-- applied force accumulates without bound. SetPosition resets a body's
-- velocity to zero on every call (oldPos snaps to pos), sidestepping that
-- entirely.
local engine = Nature2D.init(screenGui)
engine:CreateCanvas(arenaTopLeft, Vector2.new(ARENA.width, ARENA.height), ground)
engine:SetPhysicalProperty("Gravity", Vector2.new(0, 0))
engine:SetPhysicalProperty("Friction", 0.2)
engine:SetPhysicalProperty("AirFriction", 0.2)
engine:Start()

-- ===== Enemies (ground-walkers, X-axis chase only) =====
local enemies = {} -- id -> { sprite, animator, body, hp, maxHp, healthFill, lastContactTime }
local nextEnemyId = 1
local spawnTimer = 0

local function countAlive()
	local n = 0
	for _ in pairs(enemies) do
		n += 1
	end
	return n
end

local function spawnEnemy()
	local size = enemyCfg.displaySize
	local x = math.random(size, ARENA.width - size)
	local y = GROUND_Y - size / 2 + enemyGroundOffset

	local sprite = Instance.new("ImageLabel")
	sprite.Name = "Enemy_" .. tostring(nextEnemyId)
	sprite.Image = enemyCfg.assetId
	sprite.ScaleType = Enum.ScaleType.Crop
	sprite.BackgroundTransparency = 1
	sprite.Size = UDim2.new(0, size, 0, size)
	sprite.Position = UDim2.new(0, x - size / 2, 0, y - size / 2)
	sprite.ZIndex = 5
	sprite.Parent = screenGui

	local healthFill = createHealthBar(sprite, size, enemyHeadOffset)
	local animator = CharacterAnimator.new(sprite, enemyCfg.states, enemyCfg.assetId, CELL, CELL)

	local body = engine:Create("RigidBody", {
		Object = sprite,
		Mass = 1,
		Collidable = true,
		Anchored = false,
		Gravity = Vector2.new(0, 0),
		KeepInCanvas = true,
		CanRotate = false, -- ground-walkers must stay upright; the earlier SAT crash (now patched at the root) was unrelated to this
	})

	local id = nextEnemyId
	nextEnemyId += 1
	enemies[id] = {
		sprite = sprite,
		animator = animator,
		body = body,
		hp = enemyCfg.maxHp,
		maxHp = enemyCfg.maxHp,
		healthFill = healthFill,
		lastContactTime = 0,
	}
end

local function killEnemy(id)
	local enemy = enemies[id]
	if not enemy then return end
	enemy.animator:destroy()
	enemy.body:Destroy()
	enemy.sprite:Destroy()
	enemies[id] = nil
	grantXp(enemyCfg.xpReward)
end

-- ===== Input =====
local pressed = {}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	pressed[input.KeyCode] = true

	if input.KeyCode == Enum.KeyCode.Space then
		if grounded then
			velocityY = JUMP_VELOCITY
			grounded = false
			heroAnimator:playOnce("jump")
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		local now = os.clock()
		if (now - lastAttackTime) >= playerCfg.attackCooldown and heroAnimator:playOnce("attack") then
			lastAttackTime = now
			local facingDx = facingLeft and -1 or 1
			local hitX = playerX + facingDx * (playerCfg.attackRange / 2)

			for id, enemy in pairs(enemies) do
				local center = enemy.body:GetCenter()
				local dist = Vector2.new(center.X - hitX, center.Y - playerY).Magnitude
				if dist <= playerCfg.attackRange then
					enemy.hp -= playerCfg.attackDamage
					if enemy.hp <= 0 then
						killEnemy(id)
					else
						enemy.healthFill.Size = UDim2.new(math.clamp(enemy.hp / enemy.maxHp, 0, 1), 0, 1, 0)
					end
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		heroAnimator:playOnce("wave")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	pressed[input.KeyCode] = false
end)

-- ===== Main loop =====
RunService.RenderStepped:Connect(function(dt)
	-- horizontal movement (left/right only, MapleStory-style)
	local dx = 0
	if pressed[Enum.KeyCode.A] or pressed[Enum.KeyCode.Left] then dx -= 1 end
	if pressed[Enum.KeyCode.D] or pressed[Enum.KeyCode.Right] then dx += 1 end

	local half = playerCfg.displaySize / 2
	if dx ~= 0 then
		playerX = math.clamp(playerX + dx * playerCfg.moveSpeed * dt, half, ARENA.width - half)
		facingLeft = dx < 0
		heroAnimator:setFacing(facingLeft)
		if grounded then
			heroAnimator:setLoopState("idle") -- no dedicated walk cycle yet
		end
	elseif grounded then
		heroAnimator:setLoopState("idle")
	end

	-- gravity + jump arc
	velocityY += GRAVITY * dt
	playerY += velocityY * dt
	if playerY >= GROUND_Y - half + playerGroundOffset then
		playerY = GROUND_Y - half + playerGroundOffset
		velocityY = 0
		grounded = true
	else
		grounded = false
	end

	setSpriteCenter(heroSprite, playerX, playerY, playerCfg.displaySize)

	-- enemy spawn
	spawnTimer += dt
	if spawnTimer >= enemyCfg.spawnIntervalSeconds and countAlive() < enemyCfg.maxAlive then
		spawnTimer = 0
		spawnEnemy()
	end

	-- enemy AI + contact damage (X-axis chase, Y pinned to the ground)
	local now = os.clock()
	local enemyHalf = enemyCfg.displaySize / 2
	local enemyY = GROUND_Y - enemyHalf + enemyGroundOffset
	for id, enemy in pairs(enemies) do
		local center = enemy.body:GetCenter()
		local dist = Vector2.new(playerX - center.X, playerY - center.Y).Magnitude

		if dist <= enemyCfg.aggroRange and math.abs(playerX - center.X) > 2 then
			local dirX = playerX > center.X and 1 or -1
			local step = math.min(enemyCfg.moveSpeed * dt, math.abs(playerX - center.X))
			local newX = center.X + dirX * step
			enemy.body:SetPosition(newX - enemyHalf, enemyY - enemyHalf)
			enemy.animator:setFacing(dirX < 0)
		end

		if dist <= 40 and (now - enemy.lastContactTime) >= enemyCfg.contactCooldown then
			enemy.lastContactTime = now
			enemy.animator:playOnce("attack")
			damagePlayer(enemyCfg.contactDamage)
		else
			enemy.animator:setLoopState("idle")
		end
	end
end)
