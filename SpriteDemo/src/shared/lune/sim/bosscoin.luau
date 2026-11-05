-- 보스 주화 장비(2026-11-05 — 공방 js/lune/design/bosscoin.js · 메이플의 앱솔랩스 · 아케인셰이드 코인처럼). 사용자: "메이플 스우, 데미안처럼 150제 장비를 만들수있는 코어를 드롭할거고 …
--  사냥하면 나오는 보조 코어랑 보스잡아서 나오는 코어랑 합쳐서 코인을 만들고 그걸로 150제 장비를 구할수 있는거야".
--  세트마다: 보스의 핵(core — 용암 거인을 격파한 사람마다 하나: 주간 보스의 보상 pay.goods) + 사냥의 핵(sub — 둘레 사냥터의 몬스터: sim/room.luau lootFor) → 주화(coin — 숯돌이 벼린다)
--   → 그 세트의 이름 붙은 장비(items.generated의 UNIQUES 가운데 set이 그 세트인 것 — cost = 주화 수 · 무기는 직업마다).
--  여기는 셈만 — 주민 곁인지(NPCDO coinshop)는 서버(world.luau의 Item "coinMake" · "coinBuy")가 본다.
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)

local D = Items.data
local DATA = D.BOSSCOIN or { sets = {}, words = {} }

local BossCoin = {}
BossCoin.DATA = DATA
BossCoin.WORDS = DATA.words

local BY = {}
for _, s in DATA.sets do
	BY[s.id] = s
end

function BossCoin.set(id: any)
	return if typeof(id) == "string" then BY[id] else nil
end

-- 그 세트의 장비들(UNIQUES의 차례 — 무기는 class의 것만 · class가 없으면 모두)
function BossCoin.gear(set, class: string?)
	local out = {}
	for _, u in D.UNIQUES or {} do
		if u.set == set.id and (u.who == nil or class == nil or u.who == class) then
			table.insert(out, u)
		end
	end
	return out
end

-- 그 맵(설계의 이름 — 방 번호를 뗀 것)의 몬스터가 떨어뜨리는 사냥의 핵들 { { id, pct } … }
function BossCoin.subsAt(base: any): { any }
	local out = {}
	if typeof(base) ~= "string" then
		return out
	end
	for _, s in DATA.sets do
		if table.find(s.sub.maps, base) then
			table.insert(out, { id = s.sub.id, pct = s.sub.pct })
		end
	end
	return out
end

-- 주화를 n개 벼릴 수 있나 → nil(된다) · 까닭
function BossCoin.canMake(h, set, n: number): string?
	local W = BossCoin.WORDS
	if typeof(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > 999 then
		return "수가 맞지 않는다"
	end
	for _, need in { { set.core, set.coin.core }, { set.sub.id, set.coin.sub } } do
		if Bag.count(h, need[1]) < need[2] * n then
			local g = Items.goods(need[1])
			return (string.gsub(W.short or "{name}", "{name}", if g then g.name else need[1]))
		end
	end
	if Bag.room(h, set.coin.id) < n then
		return W.full
	end
	return nil
end
-- 가진 것으로 벼릴 수 있는 가장 많은 수
function BossCoin.maxMake(h, set): number
	local a = Bag.count(h, set.core) // math.max(1, set.coin.core)
	local b = Bag.count(h, set.sub.id) // math.max(1, set.coin.sub)
	return math.max(0, math.min(a, b, Bag.room(h, set.coin.id)))
end
-- 주화를 n개 벼린다(핵을 덜고 주화를 넣는다) → true · 또는 nil과 까닭
function BossCoin.make(h, setId: any, n: any): (boolean?, string?)
	local set = BossCoin.set(setId)
	if not set then
		return nil, "모르는 세트다"
	end
	n = if typeof(n) == "number" then n else 1
	local why = BossCoin.canMake(h, set, n)
	if why then
		return nil, why
	end
	Bag.take(h, set.core, set.coin.core * n)
	Bag.take(h, set.sub.id, set.coin.sub * n)
	Bag.give(h, set.coin.id, n)
	return true
end

-- 주화로 장비를 바꿀 수 있나 → nil(된다) · 까닭
function BossCoin.canBuy(h, set, u): string?
	local W = BossCoin.WORDS
	if not u or u.set ~= set.id then
		return "모르는 장비다"
	elseif u.who ~= nil and u.who ~= h.class then
		return "내 직업의 장비가 아니다"
	elseif Bag.count(h, set.coin.id) < u.cost then
		local g = Items.goods(set.coin.id)
		return (string.gsub(W.short or "{name}", "{name}", if g then g.name else set.coin.id))
	elseif Bag.free(h) <= 0 then
		return W.full
	end
	return nil
end
-- 주화를 내고 장비를 받는다 → 받은 장비 · 또는 nil과 까닭. rng = 성능을 굴리는 난수(2026-11-05 사용자 "교환할때 샤냥터 드롭 장비처럼 랜덤값으로" — Items.rollQuality: 낡은 10 · 허름한 20 · 보통 40 · 좋은 22 · 빼어난 8%)
function BossCoin.buy(h, setId: any, uid: any, rng)
	local set = BossCoin.set(setId)
	if not set then
		return nil, "모르는 세트다"
	end
	local u = Items.unique(uid)
	local why = BossCoin.canBuy(h, set, u)
	if why then
		return nil, why
	end
	Bag.take(h, set.coin.id, u.cost)
	local it = Items.makeUnique(uid, if u.roll and rng then Items.rollQuality(rng) else nil)
	Bag.add(h, it)
	return it
end

return BossCoin
