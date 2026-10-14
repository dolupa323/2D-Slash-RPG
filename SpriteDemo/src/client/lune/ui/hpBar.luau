-- 체력 띠의 효과를 띠(Ui.bar)에 붙인다 — 몬스터 머리 위의 띠 · 보스의 넓은 바(플레이어의 체력 바는 hud.luau가 같은 셈으로 그린다).
--  사용자 2026-10-13: "몬스터 체력바도  유저 체력바처럼 고도화 되어야합니다."
--  셈은 shared/lune/ui/hpFx.luau(플레이어의 것과 같다 · 수는 공방의 UILAYOUT.vitals.fx):
--   닳을 때 = 빨간 띠는 바로 줄고, 닳은 만큼이 밝은 색으로 잠깐 남았다가 따라 줄어든다 + 띠가 희게 번쩍인다
--   찰 때   = 찬 만큼이 풀빛으로 먼저 보이고 빨간 띠가 차오른다 + 풀빛으로 번쩍인다
--  몬스터에게는 「-23」 같은 글을 띄우지 않는다(피해 숫자가 이미 몬스터 위에 뜬다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local HpFx = require(lune.ui.hpFx)
local Ui = require(script.Parent.ui)

local HpBar = {}
HpBar.__index = HpBar

local function hex(h: string): Color3
	return Color3.fromRGB(tonumber(h:sub(2, 3), 16) :: number, tonumber(h:sub(4, 5), 16) :: number, tonumber(h:sub(6, 7), 16) :: number)
end

-- bar = Ui.bar가 만든 띠 · w · h = 그 띠의 크기(테두리까지)
function HpBar.attach(bar, w: number, h: number)
	local F = HpFx.F
	local self = setmetatable({ bar = bar, w = w - 2, h = h - 2, st = HpFx.new() }, HpBar)
	self.lag = Ui.box(bar.frame, 1, 1, 0, self.h, hex(F.lagColor))
	self.lag.Name = "Lag"
	self.gain = Ui.box(bar.frame, 1, 1, 0, self.h, hex(F.gainColor))
	self.gain.Name = "Gain"
	bar.fill.ZIndex = 2 -- 빨간 띠는 그 둘 위에
	self.lag.ZIndex, self.gain.ZIndex = 1, 1
	self.flash = Ui.box(bar.frame, 1, 1, self.w, self.h, Color3.new(1, 1, 1))
	self.flash.Name = "Flash"
	self.flash.ZIndex = 3
	self.flash.BackgroundTransparency = 1
	self.heal = hex(F.gainColor)
	return self
end

function HpBar:draw()
	local st = self.st
	if st.fill == nil then
		return
	end
	local function px(v: number): number
		return math.floor(self.w * math.clamp(v, 0, 1) + 0.5)
	end
	self.bar:set(st.fill)
	self.lag.Size = UDim2.fromOffset(if st.lag > st.fill then px(st.lag) else 0, self.h)
	self.gain.Size = UDim2.fromOffset(if st.gain > st.fill then px(st.gain) else 0, self.h)
	self.flash.BackgroundColor3 = if st.kind == "heal" then self.heal else Color3.new(1, 1, 1)
	self.flash.BackgroundTransparency = 1 - HpFx.F.flashA * st.flash / HpFx.F.flash
end

-- 새 체력(ratio 0~1 · hp = 숫자). 처음(또는 reset 뒤)에는 효과 없이 그대로 놓는다
function HpBar:set(ratio: number, hp: number)
	HpFx.set(self.st, ratio, hp)
	self:draw()
end

-- 장마다: 효과를 흘려보낸다
function HpBar:step(dt: number)
	if not HpFx.idle(self.st) then
		HpFx.step(self.st, dt)
		self:draw()
	end
end

-- 효과가 아직 보이는가(닳은 자리가 줄어드는 중 · 번쩍이는 중)
function HpBar:busy(): boolean
	return not HpFx.idle(self.st)
end

-- 처음으로(다시 나타난 몬스터 · 다른 보스): 다음 set은 효과 없이 놓인다
function HpBar:reset()
	self.st = HpFx.new()
	self.lag.Size = UDim2.fromOffset(0, self.h)
	self.gain.Size = UDim2.fromOffset(0, self.h)
	self.flash.BackgroundTransparency = 1
end

return HpBar
