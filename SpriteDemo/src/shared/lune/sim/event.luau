-- 기간 이벤트(2026-10-29 — 공방 js/lune/design/event.js · 할로윈) — 날짜가 되면 저절로 켜지고 지나면 저절로 꺼진다.
--  사용자: "할로윈 날짜 1주전후로 할로윈 이벤트 자동발동되게 할로윈 이벤트 만들고" → 같은 날 "할로윈 이벤트 상점 ui 처럼해 … 한정 할로윈 라이딩, 한정 할로윈 펫(재까마귀 스펙),
--   할로윈 데미지스킨, 달가루상자(개수한정), 이렇게 다양하게 사탕으로 구매할수있게 하고 보스 잡아도 사탕좀 많이주고 … 다 할로윈 기간 한정으로"
--  여기는 셈만 한다: 오늘 켜져 있는가 · 상점의 물건(이름 · 살 수 있나) · 보스의 사탕 · 날아다니는 장식. 사탕을 떨어뜨리는 것은 sim/room.luau의 lootFor ·
--   사는 것은 server world.luau의 EventTrade · 상점 창은 client ui/shopWindow.luau(event:<이름표>) · 장식은 client eventFly.luau
--  시각: 세계 표준시의 초(os.time) — 이벤트마다 tz시간을 더해 그 나라의 날짜로 본다(공방의 eventOn과 같은 셈)
local root = script.Parent.Parent
local D = require(root.data["event.generated"])
local Items = require(script.Parent.items)

local Event = {}
Event.DATA = D
Event.clock = os.time -- (자동 검사가 바꾼다)

local BY = {}
for _, e in D.list do
	BY[e.id] = e
end
function Event.def(id: any)
	return if typeof(id) == "string" then BY[id] else nil
end

-- 그때(없으면 지금) 켜져 있는가
function Event.on(id: string, now: number?): boolean
	local e = BY[id]
	if not e then
		return false
	end
	local d = os.date("!*t", math.floor(now or Event.clock()) + e.tz * 3600)
	local md = d.month * 100 + d.day
	local a, b = e.from[1] * 100 + e.from[2], e.to[1] * 100 + e.to[2]
	return if a <= b then md >= a and md <= b else (md >= a or md <= b)
end

-- 지금 켜져 있는 이벤트들
function Event.active(now: number?): { any }
	local out = {}
	for _, e in D.list do
		if Event.on(e.id, now) then
			table.insert(out, e)
		end
	end
	return out
end

-- 그 주민(이벤트의 주민 — scenes의 npcs[].event)이 지금 서 있는가
function Event.npcOn(npc, now: number?): boolean
	return npc == nil or not npc.event or Event.on(npc.event, now)
end

-- 그 해(한정 수를 세는 열쇠 — 그 이벤트가 시작한 해: 1월에 끝나는 이벤트도 한 해로 센다)
local function season(e, now: number?): number
	local d = os.date("!*t", math.floor(now or Event.clock()) + e.tz * 3600)
	local md = d.month * 100 + d.day
	return if md < e.from[1] * 100 + e.from[2] then d.year - 1 else d.year
end
function Event.countKey(e, item, now: number?): string
	return ("%s:%d:%s"):format(e.id, season(e, now), item.id)
end

-- 기간의 글: 「10월 24일」 · 「11월 7일」
function Event.span(e): (string, string)
	local W = e.words
	local function day(md)
		return (string.gsub(string.gsub(W.date, "{m}", tostring(md[1])), "{d}", tostring(md[2])))
	end
	return day(e.from), day(e.to)
end

-- 상점의 물건 하나
function Event.item(e, id: any)
	for _, it in e.shop do
		if it.id == id then
			return it
		end
	end
	return nil
end

-- 달가루 랜덤 상자(2026-10-29 사용자: "엄청 조금줄수도 엄청 많이줄수도있는 랜덤박스로"): 바탕 = 산 계정의 가장 높은 레벨대의 달가루 상자(달빛 상점)의 달가루
function Event.dustBase(band: number): number
	local g = Items.goods("bm_dust_" .. band)
	return (g and g.amount) or 0
