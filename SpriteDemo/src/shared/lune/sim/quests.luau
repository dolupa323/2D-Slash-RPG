-- 퀘스트의 셈 — 받기 · 잡은 것 세기 · 다 됐는지 · 돌려주기. 화면도 서버도 모르는 순수한 셈이다.
--  자료는 data/quests.generated.luau(공방 js/lune/design/questplay.js에서 내보낸 것): 누구에게서 받고 · 무엇을 몇 개 · 누구에게 돌려주고 · 무엇을 받나.
--  사람마다의 상태(book) = { [퀘스트 id] = { done = 끝냈는가, c = { [할 일 차례] = 지금까지의 수 } } } — 받지 않은 퀘스트는 들어 있지 않다.
--  서버는 캐릭터의 표에(h.quests), 클라이언트는 서버가 보내 준 것을 그대로 갖고 같은 함수로 주민 머리 위의 표시와 알리미를 셈한다.
local D = require(script.Parent.Parent.data["quests.generated"])

local Q = {}
Q.list = D.list
Q.MAX_ACTIVE = 10 -- 한 번에 받아 둘 수 있는 수

local byId = {}
for i, def in D.list do
	byId[def.id] = def
	def.order = i
end

function Q.def(id: any)
	return if typeof(id) == "string" then byId[id] else nil
end

-- 할 일 하나를 화면에 적는 꼴: 「수습 검병 3/5」 · 들르는 일은 「달맞이 광장 들르기」 · 다 했으면 「… ✓」
function Q.stepText(step, have: number): string
	if step.type == "visit" then
		return ("%s 들르기%s"):format(step.name, if have >= step.n then " ✓" else "")
	elseif step.type == "meet" then
		return ("%s 만나기%s"):format(step.name, if have >= step.n then " ✓" else "") -- 처음 인사(2026-10-16 — 만나면 그 사람의 기능이 열린다)
	end
	return ("%s %d/%d"):format(step.name, math.min(have, step.n), step.n)
end

-- 받침이 있으면 a, 없으면 b(을 · 를 / 이 · 가)를 고른다 — 한글로 끝나지 않으면 a
local function josa(word: string, a: string, b: string): string
	local last = nil
	for _, code in utf8.codes(word) do
		last = code
	end
	if last and last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 == 0 then
		return b
	end
	return a
end
Q.josa = josa

-- 그 일을 어디서 무엇을 잡아 하는가: 「달그림자 사냥터의 검병을 잡으면 떨어진다」 · 「마을 어귀에 있다」
--  사용자 2026-10-07: "뭘잡아야 갑옷조각이 나오는지를 자연스럽게 적어둬야 퀘스트를 진행할거아닙니까 이렇게 적으면 누가 어떻게 알아요"
function Q.stepHint(def, step): string
	local SCENES = require(script.Parent.Parent.data["scenes.generated"])
	local COMBAT = require(script.Parent.Parent.data["combat.generated"])
	local scene = def.scene and SCENES.scenes[def.scene]
	local place = if scene then scene.name else "이 근처"
	local mob = COMBAT.mobs[step.mob]
	local name = if mob then mob.name else step.name
	if step.type == "gather" then
		return ("%s의 %s%s 잡으면 떨어진다"):format(place, name, josa(name, "을", "를"))
	elseif step.type == "use" then
		return ("%s — %s 앞에서 ↑"):format(place, step.place) -- 맵에 놓인 것 앞에서 ↑를 누르는 일
	elseif step.type == "visit" then
		return ("%s에 가 본다"):format(step.name) -- 그 맵에 들어가면 된다(2026-10-16)
	elseif step.type == "meet" then
		local at = Q.npcScene(def, step.npc)
		local sc = at and SCENES.scenes[at]
		return ("%s — %s에게 말을 건다"):format(if sc then sc.name else place, step.name)
	end
	return ("%s에 있다"):format(place)
end

-- 아직 다 하지 못한 일들의 길잡이(퀘스트 창에 적는다)
function Q.hints(book, id: string): { string }
	local def, st = byId[id], book[id]
	local out = {}
	if def and st then
		for i, step in def.steps do
			if (st.c[i] or 0) < step.n then
				table.insert(out, Q.stepHint(def, step))
			end
		end
	end
	return out
end

-- 알리미에 적는 한 줄: 모으는 일은 떨어뜨리는 졸개의 이름을 앞에 — 「검병 · 갑옷 조각 0/8」
function Q.trackText(step, have: number): string
	if step.type == "gather" then
		local COMBAT = require(script.Parent.Parent.data["combat.generated"])
		local mob = COMBAT.mobs[step.mob]
		if mob then
			return ("%s · %s"):format(mob.name, Q.stepText(step, have))
		end
	end
	return Q.stepText(step, have)
