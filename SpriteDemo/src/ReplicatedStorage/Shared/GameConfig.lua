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
	groundThickness = 100, -- purely cosmetic (physics uses groundY, not this) — sized to read as a real dirt path once textured, not a thin line
	-- Desert-village dirt path tile (sprite-gen, runs/town/ground_tile.png),
	-- rendered ScaleType.Tile so it repeats across the whole World.width.
	groundTextureAssetId = "rbxassetid://126676116585222",
	groundTileWorldSize = 128, -- world px per texture repeat
	-- Desert canyon backdrop (sprite-gen, runs/town/background.png, source
	-- 1665x945px). Rendered ScaleType.Tile at its native aspect ratio,
	-- scrolling at backgroundParallaxFactor of the foreground camera speed
	-- for a basic depth cue (mountains "further away" than the ground line).
	backgroundAssetId = "rbxassetid://123964520230006",
	backgroundAspectRatio = 1665 / 945,
	backgroundParallaxFactor = 0.4,
}
GameConfig.World.groundY = GameConfig.World.height - GameConfig.World.groundMargin

-- Dedicated pixel-art terrain pieces (sprite-gen, runs/town/platform_*.png),
-- each a standalone rock chunk on a transparent background with its flat
-- top surface drawn near the top edge of the image (so anchoring the
-- image's top-left to a platform's collision y lines the art up with the
-- collision surface). aspectRatio = native width/height, used to size each
-- instance without distortion (see HeroSpriteDemo.client.lua render loop).
GameConfig.World.platformTextures = {
	-- Base ground is the one tiled (repeating strip) surface; everything
	-- else below is a single non-tiled rock-chunk image.
	ground      = { assetId = GameConfig.World.groundTextureAssetId, tile = true, tileWorldSize = GameConfig.World.groundTileWorldSize },
	wide        = { assetId = "rbxassetid://117308572215729", aspectRatio = 1536 / 1024 }, -- wide flat-top slab
	narrow      = { assetId = "rbxassetid://97422024651159", aspectRatio = 1254 / 1254 }, -- small ledge
	rock        = { assetId = "rbxassetid://95288075916163", aspectRatio = 1254 / 1254 }, -- small floating stepping-stone
	pillar      = { assetId = "rbxassetid://127620933867297", aspectRatio = 1024 / 1536 }, -- tall tower-base column
	ledgeTiny   = { assetId = "rbxassetid://83399260685924", aspectRatio = 1254 / 1254 }, -- tiniest stepping-stone
	arch        = { assetId = "rbxassetid://131166177161247", aspectRatio = 1122 / 1402 }, -- tall rock arch with a hole
	bridge      = { assetId = "rbxassetid://124027933378741", aspectRatio = 1774 / 887 }, -- long rope/plank bridge span
	towerWall   = { assetId = "rbxassetid://96259290062678", aspectRatio = 1536 / 1024 }, -- big architectural block (door/banner)
	stairsLedge = { assetId = "rbxassetid://103051054584210", aspectRatio = 1536 / 1024 }, -- flat-top with carved side stairs
}

-- Decorative-only pieces placed on top of platforms — never checked by
-- PhysicsStep, purely visual (see the separate decorations render loop in
-- HeroSpriteDemo.client.lua). Same {x1,x2,y,texture} shape as platforms for
-- consistency, but y here just anchors the image's top edge, no collision
-- meaning.
GameConfig.World.decorationTextures = {
	crate   = { assetId = "rbxassetid://106620797064599", aspectRatio = 1254 / 1254 },
	barrel  = { assetId = "rbxassetid://110601090532278", aspectRatio = 1774 / 887 },
	pot     = { assetId = "rbxassetid://118065835463325", aspectRatio = 1254 / 1254 },
	banner  = { assetId = "rbxassetid://97226640538443", aspectRatio = 1254 / 1254 },
	lantern = { assetId = "rbxassetid://97722818056545", aspectRatio = 1254 / 1254 },
	ladder  = { assetId = "rbxassetid://117108973768517", aspectRatio = 1254 / 1254 },
}

