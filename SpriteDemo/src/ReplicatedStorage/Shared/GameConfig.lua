-- Central config: sprite atlases (from sprite-gen manifest.json) + combat stats.
-- Keep this the single source of truth; client and server both require it.

local GameConfig = {}

GameConfig.CELL_WIDTH = 256
GameConfig.CELL_HEIGHT = 256

GameConfig.Arena = {
	width = 900,
	height = 500,
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