end

-- 받아 둔 퀘스트의 할 일이 다 됐는가
function Q.isReady(book, id: string): boolean
	local def, st = byId[id], book[id]
	if not def or not st or st.done then
		return false
	end
	for i, step in def.steps do
		if (st.c[i] or 0) < step.n then
			return false
		end
	end
	return true
end

-- 퀘스트의 지금 모습: "done" 끝냄 · "ready" 돌려주면 된다 · "active" 하는 중 · "open" 받을 수 있다 · "locked" 아직 못 받는다
function Q.state(book, level: number, id: string): string
	local def, st = byId[id], book[id]
	if not def then
		return "locked"
	elseif st then
		return if st.done then "done" elseif Q.isReady(book, id) then "ready" else "active"
	elseif not def.playable or level < def.lv then
		return "locked"
	elseif def.after and not (book[def.after] and book[def.after].done) then
		return "locked"
	end
	return "open"
end

local function activeCount(book): number
	local n = 0
	for _, st in book do
		if not st.done then
			n += 1
		end
	end
	return n
end

-- 그 지역의 퀘스트 줄에서 아직 끝내지 않은 퀘스트가 잡게 하는 몬스터 { [몬스터] = true } — 일일 의뢰가 피한다(sim/daily.luau — 2026-10-15
--  사용자: "메인퀘스트에서 궁병잡는거 중간에 일일퀘스트도 자연스럽게하면 너무 반복됩니다")
function Q.lineMobs(book, region: string): { [string]: boolean }
	local out = {}
	for _, def in D.list do
		if def.line and def.region == region and def.playable and not (book[def.id] and book[def.id].done) then
			for _, step in def.steps do
				if step.mob then
					out[step.mob] = true
				end
			end
		end
	end
	return out
end

-- 받는다
function Q.accept(book, level: number, id: any): (boolean?, string?)
	local def = Q.def(id)
	if not def then
		return nil, "없는 퀘스트다"
	end
	local state = Q.state(book, level, id)
	if state == "locked" then
		return nil, if level < def.lv then ("Lv.%d부터 받는다"):format(def.lv) else "아직 받을 수 없다"
	elseif state ~= "open" then
		return nil, "이미 받은 퀘스트다"
	elseif activeCount(book) >= Q.MAX_ACTIVE then
		return nil, "퀘스트를 더 받을 수 없다"
	end
	book[id] = { done = false, c = {} }
	return true
end

-- 저절로 받는 퀘스트(자료의 auto) — 지금은 하나도 없다: 모든 퀘스트는 주는 주민에게 말을 걸어 받는다
--  (사용자 2026-10-11: "퀘스트를 부여해주는 npc 랑 말을하고 퀘스트를 수락해야 퀘스트가 수락되고 … 정석적으로". 전에는 새 캐릭터의 「첫 기술」과 전직 퀘스트를 여기서 저절로 받았다.)
--  공방의 검사가 auto를 막는다. 이 함수는 빈 표를 돌려준다(부르는 곳들은 그대로 둔다)
function Q.start(book, level: number): { string }
	local got = {}
	for _, def in D.list do
		if def.auto and Q.state(book, level, def.id) == "open" then
			if Q.accept(book, level, def.id) then
				table.insert(got, def.id)
			end
		end
	end
	return got
end

-- 새 캐릭터가 서는 곳: 첫 퀘스트(「첫 기술」)를 끝내기 전에는 그것을 주는 사제의 사당 안(공방 questplay.js의 FIRST) — 끝낸 뒤에는 nil(마을의 시작 자리).
--  Lv.1일 때만이다: 첫 퀘스트를 건너뛰고 자란 예전 캐릭터(이 규칙이 생기기 전 — 2026-10-10)는 하던 대로 마을에서 시작하고 기술도 그대로 쓴다.
--  받기 전(사제에게 아직 말을 걸지 않았다)이든 받은 뒤든, 끝내기 전이면 새 캐릭터다
Q.FIRST = D.first
function Q.isNew(book, level: number): boolean
	local st = book[D.first.quest]
	return level <= 1 and not (st ~= nil and st.done)
end
function Q.firstScene(book, level: number): string?
	return if Q.isNew(book, level) then D.first.scene else nil
end

-- 그 차수로 올려 주는 전직 퀘스트(없으면 nil — 그 차수는 레벨만 되면 오른다)
function Q.jobQuest(job: number)
	for _, def in D.list do
		if def.kind == "job" and def.playable and def.reward.job == job then
			return def
		end
	end
	return nil
end

