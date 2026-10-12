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

-- 할 일 하나를 화면에 적는 꼴: 「수습 검병 3/5」
function Q.stepText(step, have: number): string
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
function Q.onKill(book, mobKind: string, scene: string): { string }
	local changed = {}
	for id, st in book do
		local def = byId[id]
		if def and not st.done and def.scene == scene then
			for i, step in def.steps do
				local have = st.c[i] or 0
				if step.type == "kill" and step.mob == mobKind and have < step.n then
					st.c[i] = have + 1
					table.insert(changed, id)
				end
			end
		end
	end
	return changed
end

-- 그 장면의 그 몬스터를 아직 잡아야 하는가(하는 중인 퀘스트의 못 다 한 잡기). 스토리 보스는 이것이 참인 사람이 방에 있을 때만 서 있다(sim/room.luau)
-- 그 퀘스트에 닿았는가: 받았거나(하는 중) 끝냈다 — 그 퀘스트를 받아야 열리는 문(장면의 portals의 need — 사당 지하)이 쓴다
function Q.reached(book, id: any): boolean
	return book ~= nil and typeof(id) == "string" and book[id] ~= nil
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
		if def and not st.done and def.scene == scene then
			for i, step in def.steps do
				if step.type == "gather" and step.mob == mobKind and (st.c[i] or 0) < step.n and rng:NextNumber(0, 100) < step.pct then
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
function Q.npcScene(def, npcId: string): string?
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
	table.sort(keys, function(a, b)
		local da, db = dist[a] or math.huge, dist[b] or math.huge
		if da ~= db then
			return da < db
		end
		local qa, qb = #(SCENES.scenes[a].mobs or {}) == 0, #(SCENES.scenes[b].mobs or {}) == 0
		if qa ~= qb then
			return qa
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
		table.insert(out, { title = "! " .. def.name, line = if place then ("%s에게 받는다 · %s"):format(who(def), place) else ("%s에게 받는다"):format(who(def)), kind = "job" })
	end
	local main, why = Q.nextMain(book, level)
	if main and why == "open" then
		local place = Q.giverPlace(main)
		table.insert(out, { title = "! " .. main.name, line = if place then ("%s에게 받는다 · %s"):format(who(main), place) else ("%s에게 받는다"):format(who(main)), kind = "open" })
	elseif main then
		table.insert(out, { title = main.name, line = ("Lv.%d부터 받는다"):format(main.lv), kind = "level" })
	end
	local sides = Q.openSides(book, level)
	for i = 1, math.min(2, #sides) do
		local def = sides[i]
		local place = Q.giverPlace(def)
		table.insert(out, { title = "! " .. def.name, line = if place then ("%s에게 받는다 · %s"):format(who(def), place) else ("%s에게 받는다"):format(who(def)), kind = "side" })
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
		if def and typeof(row) == "table" then
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
