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

-- 새 캐릭터: 저절로 받는 퀘스트(첫 메인)
function Q.start(book, level: number)
	for _, def in D.list do
		if def.auto and Q.state(book, level, def.id) == "open" then
			Q.accept(book, level, def.id)
		end
	end
end

-- 졸개를 잡았다. 바뀐 퀘스트들의 id를 돌려준다(없으면 빈 표). 잡는 일만 센다 — 모으는 물건은 땅에 떨어지고(Q.drops) 주워야 오른다(Q.onLoot)
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

-- 졸개를 잡았을 때 떨어지는 퀘스트의 물건들: 아직 모으는 중인 물건마다 그 확률(pct)로 하나. { { quest, step, name, icon } … }
--  사용자 2026-10-07: "퀘스트 아이템이나 , 기타아이템들은 왜 드롭도되지않고 그림도없고 그냥 텍스트로만 오르나요?" — 잡으면 숫자만 오르던 것을, 그림이 있는 물건이 땅에 떨어지고 주워야 오르게 고쳤다
function Q.drops(book, mobKind: string, scene: string, rng)
	local out = {}
	for id, st in book do
		local def = byId[id]
		if def and not st.done and def.scene == scene then
			for i, step in def.steps do
				if step.type == "gather" and step.mob == mobKind and (st.c[i] or 0) < step.n and rng:NextNumber(0, 100) < step.pct then
					table.insert(out, { quest = id, step = i, name = step.name, icon = step.icon })
				end
			end
		end
	end
	return out
end

-- 퀘스트의 물건을 주웠다. 그 퀘스트의 숫자가 올랐으면 true(이미 다 모았거나 그만둔 퀘스트면 false — 물건은 그냥 사라진다)
function Q.onLoot(book, id: any, step: number): boolean
	local def, st = byId[id], book[id]
	local s = def and def.steps[step]
	if not st or st.done or not s or s.type ~= "gather" then
		return false
	end
	local have = st.c[step] or 0
	if have >= s.n then
		return false
	end
	st.c[step] = have + 1
	return true
end

-- 지금 모으고 있는 물건들(가방의 재료 탭에 보인다): { { name, icon, have, n } … } — 받은 퀘스트의 것만, 끝낸 퀘스트의 것은 빠진다
function Q.items(book)
	local out = {}
	for _, def in D.list do
		local st = book[def.id]
		if st and not st.done then
			for i, step in def.steps do
				if step.type == "gather" then
					table.insert(out, { name = step.name, icon = step.icon, have = st.c[i] or 0, n = step.n })
				end
			end
		end
	end
	return out
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
	elseif def.kind == "main" then
		return nil, "메인 퀘스트는 그만둘 수 없다"
	end
	book[id] = nil
	return true
end

-- 그 주민에게서 할 수 있는 것: ready = 돌려줄 것 · offer = 받을 것 · wait = 받아서 하는 중인 것(이 주민에게 돌려줄 것)
function Q.atNpc(book, level: number, npc: string)
	local out = { ready = {}, offer = {}, wait = {} }
	for _, def in D.list do
		local state = Q.state(book, level, def.id)
		if def.endNpc == npc and state == "ready" then
			table.insert(out.ready, def.id)
		elseif def.giver == npc and state == "open" and not def.auto then
			table.insert(out.offer, def.id)
		elseif def.endNpc == npc and state == "active" then
			table.insert(out.wait, def.id)
		end
	end
	return out
end

-- 주민 머리 위의 표시: "?" 돌려줄 것이 있다 · "!" 줄 것이 있다 · nil
function Q.mark(book, level: number, npc: string): string?
	local at = Q.atNpc(book, level, npc)
	return if #at.ready > 0 then "?" elseif #at.offer > 0 then "!" else nil
end

-- 하는 중인 퀘스트들(메인이 먼저, 그다음 받은 차례가 아니라 자료의 차례)
function Q.active(book): { string }
	local list = {}
	for id, st in book do
		if not st.done and byId[id] then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		local da, db = byId[a], byId[b]
		if (da.kind == "main") ~= (db.kind == "main") then
			return da.kind == "main"
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