-- 이미 닿은 차수의 전직 퀘스트는 끝낸 것으로 적는다(전직 퀘스트가 생기기 전의 캐릭터 · 확인용 캐릭터가 다시 받지 않게)
function Q.jobsDone(book, job: number)
	for _, def in D.list do
		if def.kind == "job" and def.reward.job and def.reward.job <= job then
			book[def.id] = { done = true, c = {} }
		end
	end
end

-- 졸개를 잡았다. 바뀐 퀘스트들의 id를 돌려준다(없으면 빈 표). 잡는 일만 센다 — 모으는 물건은 땅에 떨어지고(Q.drops) 주우면 가방에 들어가며, 가방에 든 수가 곧 숫자다(Q.sync)
--  **어느 맵에서 잡든 그 몬스터면 센다**(사용자 2026-10-13: "똑같은 몬스터인데 … 달그림자 사냥터  검병한테는 드랍이 안되고 사냥터 깊은곳 검병한테는 드랍이되고  이런식이면 안됩니다.
--   하드코딩 박는식으로 개발을하면안되요" — 전에는 그 퀘스트의 맵에서 잡은 것만 세고 떨어뜨렸다). 이야기의 자리에서만 세는 일(only — 사당 지하를 지키는 「불타는 마을」)만 그 맵을 본다.
local function counts(def, step, scene: string): boolean
	return not step.only or def.scene == scene
end
function Q.onKill(book, mobKind: string, scene: string): { string }
	local changed = {}
	for id, st in book do
		local def = byId[id]
		if def and not st.done then
			for i, step in def.steps do
				local have = st.c[i] or 0
				if step.type == "kill" and step.mob == mobKind and have < step.n and counts(def, step, scene) then
					st.c[i] = have + 1
					table.insert(changed, id)
				end
			end
		end
	end
	return changed
end

-- 그 맵에 들어갔다: 하는 중인 퀘스트의 「들르기」가 된다(2026-10-16 — 「항구의 첫날」처럼 도시를 둘러보는 퀘스트). 바뀐 퀘스트들
function Q.onVisit(book, scene: string): { string }
	local changed = {}
	for id, st in book do
		local def = byId[id]
		if def and not st.done then
			for i, step in def.steps do
				if step.type == "visit" and step.at == scene and (st.c[i] or 0) < step.n then
					st.c[i] = step.n
					table.insert(changed, id)
				end
			end
		end
	end
	return changed
end

-- 그 사람과 처음 인사를 나눴다: 하는 중인 퀘스트의 「만나기」가 된다(2026-10-16 — 「항구의 첫날」). 바뀐 퀘스트들
function Q.onMeet(book, npc: string): { string }
	local changed = {}
	for id, st in book do
		local def = byId[id]
		if def and not st.done then
			for i, step in def.steps do
				if step.type == "meet" and step.npc == npc and (st.c[i] or 0) < step.n then
					st.c[i] = step.n
					table.insert(changed, id)
				end
			end
		end
	end
	return changed
end

-- 그 장면의 그 몬스터를 아직 잡아야 하는가(하는 중인 퀘스트의 못 다 한 잡기). 스토리 보스는 이것이 참인 사람이 방에 있을 때만 서 있다(sim/room.luau)
-- 그 퀘스트에 닿았는가: 받았거나(하는 중) 끝냈다 — 그 퀘스트를 받아야 열리는 문(장면의 portals의 need — 사당 지하)이 쓴다
--  id가 표면 그 가운데 하나라도(사당 지하 = 「불타는 마을」 또는 2차 전직)
function Q.reached(book, id: any): boolean
	if book == nil then
		return false
	elseif typeof(id) == "table" then
		for _, one in id do
			if Q.reached(book, one) then
				return true
			end
		end
		return false
	end
	return typeof(id) == "string" and book[id] ~= nil
end

-- 그 퀘스트를 끝냈는가 — 끝내야 열리는 문(장면의 portals의 done — 초승달 마을의 작은 나루: 「불타는 마을」을 끝내야 은달 항구로 가는 배가 뜬다)
function Q.finished(book, id: any): boolean
	if book == nil then
		return false
	elseif typeof(id) == "table" then
		for _, one in id do
			if not Q.finished(book, one) then
				return false
			end
		end
		return true
	end
	return typeof(id) == "string" and book[id] ~= nil and book[id].done == true
end

-- 줄에서 그 퀘스트 앞의 것들을 모두 끝낸 것으로 적는다(자동 검사 · 시험용 — 그 퀘스트는 건드리지 않는다). 퀘스트는 한 줄이라 앞의 것을 끝내야 받는다
function Q.finishBefore(book, id: any)
	local def = byId[id]
	while def and def.after do
		local st = book[def.after]
		if st then
			st.done = true
		else
			book[def.after] = { done = true, c = {} }
		end
		def = byId[def.after]
	end
end

-- 그 퀘스트를 끝내면 열리는 문들: { { scene(장면의 이름표), place(맵의 이름), label(문의 글) } … } — 끝낸 순간 화면이 「새 길이 열렸다」고 알린다(client/lune/boot.luau)
function Q.opens(id: any)
	local SCENES = require(script.Parent.Parent.data["scenes.generated"])
	local out = {}
	for key, sc in SCENES.scenes do
		for _, p in sc.portals or {} do
			local hit = p.done == id
			if typeof(p.done) == "table" then
				hit = table.find(p.done, id) ~= nil
			end
			if hit then
				table.insert(out, { scene = key, place = sc.name, label = p.label })
			end
		end
	end
	-- 탈것(2026-10-16 — 문 대신 사람): 그 퀘스트를 끝내야 태우는 탈것(마을 → 은달 항구의 배 — sim/voyage.luau의 open과 같은 자물쇠)
	local V = require(script.Parent.Parent.data["city.generated"]).voyage
	for _, r in V.routes do
		local from = SCENES.scenes[r.from]
		if r.need == id and from then
			local who = nil
			for _, n in from.npcs or {} do
				if n.id == r.npc then
					who = n.role
				end
			end
			table.insert(out, { scene = r.from, place = from.name, label = ("%s — %s로 가는 %s"):format(who or "배", r.dest, if r.kind == "airship" then "비행선" else "배") })
		end
	end
	table.sort(out, function(a, b)
		return a.scene < b.scene
	end)
	return out
end
Q.OPENED = { head = "새 길이 열렸다", line = "%s의 「%s」" } -- 그때의 큰 알림(제목 · 줄 — 맵의 이름 · 문의 글)

-- 그 문이 열렸는가: need = 그 퀘스트를 받은 뒤 · done = 그 퀘스트를 끝낸 뒤(서버 · 화면 · 길찾기 · 월드맵이 모두 이것으로 본다)
function Q.portalOpen(book, portal): boolean
	return (portal.need == nil or Q.reached(book, portal.need)) and (portal.done == nil or Q.finished(book, portal.done))
end

-- 그 장면의 그 졸개가 필요한가: 하는 중인 퀘스트에 그 졸개를 잡는 일 · 그 졸개에게서 모으는 일이 남아 있다 — 이야기의 방(사당 지하)의 졸개가 이것으로 나온다
function Q.wantsMob(book, mobKind: string, scene: string): boolean
	if not book then
		return false
	end
	for id, st in book do
		local def = byId[id]
		if def and not st.done and def.scene == scene then
			for i, step in def.steps do
				if (step.type == "kill" or step.type == "gather") and step.mob == mobKind and (st.c[i] or 0) < step.n then
					return true
				end
			end
		end
	end
	return false
end

function Q.wantsKill(book, mobKind: string, scene: string): boolean
	if not book then
		return false
	end
	for id, st in book do
		local def = byId[id]
		if def and not st.done and def.scene == scene then
			for i, step in def.steps do
				if step.type == "kill" and step.mob == mobKind and (st.c[i] or 0) < step.n then
					return true
				end
			end
		end
	end
	return false
end

-- ---------- 맵에 놓인 것 앞에서 ↑를 누르는 일(type "use") ----------
Q.USE_REACH = { x = 30, y = 24 } -- 그 자리에서 이만큼 안에 서야 한다(게임의 도트 — 주민에게 말을 걸 때와 같은 폭)

-- 그 장면에서 지금 ↑를 누를 수 있는 자리들: 하는 중인 퀘스트의 아직 못 한 일. { { quest, step, x, y, up(「!」의 높이), place, act } … }(자료의 차례)
function Q.spotsIn(book, scene: string)
	local out = {}
	for _, def in D.list do
		local st = book[def.id]
		if st and not st.done and def.scene == scene then
			for i, step in def.steps do
				if step.type == "use" and (st.c[i] or 0) < step.n then
					table.insert(out, { quest = def.id, step = i, x = step.x, y = step.y, up = step.up, place = step.place, act = step.act })
				end
			end
		end
	end
	return out
end

-- 그 자리 앞에서 ↑를 눌렀다: 그 퀘스트의 아직 못 한 일 가운데 가까이에 있는 것의 숫자가 하나 오른다. 됐으면 true(아니면 nil과 까닭)
function Q.use(book, id: any, scene: string, x: number, y: number): (boolean?, string?)
	local def = Q.def(id)
	local st = def and book[id]
	if not def or not st or st.done then
		return nil, "하는 중인 퀘스트가 아니다"
	elseif def.scene ~= scene then
		return nil, "여기가 아니다"
	end
	for i, step in def.steps do
		if step.type == "use" and (st.c[i] or 0) < step.n then
			if math.abs(step.x - x) <= Q.USE_REACH.x and math.abs(step.y - y) <= Q.USE_REACH.y then
				st.c[i] = (st.c[i] or 0) + 1
				return true
			end
			return nil, "그 자리 앞이 아니다"
		end
	end
	return nil, "여기서 할 일이 없다"
end

-- 졸개를 잡았을 때 떨어지는 퀘스트의 물건들: 아직 모으는 중인 물건마다 그 확률(pct)로 하나. { { quest, step, name, icon } … }
--  사용자 2026-10-07: "퀘스트 아이템이나 , 기타아이템들은 왜 드롭도되지않고 그림도없고 그냥 텍스트로만 오르나요?" — 잡으면 숫자만 오르던 것을, 그림이 있는 물건이 땅에 떨어지고 주워야 오르게 고쳤다
function Q.drops(book, mobKind: string, scene: string, rng)
	local out = {}
	for id, st in book do
		local def = byId[id]
		if def and not st.done then
			for i, step in def.steps do
				if step.type == "gather" and step.mob == mobKind and counts(def, step, scene) and (st.c[i] or 0) < step.n and rng:NextNumber(0, 100) < step.pct then
					table.insert(out, { quest = id, step = i, name = step.name, icon = step.icon, goods = step.item })
				end
			end
		end
	end
	return out
end

-- 모으는 일의 숫자를 가방에 맞춘다 — 모으는 물건은 가방의 기타 탭에 놓이는 진짜 아이템이고, 가방에 든 수가 곧 퀘스트의 숫자다
--  (사용자 2026-10-08: "품목이 고정되어있고 거기서 수량 1/8 이런식으로 표기하는게 인벤토리가 아닙니다" — 숫자를 따로 세던 것을 고쳤다. 버리면 숫자도 준다).
--  count(이름표) → 가방에 든 수. 바뀐 것이 있으면 true(부른 쪽이 화면에 알린다)
function Q.sync(book, count: (string) -> number): boolean
	local changed = false
	for id, st in book do
		local def = byId[id]
		if def and not st.done then
			for i, step in def.steps do
				if step.type == "gather" and step.item then
					local have = math.min(step.n, count(step.item))
					if (st.c[i] or 0) ~= have then
						st.c[i] = have
						changed = true
					end
				end
			end
		end
	end
	return changed
end

-- 그 퀘스트가 모으게 하는 물건들 { { item = 이름표, n = 모을 수 } … }(돌려줄 때 가방에서 빠진다)
function Q.takes(id: any)
	local out = {}
	local def = byId[id]
	for _, step in if def then def.steps else {} do
		if step.type == "gather" and step.item then
			table.insert(out, { item = step.item, n = step.n })
		end
	end
	return out
end

-- 하는 중인 퀘스트 가운데 그 물건을 모으는 것이 있는가(except = 빼고 볼 퀘스트)
function Q.wants(book, item: string, except: string?): boolean
	for id, st in book do
		local def = byId[id]
		if def and not st.done and id ~= except then
			for _, step in def.steps do
				if step.type == "gather" and step.item == item then
					return true
				end
			end
		end
	end
	return false
end

-- 돌려준다. 끝낸 것으로 적고 보상을 돌려준다(보상을 실제로 주는 것은 부른 쪽 — sim/hero.luau의 questDone)
function Q.complete(book, id: any)
	local def = Q.def(id)
	if not def or not book[id] then
		return nil, "받지 않은 퀘스트다"
	elseif book[id].done then
		return nil, "이미 끝낸 퀘스트다"
	elseif not Q.isReady(book, id) then
		return nil, "아직 다 하지 못했다"
	end
	book[id].done = true
	return def.reward
end

-- 그만둔다(메인은 그만둘 수 없다). 다시 받으면 처음부터다
function Q.drop(book, id: any): (boolean?, string?)
	local def = Q.def(id)
	if not def or not book[id] or book[id].done then
		return nil, "하는 중인 퀘스트가 아니다"
	elseif def.kind ~= "side" then
		return nil, if def.kind == "job" then "전직 퀘스트는 그만둘 수 없다" else "메인 퀘스트는 그만둘 수 없다"
	end
	book[id] = nil
	return true
end

-- 그 주민에게서 할 수 있는 것: ready = 돌려줄 것 · offer = 받을 것 · wait = 받아서 하는 중인 것(이 주민에게 돌려줄 것)
--  region = 그 주민이 서 있는 맵의 지역(장면 자료의 region). 여러 맵에 서는 주민(샛별 · 반달 · 하늬 …)은 제가 선 지역의 퀘스트만 준다 — 돌려받는 것은 어디서든 한다. 주지 않으면(nil) 가리지 않는다
function Q.atNpc(book, level: number, npc: string, region: any?)
	local out = { ready = {}, offer = {}, wait = {} }
	for _, def in D.list do
		local state = Q.state(book, level, def.id)
		if def.endNpc == npc and state == "ready" then
			table.insert(out.ready, def.id)
		elseif def.giver == npc and state == "open" and not def.auto and (region == nil or def.region == region or def.kind == "job") then -- 전직 퀘스트는 사제가 어디서든 준다
			table.insert(out.offer, def.id)
		elseif def.endNpc == npc and state == "active" then
			table.insert(out.wait, def.id)
		end
	end
	return out
end

-- 주민 머리 위의 표시: "?" 돌려줄 것이 있다 · "!" 줄 것이 있다 · nil
function Q.mark(book, level: number, npc: string, region: any?): string?
	local at = Q.atNpc(book, level, npc, region)
	return if #at.ready > 0 then "?" elseif #at.offer > 0 then "!" else nil
end

-- ---------- 길잡이(알리미가 적는다 — 메이플스토리의 전구 구실) ----------
-- 다음에 할 메인: 아직 받지 않은 첫 메인. 돌려주는 것: 퀘스트, "open"(지금 받을 수 있다) · "level"(레벨이 모자란다). 앞의 메인을 하는 중이면 nil
function Q.nextMain(book, level: number)
	for _, def in D.list do
		if def.kind == "main" and def.playable and not book[def.id] then
			if Q.state(book, level, def.id) == "open" then
				return def, "open"
			elseif level < def.lv and (not def.after or (book[def.after] ~= nil and book[def.after].done)) then
				return def, "level"
			end
			return nil
		end
	end
	return nil
end

-- 지금 받을 수 있는 전직 퀘스트들(레벨이 됐다 — 그믐 사제에게 가서 받는다)
function Q.openJobs(book, level: number)
	local out = {}
	for _, def in D.list do
		if def.kind == "job" and def.playable and not def.auto and Q.state(book, level, def.id) == "open" then
			table.insert(out, def)
		end
	end
	return out
end

-- 지금 받을 수 있는 주민의 부탁들(자료의 차례)
function Q.openSides(book, level: number)
	local out = {}
	for _, def in D.list do
		if def.kind == "side" and not def.auto and Q.state(book, level, def.id) == "open" then
			table.insert(out, def)
		end
	end
	return out
end

-- 퀘스트 창의 「시작 가능」(메이플스토리의 퀘스트 창처럼): 지금 받을 수 있는 것(메인 먼저 · 그다음 부탁 — 자료의 차례), 맨 끝에 레벨이 모자란 다음 메인 하나(그 줄은 Q.state가 "locked"다)
function Q.listOpen(book, level: number): { string }
	local out = {}
	for _, def in Q.openJobs(book, level) do
		table.insert(out, def.id) -- 전직 퀘스트가 맨 위
	end
	for _, def in D.list do
		if def.kind == "main" and not def.auto and Q.state(book, level, def.id) == "open" then
			table.insert(out, def.id)
		end
	end
	for _, def in Q.openSides(book, level) do
		table.insert(out, def.id)
	end
	local main, why = Q.nextMain(book, level)
	if main and why == "level" then
		table.insert(out, main.id)
	end
	return out
end

-- 퀘스트 창의 「완료」: 끝낸 것(자료의 차례 — 전직 · 메인 · 부탁)
function Q.listDone(book): { string }
	local out = {}
	for _, def in D.list do
		local st = book[def.id]
		if st and st.done then
			table.insert(out, def.id)
		end
	end
	return out
end

-- 그 퀘스트를 주는 주민이 서 있는 맵의 이름 — 그 퀘스트의 지역 안에서(주민은 제가 선 지역의 퀘스트만 준다).
--  여러 맵에 서 있으면(샛별 · 반달 · 하늬) 그 퀘스트를 하는 맵에서 문으로 가장 가까운 곳 — 같으면 몬스터가 없는 맵, 그다음은 이름표의 차례. 못 찾으면 nil
local placeOf = {}
-- 그 주민이 서 있는 장면의 이름표(월드맵이 그 맵에 ! 를 찍는다). 못 찾으면 nil
function Q.npcScene(def, npcId: string?): string?
	if typeof(npcId) ~= "string" then
		return nil -- 주는 · 돌려받는 주민이 없는 퀘스트(놀이 자료가 없다 — 2026-10-15에 줄에서 뺀 것): 갈 곳이 없다
	end
	local cacheKey = def.id .. "|" .. npcId
	if placeOf[cacheKey] ~= nil then
		return placeOf[cacheKey] or nil
	end
	local SCENES = require(script.Parent.Parent.data["scenes.generated"])
	-- 퀘스트를 하는 맵에서 문을 몇 번 지나야 닿는가
	local dist = {}
	if def.scene and SCENES.scenes[def.scene] then
		dist[def.scene] = 0
		local queue, at = { def.scene }, 1
		while queue[at] do
			local key = queue[at]
			at += 1
			for _, p in SCENES.scenes[key].portals or {} do
				if SCENES.scenes[p.to] and dist[p.to] == nil then
					dist[p.to] = dist[key] + 1
					table.insert(queue, p.to)
				end
			end
		end
	end
	local keys = {}
	for key, sc in SCENES.scenes do
		if sc.region == def.region then
			for _, n in sc.npcs or {} do
				if n.id == npcId then
					table.insert(keys, key)
					break
				end
			end
		end
	end
	if #keys == 0 then
		-- 그 지역에 없는 사람(2026-10-16 — 촌장이 주고 도시의 안내인이 돌려받는 「큰 항구로」 · 도시의 안내인이 주고 나루의 견습 기사가 돌려받는 「강 위의 나루」): 어디든
		for key, sc in SCENES.scenes do
			for _, n in sc.npcs or {} do
				if n.id == npcId then
					table.insert(keys, key)
					break
				end
			end
		end
	end
	table.sort(keys, function(a, b)
		local da, db = dist[a] or math.huge, dist[b] or math.huge
		if da ~= db then
			return da < db
		end
		local qa, qb = #(SCENES.scenes[a].mobs or {}) == 0, #(SCENES.scenes[b].mobs or {}) == 0
		if qa ~= qb then
			return qa
		end
		-- 같은 거리면 마을(쓰러졌을 때 돌아오는 곳 — 초승달 마을 · 고갯마루 주막)이 먼저다: 샛별은 마을에도 세 갈래 길에도 서 있다(2026-10-13 — 길을 다시 이으며 둘이 같은 거리가 됐다)
		local ha, hb = SCENES.homes[a] ~= nil, SCENES.homes[b] ~= nil
		if ha ~= hb then
			return ha
		end
		return a < b
	end)
	placeOf[cacheKey] = keys[1] or false
	return keys[1]
end
-- 그 퀘스트를 주는 주민이 선 장면 · 돌려받는 주민이 선 장면
function Q.giverScene(def): string?
	return Q.npcScene(def, def.giver)
end
function Q.endScene(def): string?
	return Q.npcScene(def, def.endNpc)
end

-- 이야기를 따라갈 때 지금 가야 할 곳(월드맵이 거기까지의 길을 그린다 — 메이플스토리의 월드맵이 가는 길을 보여 주듯):
--  하는 중인 전직 · 메인 퀘스트가 있으면 그 퀘스트를 하는 맵(다 했으면 돌려받는 주민이 선 곳), 없으면 지금 받을 수 있는 다음 메인을 주는 주민이 선 곳.
--  { def, scene, kind = "do"(하러) · "back"(돌려주러) · "take"(받으러) } — 갈 곳이 없으면 nil(레벨이 모자라 다음 메인을 못 받을 때)
function Q.goal(book, level: number)
	for _, id in Q.active(book) do
		local def = byId[id]
		if def.kind == "job" or def.kind == "main" then
			if Q.state(book, level, id) == "ready" then
				local scene = Q.endScene(def)
				if scene then
					return { def = def, scene = scene, kind = "back" }
				end
			elseif def.scene then
				-- 들르는 일이 남았으면 그 맵으로(차례대로 — 2026-10-16)
				local st = book[id]
				for i, step in def.steps do
					if step.type == "visit" and (st.c[i] or 0) < step.n then
						return { def = def, scene = step.at, kind = "do" }
					elseif step.type == "meet" and (st.c[i] or 0) < step.n then
						local at = Q.npcScene(def, step.npc) -- 만날 사람이 선 곳(차례대로)
						if at then
							return { def = def, scene = at, kind = "do", npc = step.npc }
						end
					end
				end
				return { def = def, scene = def.scene, kind = "do" }
			end
		end
	end
	-- 받을 수 있는 전직 퀘스트가 있으면 그것을 주는 사제에게 먼저
	for _, job in Q.openJobs(book, level) do
		local scene = Q.giverScene(job)
		if scene then
			return { def = job, scene = scene, kind = "take" }
		end
	end
	local def, why = Q.nextMain(book, level)
	if def and why == "open" and not def.auto then
		local scene = Q.giverScene(def)
		if scene then
			return { def = def, scene = scene, kind = "take" }
		end
	end
	return nil
end

function Q.giverPlace(def): string?
	local key = Q.giverScene(def)
	return if key then require(script.Parent.Parent.data["scenes.generated"]).scenes[key].name else nil
end

-- 알리미의 길잡이 줄들: { { title, line, kind = "job" | "open" | "level" | "side" } … } — 받을 수 있는 전직 퀘스트 · 다음 메인 하나 · 받을 수 있는 부탁 둘까지. names = 주민 id → 이름
function Q.guide(book, level: number, names)
	local out = {}
	local function who(def): string
		return (names and names[def.giver]) or "주민"
	end
	for _, def in Q.openJobs(book, level) do
		local place = Q.giverPlace(def)
		table.insert(out, { id = def.id, title = "! " .. def.name, line = if place then ("%s에게 받는다 · %s"):format(who(def), place) else ("%s에게 받는다"):format(who(def)), kind = "job" })
	end
	local main, why = Q.nextMain(book, level)
	if main and why == "open" then
		local place = Q.giverPlace(main)
		table.insert(out, { id = main.id, title = "! " .. main.name, line = if place then ("%s에게 받는다 · %s"):format(who(main), place) else ("%s에게 받는다"):format(who(main)), kind = "open" })
	elseif main then
		table.insert(out, { title = main.name, line = ("Lv.%d부터 받는다"):format(main.lv), kind = "level" })
	end
	local sides = Q.openSides(book, level)
	for i = 1, math.min(2, #sides) do
		local def = sides[i]
		local place = Q.giverPlace(def)
		table.insert(out, { id = def.id, title = "! " .. def.name, line = if place then ("%s에게 받는다 · %s"):format(who(def), place) else ("%s에게 받는다"):format(who(def)), kind = "side" })
	end
	return out
end

-- 하는 중인 퀘스트들(전직 퀘스트가 맨 위 · 메인 · 그다음은 받은 차례가 아니라 자료의 차례)
local KIND_ORDER = { job = 1, main = 2, side = 3 }
function Q.active(book): { string }
	local list = {}
	for id, st in book do
		if not st.done and byId[id] then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		local da, db = byId[a], byId[b]
		local ka, kb = KIND_ORDER[da.kind] or 9, KIND_ORDER[db.kind] or 9
		if ka ~= kb then
			return ka < kb
		end
		return da.order < db.order
	end)
	return list
end

-- 알리미에 적는 줄들: 할 일이 남았으면 그것들, 다 됐으면 「○○에게 돌아간다」. names = 주민 id → 이름
function Q.todo(book, id: string, names): { string }
	local def, st = byId[id], book[id]
	local out = {}
	if not def or not st then
		return out
	end
	for i, step in def.steps do
		if (st.c[i] or 0) < step.n then
			table.insert(out, Q.trackText(step, st.c[i] or 0))
		end
	end
	if #out == 0 then
		table.insert(out, ("%s에게 간다"):format((names and names[def.endNpc]) or "주민"))
	end
	return out
end

-- 클라이언트에 보내는 꼴(수의 표를 빈 데 없이 채운다 — 빈 데가 있으면 보낼 때 잘린다)
function Q.view(book)
	local out = {}
	for id, st in book do
		local def = byId[id]
		if def then
			local counts = {}
			for i in def.steps do
				counts[i] = st.c[i] or 0
			end
			out[id] = { done = st.done, c = counts }
		end
	end
	return out
end

-- ---------- 저장 ----------
function Q.pack(book)
	local out = {}
	for id, st in book do
		if byId[id] then
			local counts = {}
			for i, step in byId[id].steps do
				counts[i] = math.min(st.c[i] or 0, step.n)
			end
			out[id] = { d = if st.done then 1 else 0, c = counts }
		end
	end
	return out
end

-- 저장된 것을 되살린다(모르는 퀘스트 · 이상한 수는 버린다)
function Q.unpack(data: any)
	local book = {}
	if typeof(data) ~= "table" then
		return book
	end
	for id, row in data do
		local def = Q.def(id)
		-- 하는 중이던 퀘스트가 이제 할 수 없는 것이면(2026-10-15에 줄에서 뺀 등불 심지 · 낡은 달력 …) 지운다 — 끝낼 수도, 돌려줄 주민도 없어 알리미 · 길찾기에 남는다.
		--  끝낸 것은 그대로 둔다(줄의 앞뒤 · 열리는 문이 끝낸 것을 본다)
		if def and typeof(row) == "table" and (row.d == 1 or def.playable) then
			local st = { done = row.d == 1, c = {} }
			if typeof(row.c) == "table" then
				for i, step in def.steps do
					local n = row.c[i]
					if typeof(n) == "number" and n == math.floor(n) and n >= 0 then
						st.c[i] = math.min(n, step.n)
					end
				end
			end
			book[id] = st
		end
	end
	return book
end

return Q
