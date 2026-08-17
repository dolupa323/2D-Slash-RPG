-- Central config: sprite atlases (from sprite-gen manifest.json) + combat stats.
-- Keep this the single source of truth; client and server both require it.
-- (commit/push test)

local GameConfig = {}

GameConfig.CELL_WIDTH = 256
GameConfig.CELL_HEIGHT = 256

-- World is the shared, viewport-independent simulation space (server-
-- authoritative once Phase 3+ lands). Every client derives its own screen
-- position via Render/Camera.lua's world->screen transform; nothing in the
-- simulation itself should ever read camera.ViewportSize.
GameConfig.World = {
	width = 4000,
	height = 720,
	groundMargin = 100, -- px from World.height up to the ground's top surface
	groundChunkWidth = 100, -- world px per repeated ground piece (see platforms loop below)
	-- Legacy Fantasy - High Forest asset pack (C:\YJS\Roblox\Legacy-Fantasy -
	-- High Forest 2.3, license confirmed by the user) — replaces the
	-- hand-generated desert theme entirely. Two-layer parallax sky, same
	-- viewport-anchored infinite-tile technique the desert background was
	-- fixed to use (see backgroundParallaxFactor/midgroundParallaxFactor).
	skyAssetId = "rbxassetid://117452104173020", -- Background/Background.png
	skyAspectRatio = 480 / 272,
	backgroundParallaxFactor = 0.15,
	-- Trees/Background.png: distant pine silhouette band, already
	-- semi-transparent near its own top edge (fades into the sky rather
	-- than a hard line) and has real detail all the way to its bottom edge
	-- (checked via row-variance sampling), so unlike the old desert
	-- background there's no plain/undetailed strip to worry about.
	midgroundAssetId = "rbxassetid://85970701016589", -- Trees/Background.png
	midgroundAspectRatio = 896 / 256,
	midgroundParallaxFactor = 0.4,
}
GameConfig.World.groundY = GameConfig.World.height - GameConfig.World.groundMargin

-- Forest terrain pieces, cropped from the asset pack's sheets (Tiles.png /
-- Buildings.png / Props-Rocks.png) down to individual alpha-tight PNGs —
-- same crop-tight convention proven out on the desert platform pieces, so
-- each piece's visible art matches its collision box. aspectRatio = native
-- width/height of the cropped file (see HeroSpriteDemo.client.lua render
-- loop, which is fully asset-agnostic and needed zero changes for this
-- swap — only this data and the two background layers changed).
GameConfig.World.platformTextures = {
	grassGround   = { assetId = "rbxassetid://96017270758916", aspectRatio = 82 / 75 }, -- Tiles.png grass-top block, repeated edge-to-edge for the base ground
	wide          = { assetId = "rbxassetid://96017270758916", aspectRatio = 82 / 75 }, -- same grass block, used standalone as an elevated platform
	narrow        = { assetId = "rbxassetid://95193251023688", aspectRatio = 48 / 75 },
	rock          = { assetId = "rbxassetid://98685309326616", aspectRatio = 62 / 77 }, -- Props-Rocks.png mossy boulder
	rockSmall     = { assetId = "rbxassetid://120743987225209", aspectRatio = 42 / 34 },
	pillar        = { assetId = "rbxassetid://104740070526011", aspectRatio = 66 / 178 }, -- Tiles.png tree trunk (with beehives built into the art)
	floatPlank    = { assetId = "rbxassetid://139293238298132", aspectRatio = 60 / 30 }, -- mossy wood plank
	bridge        = { assetId = "rbxassetid://87174825337257", aspectRatio = 88 / 48 }, -- rope bridge
	cabinWall     = { assetId = "rbxassetid://79448280022903", aspectRatio = 112 / 112 }, -- Buildings.png log-cabin wall block
	rockRamp      = { assetId = "rbxassetid://98847297990632", aspectRatio = 135 / 171 }, -- Buildings.png rock mound + wood ramp, big dramatic anchor
}

