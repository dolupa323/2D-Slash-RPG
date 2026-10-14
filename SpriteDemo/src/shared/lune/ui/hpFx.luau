-- 체력 바의 효과 — 화면을 모르는 셈(그리는 것은 client/lune/hud.luau · 공방 시험 탭의 js/lune/ui/hpfx.js와 같은 셈이다).
--  사용자 2026-10-13: "플레이어 체력표기 gui 체력 다는거나  회복되는게 잘 보이지않습니다. 효과가 좀 들어가야해요"
--  닳을 때: 빨간 띠는 바로 줄고, 닳은 만큼이 밝은 색으로 잠깐 남았다가(hold) 따라 줄어든다(drain) · 띠가 희게 번쩍인다 · 「-23」이 떠오른다
--  찰 때: 찬 만큼이 풀빛으로 먼저 보이고 빨간 띠가 그 자리까지 차오른다(fill) · 풀빛으로 번쩍인다 · 「+60」이 떠오른다
--  수는 공방의 UILAYOUT.vitals.fx(data/ui.generated.luau).
--  상태: fill = 빨간 띠(0~1 — 처음에는 nil) · lag = 닳은 자리의 끝 · gain = 찬 자리의 끝 · hold · flash(남은 초) · kind("hurt" | "heal") · delta(더한 수) · deltaT(남은 초) · to(지금의 체력 0~1) · hp
local F = require(script.Parent.Parent.data["ui.generated"]).layout.vitals.fx

local HpFx = {}
HpFx.F = F

function HpFx.new()
	return { fill = nil :: number?, lag = 0, gain = 0, hold = 0, flash = 0, kind = nil :: string?, delta = 0, deltaT = 0, hp = 0, to = 0 }
end

-- 새 체력(ratio 0~1 · hp = 숫자): 처음이면 그대로 놓고, 닳았으면 · 찼으면 효과를 건다
function HpFx.set(st, ratio: number, hp: number)
	if st.fill == nil then
		st.fill, st.lag, st.gain, st.to, st.hp = ratio, ratio, ratio, ratio, hp
		return
	end
	local d = hp - st.hp
	if d == 0 and ratio == st.to then
		return
	end
	if ratio < st.to then
		st.lag = math.max(st.lag, st.fill)
		st.fill = math.min(st.fill, ratio)
		st.gain = math.min(st.gain, ratio)
		st.hold, st.flash, st.kind = F.hold, F.flash, "hurt"
	elseif ratio > st.to then
		st.gain = ratio
		st.flash, st.kind = F.flash, "heal"
	end
	if d ~= 0 then
		-- 잇달아 닳으면(merge초 안) 숫자를 더한다
		st.delta = if st.deltaT > F.delta - F.merge and math.sign(st.delta) == math.sign(d) then st.delta + d else d
		st.deltaT = F.delta
	end
	st.to, st.hp = ratio, hp
end

function HpFx.step(st, dt: number)
	if st.fill == nil then
		return
	end
	st.flash = math.max(0, st.flash - dt)
	st.deltaT = math.max(0, st.deltaT - dt)
	if st.fill < st.to then
		st.fill = math.min(st.to, st.fill + F.fill * dt) -- 차오른다
	end
	-- 닳은 자리: 잠깐(hold) 남아 있다가 따라 줄어든다 — 한 장 안에서 hold가 끝나면 남은 시간만큼은 줄인다
	local left = dt
	if st.hold > 0 then
		local used = math.min(st.hold, left)
		st.hold -= used
		left -= used
	end
	if st.hold <= 0 and st.lag > st.fill then
		st.lag = math.max(st.fill, st.lag - F.drain * left)
	end
	if st.lag < st.fill then
		st.lag = st.fill
	end
end

-- 효과가 다 끝났는가(그릴 것이 없다)
function HpFx.idle(st): boolean
	return st.fill == nil or (st.flash <= 0 and st.deltaT <= 0 and st.fill == st.to and st.lag <= st.fill)
end

-- 떠오르는 글: 「-23」 · 「+60」(없으면 nil), 그리고 얼마나 떠올랐는가(도트)
function HpFx.deltaText(st): (string?, number)
	if st.deltaT <= 0 or st.delta == 0 then
		return nil, 0
	end
	return (if st.delta > 0 then "+" else "") .. tostring(st.delta), math.floor(F.deltaUp * (1 - st.deltaT / F.delta) + 0.5)
end

return HpFx
