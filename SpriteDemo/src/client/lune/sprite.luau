-- 캐릭터 · 졸개 한 몸의 그림. 동작(clip)과 장 번호를 주면 캐릭터 판에서 그 장을 잘라 발밑 가운데 (x, y)에 맞춰 놓는다.
--  판의 그림은 오른쪽을 본다. 왼쪽을 볼 때는 자르는 폭을 음수로 줘서 뒤집는다(그림을 따로 두지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local data = ReplicatedStorage.shared.lune.data
local CHARS = require(data["chars.generated"])
local ASSETS = require(data["assets.generated"])
local Stage = require(script.Parent.stage)

local Sprite = {}
Sprite.__index = Sprite

function Sprite.new(parent: Instance, who: string, z: number?)
	local char = CHARS.chars[who]
	assert(char, "없는 캐릭터 " .. tostring(who))
	local self = setmetatable({}, Sprite)
	self.who = who
	self.char = char
	self.label = Stage.image(parent, who, "", 1, 1)
	self.label.ZIndex = z or 1
	self.label.Visible = false
	self.page = 0
	return self
end

-- 동작의 장 번호(1부터). once = 한 번만 틀고 마지막 장에서 멈춘다
function Sprite.frameAt(char, clip: string, t: number, once: boolean?): number
	local c = char.clips[clip]
	local n = #c.frames
	local i = math.floor(t * c.fps)
	return (if once then math.min(n - 1, i) else i % n) + 1
end

function Sprite:set(clip: string, frame: number, x: number, y: number, dir: number)
	local char = self.char
	local c = char.clips[clip]
	local f = c and c.frames[frame]
	local label = self.label
	if not f then
		label.Visible = false -- 빈 장
		return
	end
	if self.page ~= f[1] then
		self.page = f[1]
		label.Image = ASSETS[CHARS.pages[f[1]]] or ""
	end
	local w, h, dx, dy = f[4], f[5], f[6], f[7]
	local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
	-- 기준점: 캐릭터 동작은 발밑 가운데(ox, oy). 칸 크기가 따로인 동작(날아가는 그림)은 왼쪽 가운데다
	local ox, oy = char.ox, char.oy
	if c.fw then
		ox, oy = 0, c.fh / 2
	end
	label.Size = UDim2.fromOffset(w, h)
	if dir >= 0 then
		label.ImageRectOffset = Vector2.new(f[2], f[3])
		label.ImageRectSize = Vector2.new(w, h)
		label.Position = UDim2.fromOffset(px - ox + dx, py - oy + dy)
	else
		label.ImageRectOffset = Vector2.new(f[2] + w, f[3])
		label.ImageRectSize = Vector2.new(-w, h)
		label.Position = UDim2.fromOffset(px + ox - dx - w, py - oy + dy)
	end
	label.Visible = true
end

function Sprite:destroy()
	self.label:Destroy()
end

return Sprite
