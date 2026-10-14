-- 「달의 계승자」 — 체력 바의 효과(shared/lune/ui/hpFx.luau) · 마을에서 망루까지의 길(문의 수).
--  사용자 2026-10-13: "플레이어 체력표기 gui 체력 다는거나  회복되는게 잘 보이지않습니다. 효과가 좀 들어가야해요"
--                    "초승달마을에서 망루까지 가는게 과하게 깁니다 … 망루까지 지금 10개넘게 포탈을 타야하는게 문제입니다. 마을~ 망루 까지 사냥터 좀 줄이세요"
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local HpFx = req("ReplicatedStorage/shared/lune/ui/hpFx")
local F = HpFx.F
local function near(a, b, msg)
	expect(math.abs(a - b) < 1e-6, ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

-- ---- 1) 체력 바의 효과 ----
local st = HpFx.new()
expect(HpFx.idle(st), "처음에는 그릴 것이 없다")
HpFx.set(st, 0.8, 160)
expect(st.fill == 0.8 and st.lag == 0.8 and st.flash == 0 and HpFx.idle(st) and HpFx.deltaText(st) == nil, "처음 받은 체력은 효과 없이 그대로 놓는다")
-- 닳는다: 빨간 띠는 바로 줄고, 닳은 자리가 밝게 남는다 · 번쩍인다 · 「-40」
HpFx.set(st, 0.6, 120)
expect(st.fill == 0.6 and st.lag == 0.8 and st.kind == "hurt" and st.flash == F.flash and not HpFx.idle(st), "닳으면 빨간 띠는 바로 줄고 닳은 자리(0.8까지)가 남는다")
eq((HpFx.deltaText(st)), "-40", "닳은 수가 뜬다")
HpFx.step(st, F.hold * 0.5)
near(st.lag, 0.8, "잠깐(hold)은 그대로 남아 있다")
HpFx.step(st, F.hold * 0.5 + 0.1)
expect(st.lag < 0.8 and st.lag > 0.6, "그 뒤에 따라 줄어든다 " .. st.lag)
-- 잇달아 닳는다: 숫자를 더한다 · 닳은 자리는 가장 높았던 데서 이어진다
HpFx.set(st, 0.5, 100)
eq((HpFx.deltaText(st)), "-60", "잇달아 닳으면 숫자를 더한다")
expect(st.fill == 0.5 and st.lag > 0.5, "닳은 자리가 이어진다")
for _ = 1, 200 do
	HpFx.step(st, 1 / 60)
end
expect(HpFx.idle(st) and st.lag == st.fill and st.fill == 0.5 and HpFx.deltaText(st) == nil, "조금 뒤에는 효과가 끝난다(띠만 남는다)")
-- 찬다: 찬 자리가 풀빛으로 먼저 보이고 빨간 띠가 차오른다 · 「+60」
HpFx.set(st, 0.8, 160)
expect(st.gain == 0.8 and st.fill == 0.5 and st.kind == "heal" and st.flash == F.flash, "차면 찬 자리(0.8까지)가 먼저 보이고 빨간 띠는 아직 그 자리다")
eq((HpFx.deltaText(st)), "+60", "찬 수가 뜬다")
HpFx.step(st, 0.1)
expect(st.fill > 0.5 and st.fill < 0.8, "빨간 띠가 차오른다 " .. st.fill)
for _ = 1, 200 do
	HpFx.step(st, 1 / 60)
end
expect(HpFx.idle(st) and st.fill == 0.8, "다 차오르면 끝난다")
-- 차는 중에 닳는다: 빨간 띠가 새 체력을 넘지 않는다
HpFx.set(st, 1, 200)
HpFx.step(st, 0.05)
HpFx.set(st, 0.3, 60)
expect(st.fill <= 0.3 + 1e-9 and st.gain <= 0.3 + 1e-9 and st.lag >= st.fill, "차는 중에 닳아도 띠가 새 체력을 넘지 않는다")
eq((HpFx.deltaText(st)), "-140", "방향이 바뀌면 숫자를 새로 센다")
-- 같은 값을 다시 받으면 아무 일도 없다
for _ = 1, 300 do
	HpFx.step(st, 1 / 60)
end
HpFx.set(st, 0.3, 60)
expect(HpFx.idle(st), "같은 체력을 다시 받으면 효과가 없다(내 상태는 자주 다시 온다)")
-- 수: 눈에 보일 만큼 길고, 싸움을 가리지 않을 만큼 짧다
expect(F.hold >= 0.2 and F.hold <= 0.6 and F.flash >= 0.1 and F.flash <= 0.4 and F.delta >= 0.5 and F.delta <= 1.5, "효과의 시간")
expect(F.flashA > 0.3 and F.flashA <= 1 and F.deltaUp >= 4, "번쩍임의 진하기 · 숫자가 떠오르는 높이")

-- ---- 2) 마을에서 망루까지: 문 일곱(전에는 열) ----
local function hops(from: string, to: string): number?
	local dist, queue, at = { [from] = 0 }, { from }, 1
	while queue[at] do
		local key = queue[at]
		at += 1
		if key == to then
			return dist[key]
		end
		for _, p in SCENES.scenes[key].portals do
			if SCENES.scenes[p.to] and dist[p.to] == nil and not p.need then
				dist[p.to] = dist[key] + 1
				table.insert(queue, p.to)
			end
		end
	end
	return nil
end
local toTower = hops("town", "r1c1")
expect(toTower ~= nil and toTower <= 7, ("초승달 마을에서 망루 1층까지 문 %s개(일곱을 넘지 않는다)"):format(tostring(toTower)))
eq(hops("town", "r1cc"), 6, "수비대 야영지까지 여섯")
eq(hops("town", "r1bv"), 4, "고갯마루 주막까지 넷")
-- 줄기에 있는 사냥터(몬스터가 있는 맵)는 셋을 넘지 않는다: 마을 어귀 · 고갯길 초입 · 무너진 다리
do
	local prev, queue, at = { town = "town" }, { "town" }, 1
	while queue[at] do
		local key = queue[at]
		at += 1
		for _, p in SCENES.scenes[key].portals do
			if SCENES.scenes[p.to] and prev[p.to] == nil and not p.need then
				prev[p.to] = key
				table.insert(queue, p.to)
			end
		end
	end
	local n, cur = 0, prev.r1c1
	while cur ~= "town" do
		if #SCENES.scenes[cur].mobs > 0 then
			n += 1
		end
		cur = prev[cur]
	end
	expect(n <= 3, ("마을에서 망루까지 지나는 사냥터는 %d곳(셋을 넘지 않는다)"):format(n))
end
-- 가지가 된 사냥터들도 모두 걸어서 닿는다 · 돌아올 수 있다
for _, key in { "hunt", "r1a3", "r1a4", "r1b2", "r1b4", "r1bh", "r1bl", "r1c3", "r1c4" } do
	expect(hops("town", key) ~= nil and hops(key, "town") ~= nil, key .. " — 마을에서 닿고 마을로 돌아온다")
end
-- 사당 지하: 월드맵에 마디가 있다
local WM = req("ReplicatedStorage/shared/lune/ui/worldmap")
local rid, node = WM.nodeOf("in_cellar")
expect(rid == "r1" and node == "r1cs", "사당 지하는 월드맵의 제 마디다")
local rid2, node2 = WM.nodeOf("in_shrine")
expect(rid2 == "r1" and node2 == "town", "달의 사당 안은 마을의 마디다")
local card = WM.region("r1")
expect(card.art ~= nil and card.art.at.r1cs ~= nil, "사당 지하의 자리가 그림 위에 있다")
