-- Owns this client's camera state and the world->screen transform. World
-- coordinates are shared/simulation-space (see GameConfig.World); screen
-- coordinates are this client's own viewport pixels. Only Camera ever reads
-- camera.ViewportSize — nothing in the simulation or render code downstream
-- should touch it directly, so behavior stays identical regardless of each
-- player's window size.
--
-- UNIFORM SCALE (the responsive-layout fix): the game world is designed at
-- a reference height (GameConfig.World.height, e.g. 720 world px tall — the
-- distance from the sky to the ground). Every device's viewport gets a
-- `scale = viewport.Y / designHeight` factor, applied uniformly to X, Y, AND
-- sprite display sizes (see setSpriteWorldCenter in the client script). This
-- guarantees the full vertical play area (ground + character) always fits
-- exactly within the actual viewport height, on any aspect ratio — a
-- landscape phone with little height just sees a smaller-but-proportional
-- version of the same view a tall desktop window sees, never a view where
-- the ground/characters have scrolled below the visible area (which is what
-- happened before this fix: world Y was mapped 1:1 to screen px, so a
-- viewport shorter than the 720 design height simply couldn't show
-- everything from y=0 to the ground line).
local Camera = {}
Camera.__index = Camera

function Camera.new(worldWidth, worldHeight, viewport, designHeight)
	local self = setmetatable({}, Camera)
	self.worldWidth = worldWidth
	self.worldHeight = worldHeight
	self.designHeight = designHeight or worldHeight
	self.viewport = viewport
	self.scale = viewport.Y / self.designHeight
	self.x = (viewport.X / self.scale) / 2 -- world x currently at the center of the screen
	return self
end

function Camera:setViewport(viewport)
	self.viewport = viewport
	self.scale = viewport.Y / self.designHeight
end

function Camera:getScale()
	return self.scale
end

-- Side-scroller: only X scrolls. Y stays fixed (scaled, not scrolled) so the
-- ground line never moves vertically on screen (revisit if multi-height
-- platforms need vertical follow later).
function Camera:follow(targetWorldX)
	local halfWidthWorld = (self.viewport.X / self.scale) / 2
	local maxX = math.max(halfWidthWorld, self.worldWidth - halfWidthWorld)
	self.x = math.clamp(targetWorldX, halfWidthWorld, maxX)
end

function Camera:worldToScreen(worldX, worldY)
	local screenX = (worldX - self.x) * self.scale + self.viewport.X / 2
	local screenY = worldY * self.scale
	return screenX, screenY
end

-- Cheap visibility check for culling before even touching a pooled instance.
function Camera:isWorldXVisible(worldX, margin)
	margin = margin or 0
	local screenX = (worldX - self.x) * self.scale + self.viewport.X / 2
	return screenX >= -margin and screenX <= self.viewport.X + margin
end

return Camera
