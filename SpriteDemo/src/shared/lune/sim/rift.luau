-- 수정 틈 토벌 — 은달 항구의 반복 던전(공방 js/lune/design/city.js의 RIFT · 2026-10-16).
--  사용자 2026-10-15: 레이드 · 카오스 던전 · 반복 사냥 · 보스 난이도 같은 반복 컨텐츠는 배를 타고 대도시(은달 항구)에 간 뒤의 구간에 둔다.
--  참고: 로스트아크 카오스 던전(하루 두 번 보상 · 몰려오는 몬스터 · 끝에 정예) · 메이플스토리 몬스터파크(레벨대마다 다른 던전 · 하루 횟수 · 끝내면 큰 경험치).
--  하는 일: 광장의 토벌대장에게 「입장」 → rf1#번호처럼 따로 된 방(바탕 사냥터의 그림 · 땅) → 물결 셋 + 정예의 물결 → 다 쓰러뜨리면 완료(하루 두 번까지 보상) → 30초 뒤 광장으로.
--  제한 시간을 넘기면 실패(보상 없음 · 횟수도 쓰지 않는다). 숫자 · 이름은 모두 제 제안이다.
--  캐릭터마다의 기록 h.rift = { day = 보상을 받은 날 · used = 그날 받은 수 · clears = 모두 끝낸 수 }.
--  방의 셈(Rift.start · Rift.step)은 sim/room.luau가 부른다 — 방의 몬스터 가운데 물결(wave)이 있는 것만 움직인다.
local lune = script.Parent.Parent
local D = require(lune.data["city.generated"]).rift
local ITEMS = require(lune.data["items.generated"])
local Daily = require(script.Parent.daily)
local Items = require(script.Parent.items)

local Rift = {}
Rift.DATA = D
Rift.START = 2 -- 들어가서 첫 물결이 나오기까지(초)
Rift.STAGGER = 0.2 -- 한 물결의 몬스터가 하나씩 나타나는 간격(초)
Rift.FAIL_BACK = 5 -- 실패하면 몇 초 뒤 광장으로

local tierById = {}
for i, t in D.tiers do
	tierById[t.id] = t
	t.index = i
end
function Rift.tier(id: any)
	return if typeof(id) == "string" then tierById[id] else nil