-- Decorative-only pieces placed on top of platforms/ground — never checked
-- by PhysicsStep, purely visual.
GameConfig.World.decorationTextures = {
	treeGreen   = { assetId = "rbxassetid://89220370547945", aspectRatio = 107 / 368 },
	treeGolden  = { assetId = "rbxassetid://98113748459298", aspectRatio = 107 / 368 },
	treeDark    = { assetId = "rbxassetid://111981113942878", aspectRatio = 107 / 368 },
	treeRed     = { assetId = "rbxassetid://131173993375495", aspectRatio = 107 / 368 },
	treeYellow  = { assetId = "rbxassetid://107450307411619", aspectRatio = 107 / 368 },
	bushGreen   = { assetId = "rbxassetid://99000623975742", aspectRatio = 123 / 42 },
	bushOlive   = { assetId = "rbxassetid://73323813253099", aspectRatio = 123 / 42 },
	bushDark    = { assetId = "rbxassetid://102733838106259", aspectRatio = 123 / 42 },
	bushDarker  = { assetId = "rbxassetid://128292360855433", aspectRatio = 123 / 42 },
	beehive     = { assetId = "rbxassetid://94049444649646", aspectRatio = 47 / 63 },
	mushroom    = { assetId = "rbxassetid://100577971224293", aspectRatio = 40 / 56 },
	chest       = { assetId = "rbxassetid://93605319180565", aspectRatio = 44 / 36 },
	flowerPurple = { assetId = "rbxassetid://128519321835276", aspectRatio = 24 / 26 },
}

-- Standable surfaces. The base ground is built from many grassGround chunks
-- placed edge-to-edge (loop below) rather than one repeating tile — the
-- source art is a single organic rock/grass chunk, not a designed
-- seamless-tile, so ScaleType.Tile would show visible seams; placing
-- discrete Fit-scaled chunks side by side (exactly like every other
-- platform piece) sidesteps that entirely and even reads as a nicer,
-- slightly organic cobbled path. Elevated pieces above it form the same
-- kind of journey as the previous desert layout: cabin-wall entrance ->
-- climb via rock/trunk -> plank-and-bridge sky walk -> clear ground
-- clearing at spawn -> a second cluster with the rock-ramp anchor ->
-- descent back to ground. Vertical rises stay within ~100-160px
-- (jumpVelocity/gravity give ~205px max single-jump height); horizontal
-- gaps are sized for how far you actually travel while falling/jumping.
GameConfig.World.platforms = {}
for x = 0, GameConfig.World.width - 1, GameConfig.World.groundChunkWidth do
	table.insert(GameConfig.World.platforms, {
		x1 = x,
		x2 = x + GameConfig.World.groundChunkWidth,
		y = GameConfig.World.groundY,
		texture = "grassGround",
	})
end

local elevatedPlatforms = {
	-- Forest-gate climb into a plank-and-bridge sky walk (x 100-1150)
	{ x1 = 100, x2 = 220, y = 540, texture = "cabinWall" }, -- entrance anchor
	{ x1 = 250, x2 = 330, y = 460, texture = "rockSmall" },
	{ x1 = 330, x2 = 460, y = 460, texture = "wide" },
	{ x1 = 460, x2 = 550, y = 350, texture = "pillar" }, -- tree-trunk climb
	{ x1 = 550, x2 = 650, y = 350, texture = "wide" },
	{ x1 = 650, x2 = 950, y = 250, texture = "floatPlank" }, -- long flat plank walk
	{ x1 = 950, x2 = 1150, y = 250, texture = "bridge" }, -- rope bridge continuing at the same height

	-- Descent, then a clear run of ground (spawn sits at width/2 = 2000)
	-- kept free of platforms so it reads as a clearing
	{ x1 = 1200, x2 = 1280, y = 340, texture = "rockSmall" },
	{ x1 = 1350, x2 = 1430, y = 440, texture = "narrow" },

	-- Second cluster around the rock-ramp anchor (x 2500-3100)
	{ x1 = 2500, x2 = 2620, y = 460, texture = "cabinWall" },
	{ x1 = 2620, x2 = 2700, y = 350, texture = "pillar" },
	{ x1 = 2700, x2 = 2900, y = 350, texture = "rockRamp" },
	{ x1 = 2900, x2 = 3100, y = 460, texture = "cabinWall" },

	-- Descent finish back to ground (x 3150-3720)
	{ x1 = 3150, x2 = 3250, y = 560, texture = "rockSmall" },
	{ x1 = 3300, x2 = 3380, y = 600, texture = "narrow" },
	{ x1 = 3430, x2 = 3550, y = 560, texture = "rock" },
	{ x1 = 3600, x2 = 3720, y = 600, texture = "wide" }, -- resting landmark near the world edge
}
for _, platform in ipairs(elevatedPlatforms) do
	table.insert(GameConfig.World.platforms, platform)
end

