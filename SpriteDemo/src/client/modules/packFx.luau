-- 팩 이펙트 재생기(클라) — Ninja Adventure 팩 이펙트 시트(assets/ninja/fx.png, townAssets.FX)의 한 줄짜리 애니메이션을 그린다.
--  이펙트 이름·자리는 shared/data/ninjaFx.generated.luau(공방 js/ninja/pack.js FX_SHEETS). 시트 업로드 전이면 아무것도 안 그린다.
--  쓰는 곳: 인술 연출(town/ninjutsuFx) · 무기 맞음(town/weapon HitSlash) · 폭탄 터짐(town/monsters) · 레벨업(levelUpEffect).
--  modules/ 루트라 sceneLoader가 자동으로 load/unload를 부르지 않는다 — 쓰는 모듈이 직접 require한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local sheet = require(ReplicatedStorage.shared.data["ninjaFx.generated"])

local FT = sheet.frameTime
local DEFAULT_SCALE = townWorld.data.scale -- 이펙트 1도트 = 바닥 1도트(캐릭터·몬스터와 같은 밀도)
local DEFAULT_Z = 8900 -- 월드 그림 위, 머리 위 글씨(9001~)·데미지 숫자(9500) 아래

local exports = {}
local active = {} -- [label] = parent

-- 머무는 장이 있는 이펙트인가(깔렸다 → 머묾 → 사라짐)
function exports.Hold(name: string?): boolean
	local r = name and sheet.rects[name]
	return r ~= nil and r.hold ~= nil
end

function exports.Has(name: string?): boolean
	return name ~= nil and sheet.rects[name] ~= nil
end

-- 이펙트 하나 재생. where(t) → 가운데 자리(parent 안 px, Vector2) 또는 nil(그만).
--  opt: delay(초 뒤 시작) · loop · duration(loop일 때 길이) · rotation(도) · bottom(자리 = 그림 아래 가운데) · scale(1도트 = px) · zIndex
--       · hold(초 — 시트에 머무는 장(hold)이 있는 이펙트가 그 장에서 머무는 시간: 깔렸다 → 머묾 → 사라짐)
--       · token(표 — token.dead = true로 만들면 그 자리에서 끝난다: 설치한 것이 일찍 사라질 때)
function exports.Play(parent: Instance?, name: string?, where, opt)
	local r = name and sheet.rects[name]
	if not r or not parent or (townAssets.FX or "") == "" then
		return
	end
	opt = opt or {}
	local scale = opt.scale or DEFAULT_SCALE
	task.spawn(function()
		local label = Instance.new("ImageLabel")
		label.Name = "PackFx"
		label.BackgroundTransparency = 1
		label.Image = townAssets.FX
		label.ImageRectSize = Vector2.new(r.w, r.h)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.AnchorPoint = Vector2.new(0.5, if opt.bottom then 1 else 0.5)
		label.Size = UDim2.fromOffset(r.w * scale, r.h * scale)
		label.Rotation = opt.rotation or 0
		label.ZIndex = opt.zIndex or DEFAULT_Z
		label.Visible = false
		label.Parent = parent
		active[label] = parent
		local t = -(opt.delay or 0)
		while label.Parent and not (opt.token and opt.token.dead) do
			t += task.wait()
			if t < 0 then
				continue
			end
			local f = math.floor(t / FT)
			if r.hold and opt.hold and not opt.loop then
				local before = r.hold * FT
				if t >= before then
					f = if t < before + opt.hold then r.hold else r.hold + 1 + math.floor((t - before - opt.hold) / FT)
				end
			end
			if opt.loop then
				if opt.duration and t >= opt.duration then
					break
				end
				f %= r.frames
			elseif f >= r.frames then
				break
			end
			local at = where(t)
			if not at then
				break
			end
			label.ImageRectOffset = Vector2.new(r.x + f * r.w, r.y)
			label.Position = UDim2.fromOffset(math.round(at.X), math.round(at.Y))
			label.Visible = true
		end
		active[label] = nil
		label:Destroy()
	end)
end

-- 그 parent 아래에서 재생 중인 이펙트를 모두 지운다(씬을 내릴 때)
function exports.Clear(parent: Instance?)
	for label, owner in active do
		if owner == parent then
			active[label] = nil
			label:Destroy()
		end
	end
end

return exports