end
-- 그 장면 이름(rf1#3)이 토벌의 방이면 그 단계, 아니면 nil
function Rift.tierOfKey(key: any)
	if typeof(key) ~= "string" then
		return nil
	end
	local base = string.match(key, "^(rf%d+)#%d+$")
	return if base then tierById[base] else nil
end

-- ---------- 캐릭터마다의 기록 ----------
function Rift.new()
	return { day = 0, used = 0, clears = 0 }
end
-- 오늘 남은 보상 횟수
function Rift.left(r, now: number): number
	if r.day ~= Daily.dayOf(now) then
		return D.perDay
	end
	return math.max(0, D.perDay - r.used)
end
-- 보상 한 번을 쓴다(남았으면 true)
function Rift.use(r, now: number): boolean
	local day = Daily.dayOf(now)
	if r.day ~= day then
		r.day, r.used = day, 0
	end
	if r.used >= D.perDay then
		return false
	end
	r.used += 1
	return true
end
function Rift.pack(r)
	return { day = r.day, used = r.used, clears = r.clears }
end
function Rift.unpack(data: any)
	local r = Rift.new()
	if typeof(data) == "table" then
		r.day = math.floor(tonumber(data.day) or 0)
		r.used = math.clamp(math.floor(tonumber(data.used) or 0), 0, D.perDay)
		r.clears = math.max(0, math.floor(tonumber(data.clears) or 0))
	end
	return r
end

-- 들어갈 수 있는가(레벨). 맞으면 nil, 아니면 까닭
function Rift.canEnter(h, t): string?
	if not h.alive then
		return "쓰러진 채로는 들어갈 수 없다"
	elseif h.level < t.lv then
		return string.gsub(D.words.need, "{lv}", tostring(t.lv)) .. " 들어갈 수 있다"
	end
	return nil
end

-- 완료 보상의 장비(그 단계의 확률로 — 무기는 내 직업의 것, 방어구는 부위 가운데 하나). 없으면 nil
function Rift.rollGear(t, rng, who: string)
	if rng:NextNumber() >= t.pay.gear then
		return nil
	end
	local slots = { "weapon" }
	for _, id in ITEMS.ARMOR do
		table.insert(slots, id)
	end
	local slot = slots[rng:NextInteger(1, #slots)]
	return Items.make(slot, Items.stageOf(t.mobLv), Items.rollQuality(rng), if slot == "weapon" then who else nil)
end

-- ---------- 방의 셈 ----------
--  room.rift = { tier, state("wait" 들어가 기다림 · "run" 싸우는 중 · "clear" 완료 · "fail" 실패), wave(지금 물결), waves(물결 수), t(싸운 시간), after(끝난 뒤 지난 시간), left(지금 물결의 남은 몬스터) }
function Rift.start(room, t)
	local waves = 0
	for _, mob in room.mobs do
		if mob.wave then
			waves = math.max(waves, mob.wave)
			mob.away, mob.state, mob.respawn = true, "gone", math.huge -- 물결이 올 때까지 없다
		end
	end
	room.rift = { tier = t.id, state = "wait", wave = 0, waves = waves, t = 0, after = 0, left = 0, changed = true }
end

local function startWave(room, w: number)
	local R = room.rift
	R.wave = w
	local n = 0
	for _, mob in room.mobs do
		if mob.wave == w then
			n += 1
			mob.away = false
			mob.state, mob.t, mob.respawn, mob.x, mob.hp, mob.target = "gone", 0, Rift.STAGGER * n, mob.homeX, mob.maxHp, nil
			mob.bind, mob.bindImm, mob.stun, mob.rend, mob.cracks, mob.marks = 0, 0, 0, 0, 0, nil
		end
	end
	R.left = n
	R.changed = true
end

-- 지금 물결에서 아직 남은 몬스터(나타나기 전 · 살아 있는 것)
local function leftOf(room): number
	local n = 0
	for _, mob in room.mobs do
		if mob.wave == room.rift.wave and not mob.away then
			n += 1
		end
	end
	return n
end

local function clearAll(room)
	for _, mob in room.mobs do
		if mob.wave and not mob.away then
			mob.away, mob.state, mob.target = true, "gone", nil
		end
	end
end

-- 한 걸음: 상태가 바뀌었으면 R.changed = true(서버가 방에 알린다)
function Rift.step(room, heroes, dt: number)
	local R = room.rift
	if not R or next(heroes) == nil then
		return
	end
	if R.state == "wait" then
		R.after += dt
		if R.after >= Rift.START then
			R.state, R.after = "run", 0
			startWave(room, 1)
		end
	elseif R.state == "run" then
		R.t += dt
		local n = leftOf(room)
		if n ~= R.left then
			R.left = n
			R.changed = true
		end
		if n == 0 then
			if R.wave < R.waves then
				startWave(room, R.wave + 1)
			else
				R.state, R.after = "clear", 0
				R.changed = true
			end
		elseif R.t >= D.time then
			R.state, R.after = "fail", 0
			clearAll(room)
			R.changed = true
		end
	else
		R.after += dt
	end
end

-- 화면에 보내는 것
function Rift.view(room)
	local R = room.rift
	if not R then
		return nil
	end
	return { tier = R.tier, state = R.state, wave = R.wave, waves = R.waves, left = R.left, t = math.floor(R.t * 10) / 10, time = D.time, after = math.floor(R.after * 10) / 10 }
end

-- 광장으로 돌려보낼 때가 되었는가(완료 back초 · 실패 FAIL_BACK초 뒤)
function Rift.due(room): boolean
	local R = room.rift
	return R ~= nil and ((R.state == "clear" and R.after >= D.back) or (R.state == "fail" and R.after >= Rift.FAIL_BACK))
end

return Rift