-- Set dressing — trees for tall background-scale scenery, bushes as
-- ground-level filler, small props scattered for detail.
GameConfig.World.decorations = {
	{ x1 = 500, x2 = 600, y = GameConfig.World.groundY, texture = "treeGreen" },
	{ x1 = 1700, x2 = 1800, y = GameConfig.World.groundY, texture = "treeGolden" },
	{ x1 = 2350, x2 = 2450, y = GameConfig.World.groundY, texture = "treeDark" },
	{ x1 = 3050, x2 = 3150, y = GameConfig.World.groundY, texture = "treeRed" },
	{ x1 = 3750, x2 = 3850, y = GameConfig.World.groundY, texture = "treeYellow" },
	{ x1 = 150, x2 = 270, y = GameConfig.World.groundY, texture = "bushGreen" },
	{ x1 = 1050, x2 = 1170, y = GameConfig.World.groundY, texture = "bushOlive" },
	{ x1 = 1900, x2 = 2020, y = GameConfig.World.groundY, texture = "bushDark" },
	{ x1 = 2750, x2 = 2870, y = GameConfig.World.groundY, texture = "bushDarker" },
	{ x1 = 380, x2 = 420, y = GameConfig.World.groundY, texture = "mushroom" },
	{ x1 = 1950, x2 = 2000, y = GameConfig.World.groundY, texture = "chest" }, -- near spawn
	{ x1 = 2050, x2 = 2075, y = GameConfig.World.groundY, texture = "flowerPurple" },
	{ x1 = 680, x2 = 720, y = 250, texture = "beehive" }, -- hanging near the plank walk
	{ x1 = 2950, x2 = 2990, y = 350, texture = "beehive" }, -- second cluster
	{ x1 = 3350, x2 = 3390, y = 600, texture = "mushroom" }, -- descent finish
}

-- Shared by server PhysicsStep and (for now, until Phase 3 fully lands)
-- client-side prediction/rendering. World px/sec and px/sec^2.
GameConfig.Physics = {
	gravity = 2200,
	jumpVelocity = -950,
}

-- Network tick rates (Phase 3+).
GameConfig.Net = {
	inputSendRate = 24, -- Hz, client -> server PlayerInput
	broadcastRate = 20, -- Hz, server -> client WorldSnapshot
}

GameConfig.Player = {
	-- hero2: regenerated from a 3/4 side-view (facing right) base instead of
	-- the original front-facing one, for a MapleStory-style side-scroller
	-- look. setFacing(true) mirrors this right-facing art for left-walking.
	assetId = "rbxassetid://124840409867821",
	displaySize = 260, -- on-screen square size in px
	-- Measured from the idle sprite's actual alpha bounding box within its
	-- 256x256 cell (pixel_unfake keeps the character at true small pixel-art
	-- scale, so most of the cell is transparent padding, concentrated above
	-- the character). Used to align the visual character — not the cell box
	-- — to the ground line and to the health bar.
	visualTopPad = 0.641,
	visualBottomPad = 0.094,
	moveSpeed = 220,
	maxHp = 100,
	attackDamage = 12,
	attackRange = 70, -- px, melee reach in facing direction
	attackCooldown = 0.5, -- seconds
	xpToLevel = function(level)
		return 20 + (level - 1) * 15
	end,
	states = {
		idle   = { row = 0, frames = 4, fps = 4, loop = true },
		attack = { row = 1, frames = 4, fps = 8, loop = false },
		jump   = { row = 2, frames = 4, fps = 8, loop = false },
		wave   = { row = 3, frames = 4, fps = 6, loop = false },
	},
}

GameConfig.Enemy = {
	assetId = "rbxassetid://129576592291092",
	displaySize = 72,
	visualTopPad = 0.094,
	visualBottomPad = 0.094,
	moveSpeed = 90,
	maxHp = 30,
	contactDamage = 8,
	contactCooldown = 1.0,
	xpReward = 10,
	aggroRange = 260, -- px, distance at which enemy starts chasing the player
	contactRange = 40, -- px, melee contact-damage range
	spawnIntervalSeconds = 3,
	maxAlive = 6,
	states = {
		idle   = { row = 0, frames = 4, fps = 4, loop = true },
		attack = { row = 1, frames = 3, fps = 8, loop = false },
		jump   = { row = 2, frames = 4, fps = 8, loop = false },
		wave   = { row = 3, frames = 4, fps = 6, loop = false },
	},
}

return GameConfig