-- Standable surfaces, composed as a deliberate journey rather than a
-- mechanical repeat of the same shapes: town-gate tower -> stair climb ->
-- bridge-and-arch sky walk -> clear ground market square at spawn (kept
-- free of platforms so it reads as a hub) -> twin towers -> a descending
-- stair-down finish. All ten terrain pieces get used, several more than
-- once, the way a real hand-built level reuses a kit of parts. Vertical
-- rises stay within ~100-160px (jumpVelocity/gravity give ~205px max
-- single-jump height); horizontal gaps are sized for how far you actually
-- travel while falling/jumping at moveSpeed, not just eyeballed.
GameConfig.World.platforms = {
	{ x1 = 0, x2 = GameConfig.World.width, y = GameConfig.World.groundY, texture = "ground" }, -- base ground

	-- Town-gate tower climbing into a bridge-and-arch sky walk (x 100-1730)
	{ x1 = 100, x2 = 400, y = 540, texture = "towerWall" }, -- entrance anchor
	{ x1 = 430, x2 = 510, y = 460, texture = "ledgeTiny" },
	{ x1 = 510, x2 = 780, y = 460, texture = "wide" },
	{ x1 = 780, x2 = 980, y = 350, texture = "stairsLedge" },
	{ x1 = 980, x2 = 1130, y = 250, texture = "pillar" }, -- tower top
	{ x1 = 1130, x2 = 1530, y = 250, texture = "bridge" }, -- long span at tower-top height
	{ x1 = 1530, x2 = 1730, y = 250, texture = "arch" }, -- dramatic arch continuing the walk

	-- One stepping-stone down, then a clear run of ground (x 1790-2300,
	-- spawn sits at width/2 = 2000) kept free of platforms as a market hub
	{ x1 = 1790, x2 = 1890, y = 420, texture = "rock" },
	{ x1 = 2050, x2 = 2150, y = 520, texture = "narrow" }, -- optional side step, doesn't block the hub

	-- Twin towers, a different pillar/arch mix than the first climb (x 2300-3250)
	{ x1 = 2300, x2 = 2600, y = 460, texture = "towerWall" },
	{ x1 = 2600, x2 = 2750, y = 350, texture = "pillar" },
	{ x1 = 2750, x2 = 2950, y = 350, texture = "arch" },
	{ x1 = 2950, x2 = 3250, y = 460, texture = "towerWall" },

	-- Stair-down finish back toward ground (x 3300-3900)
	{ x1 = 3300, x2 = 3500, y = 560, texture = "stairsLedge" },
	{ x1 = 3520, x2 = 3600, y = 600, texture = "ledgeTiny" },
	{ x1 = 3650, x2 = 3750, y = 560, texture = "rock" },
	{ x1 = 3750, x2 = 3900, y = 600, texture = "wide" }, -- resting landmark near the world edge
}

-- Set dressing on top of the platforms above — purely cosmetic, two of
-- each prop so both towers/zones feel dressed rather than one-off.
GameConfig.World.decorations = {
	{ x1 = 150, x2 = 210, y = 540, texture = "crate" }, -- gate tower
	{ x1 = 220, x2 = 280, y = 540, texture = "barrel" },
	{ x1 = 405, x2 = 465, y = 540, texture = "ladder" }, -- leaning up toward the ledge above
	{ x1 = 1260, x2 = 1330, y = 250, texture = "lantern" }, -- hanging on the bridge
	{ x1 = 1610, x2 = 1680, y = 250, texture = "banner" }, -- on the arch
	{ x1 = 1950, x2 = 2010, y = GameConfig.World.groundY, texture = "pot" }, -- market square, ground level
	{ x1 = 2160, x2 = 2220, y = GameConfig.World.groundY, texture = "crate" },
	{ x1 = 2330, x2 = 2390, y = 460, texture = "ladder" }, -- second tower
	{ x1 = 2810, x2 = 2880, y = 350, texture = "banner" }, -- second arch
	{ x1 = 3060, x2 = 3120, y = 460, texture = "pot" },
	{ x1 = 3360, x2 = 3420, y = 560, texture = "lantern" }, -- stair-down finish
	{ x1 = 3670, x2 = 3730, y = 560, texture = "barrel" },
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
