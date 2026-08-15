-- (test comment)
-- Thin wrapper over Packages.SpriteClip2.ImageSprite: one ImageSprite per named
-- state (idle/attack/jump/wave), all sharing one ImageLabel adornee. Switching
-- state = stop the old ImageSprite, play the new one. SpriteClip2 self-drives
-- via its own Scheduler, so callers never need to step(dt) manually.
--
-- SpriteClip2's isLooped is read-only after construction, which is why each
-- state gets its own ImageSprite instance instead of mutating one shared one.

local SpriteClip2 = require(script.Parent.Parent.Packages.SpriteClip2)

local CharacterAnimator = {}
CharacterAnimator.__index = CharacterAnimator

function CharacterAnimator.new(imageLabel, states, assetId, cellWidth, cellHeight)
	local self = setmetatable({}, CharacterAnimator)
	self.imageLabel = imageLabel
	self.cellWidth = cellWidth
	self.cellHeight = cellHeight
	self.facingLeft = false
	self.playingOneShot = false
	self.sprites = {}
	self.currentName = nil
	self._frameChangedConn = nil
	-- The last ImageRectOffset SpriteClip2 itself wrote for the current frame
	-- (guaranteed unflipped). Flip rendering always derives from this, never
	-- from re-reading the (possibly already-flipped) live property — reading
	-- back a live property that a previous call already mutated is what
	-- caused the offset to drift further right on every repeated flip.
	self._baseOffset = Vector2.new(0, 0)

	for name, state in pairs(states) do
		self.sprites[name] = SpriteClip2.ImageSprite.new({
			adornee = imageLabel,
			spriteSheetId = assetId,
			spriteSize = Vector2.new(cellWidth, cellHeight),
			edgeOffset = Vector2.new(0, state.row * cellHeight),
			spriteCount = state.frames,
			columnCount = state.frames,
			frameRate = state.fps,
			isLooped = state.loop,
		})
	end

	self:_switchTo("idle")
	return self
end

-- Renders the current facing state from the last known-good base offset.
function CharacterAnimator:_render()
	if self.facingLeft then
		self.imageLabel.ImageRectOffset = Vector2.new(self._baseOffset.X + self.cellWidth, self._baseOffset.Y)
		self.imageLabel.ImageRectSize = Vector2.new(-self.cellWidth, self.cellHeight)
	else
		self.imageLabel.ImageRectOffset = self._baseOffset
		self.imageLabel.ImageRectSize = Vector2.new(self.cellWidth, self.cellHeight)
	end
end

function CharacterAnimator:_switchTo(name, isOneShot, onOneShotComplete)
	local next = self.sprites[name]
	if not next then
		return
	end

	if self._frameChangedConn then
		self._frameChangedConn:Disconnect()
		self._frameChangedConn = nil
	end
	if self._frameLastConn then
		self._frameLastConn:Disconnect()
		self._frameLastConn = nil
	end

	if self.currentName then
		local current = self.sprites[self.currentName]
		if current then
			current:Stop()
		end
	end

	self.currentName = name
	self._frameChangedConn = next:GetSignal("FrameChanged"):Connect(function()
		self._baseOffset = self.imageLabel.ImageRectOffset
		self:_render()
	end)

	-- Always revert to idle when a one-shot (attack/jump/wave) finishes, with
	-- or without a caller-supplied callback — previously this listener was
	-- only wired when a callback was passed, so playOnce("jump") (no
	-- callback) left playingOneShot stuck true forever and the sprite frozen
	-- on the animation's last frame.
	if isOneShot then
		self._frameLastConn = next:GetSignal("FrameLast"):Connect(function()
			self._frameLastConn:Disconnect()
			self._frameLastConn = nil
			self.playingOneShot = false
			self:_switchTo("idle")
			if onOneShotComplete then
				onOneShotComplete(name)
			end
		end)
	end

	next:Play()
	self._baseOffset = self.imageLabel.ImageRectOffset
	self:_render()
end

function CharacterAnimator:playOnce(name, onComplete)
	if self.playingOneShot then
		return false
	end
	self.playingOneShot = true
	self:_switchTo(name, true, onComplete)
	return true
end

function CharacterAnimator:setLoopState(name)
	if self.playingOneShot or self.currentName == name then
		return
	end
	self:_switchTo(name)
end

function CharacterAnimator:setFacing(facingLeft)
	if self.facingLeft == facingLeft then
		return
	end
	self.facingLeft = facingLeft
	self:_render()
end

function CharacterAnimator:destroy()
	if self._frameChangedConn then
		self._frameChangedConn:Disconnect()
	end
	for _, sprite in pairs(self.sprites) do
		sprite:Stop()
	end
end

return CharacterAnimator
