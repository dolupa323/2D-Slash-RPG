-- 캐릭터 · 졸개 한 몸의 그림. 동작(clip)과 장 번호를 주면 캐릭터 판에서 그 장을 잘라 발밑 가운데 (x, y)에 맞춰 놓는다.
--  판의 그림은 오른쪽을 본다. 왼쪽을 볼 때는 자르는 폭을 음수로 줘서 뒤집는다(그림을 따로 두지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local data = ReplicatedStorage.shared.lune.data
local CHARS = require(data["chars.generated"])
local ASSETS = require(data["assets.generated"])
local Stage = require(script.Parent.stage)

local Sprite = {}
Sprite.__index = Sprite
-- 고운 그림의 미리보기 배율(관리 창 「전투 → 보스 크기」): 동작에 k가 적힌 그림(스토리 보스)을 이 배만큼 더 크게 · 작게 그려 본다. 그림만 바뀐다(맞는 자리 · 몸의 판정은 설계값 그대로)
Sprite.preview = 1

-- mask = true면 같은 자리의 흰 실루엣 판(CHARS.masks)으로 그린다 — label.ImageColor3로 색을 입혀 한 색 실루엣을 만든다(대쉬의 잔상)
function Sprite.new(parent: Instance, who: string, z: number?, mask: boolean?)
	local char = CHARS.chars[who]
	assert(char, "없는 캐릭터 " .. tostring(who))
	local self = setmetatable({}, Sprite)
	self.who = who
	self.char = char
	self.pages = if mask then CHARS.masks else CHARS.pages
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

-- scale = 몸의 크기(거신의 두 배 — 발밑 가운데를 그대로 두고 커진다. 없으면 1)
function Sprite:set(clip: string, frame: number, x: number, y: number, dir: number, scale: number?)
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
		label.Image = ASSETS[self.pages[f[1]]] or ""
	end
	local w, h, dx, dy = f[4], f[5], f[6], f[7]
	local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
	-- 기준점: 캐릭터 동작은 발밑 가운데(ox, oy). 칸 크기가 따로인 동작(날아가는 그림)은 왼쪽 가운데다
	-- 제 기준점이 적힌 동작(몬스터의 마법 그림 = 발밑 가운데 · 날아가는 그림 = 한가운데)은 그것을 쓴다
	local ox, oy = char.ox, char.oy
	if c.ox then
		ox, oy = c.ox, c.oy
	elseif c.fw then
		ox, oy = 0, c.fh / 2
	end
	-- 고운 그림(c.k — 스토리 보스: 사용자가 만든 동작 그림을 받은 화소 그대로 싣고 작게 그린다. k = 그림 한 화소가 세계의 몇 점인가):
	--  부드럽게 줄여 그리고(도트 그림은 점이 또렷하게 — Pixelated) 자리와 크기를 점의 소수 자리까지 둔다. 사용자 2026-10-11: "게임에서 표현되어지는 크기를 줄이라는거에요 스프라이트를 건드리라는게아니라"
	local fine = c.k ~= nil
	local s = (scale or 1) * (if fine then c.k * Sprite.preview else 1)
	if self.fine ~= fine then
		self.fine = fine
		label.ResampleMode = if fine then Enum.ResamplerMode.Default else Enum.ResamplerMode.Pixelated
	end
	local function R(v: number): number
		return if fine then v else math.floor(v + 0.5)
	end
	label.Size = UDim2.fromOffset(R(w * s), R(h * s))
	if dir >= 0 then
		label.ImageRectOffset = Vector2.new(f[2], f[3])
		label.ImageRectSize = Vector2.new(w, h)
		label.Position = UDim2.fromOffset(px - R((ox - dx) * s), py - R((oy - dy) * s))
	else
		label.ImageRectOffset = Vector2.new(f[2] + w, f[3])
		label.ImageRectSize = Vector2.new(-w, h)
		label.Position = UDim2.fromOffset(px + R((ox - dx - w) * s), py - R((oy - dy) * s))
	end
	label.Visible = true
end

function Sprite:destroy()
	self.label:Destroy()
end

return Sprite