end
-- 굴린다: r = 0 이상 1 미만(서버의 math.random) → 받는 달가루 · 나온 칸(item.roll의 하나 — x배 · say · big)
function Event.dustRoll(item, band: number, r: number): (number, any)
	local sum = 0
	for _, q in item.roll do
		sum += q.w
	end
	local at = math.clamp(r, 0, 0.999999) * sum
	local pick = item.roll[#item.roll]
	for _, q in item.roll do
		at -= q.w
		if at < 0 then
			pick = q
			break
		end
	end
	return math.max(1, math.floor(Event.dustBase(band) * pick.x + 0.5)), pick
end

-- 그 물건의 이름(그 캐릭터 · 계정으로 — 물약은 그 레벨의 가장 좋은 것 · 달가루는 그 레벨대의 양)
function Event.what(e, item, level: number, band: number?): string
	local W = e.words
	local function fill(t: string, map)
		for k, v in map do
			t = string.gsub(t, "{" .. k .. "}", function()
				return tostring(v)
			end)
		end
		return t
	end
	local k = item.kind
	if k == "potion" then
		local p = Items.potionFor(level)
		return fill(W.potionWhat, { name = p and p.name or "?", n = item.n })
	elseif k == "goods" then
		local def = Items.goods(item.goods)
		return fill(W.goodsWhat, { name = def and def.name or item.goods, n = item.n or 1 })
	elseif k == "title" then
		local td = require(script.Parent.titles).def(item.title)
		return fill(W.titleWhat, { name = td and td.name or item.title })
	elseif k == "mount" or k == "pet" then
		local RIDE = require(root.data["ride.generated"])
		for _, q in if k == "mount" then RIDE.mounts else RIDE.pets do
			if q.id == item.ride then
				return fill(if k == "mount" then W.mountWhat else W.petWhat, { name = q.name })
			end
		end
		return item.ride
	elseif k == "dskin" then
		for _, q in e.dskins do
			if q.id == item.dskin then
				return fill(W.dskinWhat, { name = q.name })
			end
		end
		return item.dskin
	elseif k == "dust" then
		return W.dustWhat
	end
	return item.id
end

-- 그 물건의 그림(상점의 줄 · 가방의 그 그림)
function Event.icon(e, item, level: number): string
	local k = item.kind
	if k == "potion" then
		local p = Items.potionFor(level)
		return if p then p.icon else "potion_s"
	elseif k == "goods" then
		local def = Items.goods(item.goods)
		return if def then def.icon else ""
	elseif k == "mount" or k == "pet" then
		return "ride_" .. item.ride
	elseif k == "dskin" then
		for _, q in e.dskins do
			if q.id == item.dskin then
				return q.icon
			end
		end
	elseif k == "dust" then
		return "bm_dust"
	elseif k == "title" then
		return e.candy.id
	end
	return ""
end

-- 이미 가졌거나 한도를 다 썼나 → 「가졌다」(true) · 산 수 · 한도(없으면 nil)
--  h = 캐릭터 · c = 계정의 유료 상품 장부(acct.bm — 탈것 · 펫 · 스킨 · 한도) · now = 시각
function Event.owned(e, item, h, c, now: number?): (boolean, number, number?)
	local k = item.kind
	if k == "mount" then
		return c ~= nil and c.mounts[item.ride] == true, 0, nil
	elseif k == "pet" then
		return c ~= nil and c.pets[item.ride] == true, 0, nil
	elseif k == "dskin" then
		return c ~= nil and c.dskins[item.dskin] == true, 0, nil
	elseif k == "title" then
		return h ~= nil and h.titles ~= nil and h.titles[item.title] == true, 0, nil
	elseif item.limit then
		local n = (c and c.ev and c.ev[Event.countKey(e, item, now)]) or 0
		return n >= item.limit, n, item.limit
	end
	return false, 0, nil
end

-- 주간 보스전의 보상의 방에 더하는 사탕(켜져 있는 이벤트마다): { { id, n, pile } … }
function Event.bossGoods(mode: string, now: number?): { any }
	local out = {}
	for _, e in Event.active(now) do
		local n = e.boss and e.boss[mode]
		if typeof(n) == "number" and n > 0 then
			table.insert(out, { id = e.candy.id, n = n, pile = e.boss.pile or n })
		end
	end
	return out
end

-- 데미지 스킨의 정의(없으면 nil)
function Event.dskin(id: any)
	if typeof(id) ~= "string" then
		return nil
	end
	for _, e in D.list do
		for _, q in e.dskins or {} do
			if q.id == id then
				return q
			end
		end
	end
	return nil
end

return Event
