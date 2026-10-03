-- 본 줄거리 퀘스트: 자료 정합성(공방 설계를 옮긴 quests.generated) · 저장 형태 · 받기/끝내기 흐름(말 걸기 · 처치 · 모으기 · 가기 · 전직)
--  · 레벨 제한 · 가방이 가득 찼을 때 · 추적창 글이 칸에 들어가는가 · 글꼴에 없는 글자가 없는가
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local balance = req("ReplicatedStorage/shared/config/balance")
local quests = req("ReplicatedStorage/shared/config/quests")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local packets = req("ReplicatedStorage/shared/net/packets")
local schema = req("ServerScriptService/server/services/playerSchema")
local text = req("Client/ui/pixelText")
local font = req("ReplicatedStorage/shared/data/pixelFont.generated")

local LIST = quests.LIST
local function indexOf(id)
	for i, q in LIST do
		if q.id == id then return i end
	end
	error("퀘스트 없음 " .. id)
end

-- ---- 1) 자료 정합성 ----
expect(quests.COUNT >= 50, "퀘스트 수")
local speciesById, npcTypes = {}, {}
for _, s in world.species do speciesById[s.id] = s end
for _, sc in world.scenes do
	for _, n in sc.npcs do npcTypes[n.type] = true end
end
local KINDS = { talk = true, kill = true, collect = true, reach = true, boss = true, job = true, ride = true }
local seen, prevLevel = {}, 0
local function known(s)
	for _, code in utf8.codes(s) do
		local ok = (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163)
		if not ok then
			for _, ch in font.body.extra do
				if utf8.codepoint(ch) == code then ok = true end
			end
		end
		if not ok then return false end
	end
	return true
end
local TRACK_W = 172 - 20 -- globals/quest.luau 추적창 글 폭
local function fits(s) return text.Fit(s, TRACK_W, 1) == s end
for i, q in LIST do
	expect(not seen[q.id], "id가 겹치지 않음 " .. q.id)
	seen[q.id] = true
	expect(KINDS[q.kind] == true, "알려진 종류 " .. q.id)
	expect(q.level >= prevLevel and q.level >= 1 and q.level <= 100, "레벨이 차례대로 " .. q.id)
	prevLevel = q.level
	expect(typeof(q.giver) == "string" and typeof(q.giverName) == "string" and typeof(q.targetName) == "string", "주는 사람 · 목표 이름 " .. q.id)
	expect(q.exp >= 0 and q.gold >= 0 and q.count >= 1, "보상 · 개수 " .. q.id)
	if q.kind == "kill" then
		expect(speciesById[q.target] ~= nil, "처치 대상이 몬스터 표에 있음 " .. q.id)
		eq(speciesById[q.target] and speciesById[q.target].name, q.targetName, "몬스터 이름 " .. q.id)
	elseif q.kind == "collect" then
		expect(items[q.target] ~= nil, "모을 아이템이 있음 " .. q.id)
	elseif q.kind == "reach" then
		expect(q.scene == nil or world.scenes[q.scene] ~= nil, "갈 씬 " .. q.id)
	elseif q.kind == "job" then
		eq(q.level, ninjutsu.JOB_LEVELS[tonumber(q.target)], "전직 퀘스트 레벨 = 전직 레벨 " .. q.id)
	end
	if q.item then
		expect(q.item == "SchoolScroll" or items[q.item] ~= nil, "보상 아이템 " .. q.id)
		expect((q.itemCount or 0) >= 1, "보상 개수 " .. q.id)
	end
	-- 글: 글꼴에 있는 글자만, 추적창 한 줄에 들어감
	for _, s in { q.title, q.text, q.offer, q.done, q.giverName, q.targetName } do
		expect(known(s), ("글꼴에 없는 글자 %s: %s"):format(q.id, s))
	end
	expect(fits(q.title), ("추적창 제목 자리에 들어감 %s: %s"):format(q.id, q.title))
	local job = tonumber(q.target) or 0
	for _, line in {
		quests.Objective(q, false, 0, 0, 0, 1), quests.Objective(q, false, 0, 0, 0, 100),
		quests.Objective(q, true, 0, 0, 0, 100), quests.Objective(q, true, q.count, q.count, job, 100),
	} do
		expect(fits(line), ("추적창 할 일 자리에 들어감 %s: %s (%d)"):format(q.id, line, (text.Measure(line))))
	end
end
-- 지금 지은 맵만으로 할 수 있는 앞부분: 주는 사람이 마을에 있다
for _, id in { "m001", "m002", "m003", "m004", "m101", "m102" } do
	expect(npcTypes[LIST[indexOf(id)].giver] == true, "주는 사람이 게임에 있음 " .. id)
end
expect(packets.QuestTalk ~= nil and packets.QuestUpdated ~= nil, "패킷 등록")
expect(packets.QuestTalk.Args[1]("elder") and not packets.QuestTalk.Args[1](3), "QuestTalk 인자")

-- 규칙 함수
local kill, collect, talk, reach, job = LIST[indexOf("m002")], LIST[indexOf("m004")], LIST[indexOf("m001")], LIST[indexOf("m103")], LIST[indexOf("m106")]
eq(quests.TurnIn(kill), kill.giver, "처치: 주는 사람에게 돌아가 끝냄")
eq(quests.TurnIn(reach), nil, "가기: 닿으면 끝")
expect(quests.Instant(talk) and not quests.Instant(kill), "주는 사람 = 말 걸 사람이면 받자마자 끝")
expect(not quests.Ready(kill, 4, 0, 0) and quests.Ready(kill, 5, 0, 0), "처치 수")
expect(not quests.Ready(collect, 0, 0, 0) and quests.Ready(collect, 0, 1, 0), "모은 개수")
expect(not quests.Ready(job, 0, 0, 0) and quests.Ready(job, 0, 0, 1), "전직 단계")
eq(quests.Objective(kill, false, 0, 0, 0, 1), "Lv.2부터 · 스승", "할 일: 레벨이 모자람")
eq(quests.Objective(kill, false, 0, 0, 0, 2), "스승에게 가기", "할 일: 받으러 가기")
eq(quests.Objective(kill, true, 3, 0, 0, 2), "말랑이 3/5", "할 일: 처치 수")
eq(quests.Objective(kill, true, 5, 0, 0, 2), "스승에게 돌아가기", "할 일: 돌아가기")
eq(quests.Objective(collect, true, 0, 0, 0, 3), "구리 주괴 0/1", "할 일: 모으기")
eq(quests.Objective(reach, true, 0, 0, 0, 9), "나비 언덕 1 가기", "할 일: 가기")
eq(quests.Objective(job, true, 0, 0, 0, 10), "1차 전직 하기", "할 일: 전직")
eq(quests.RewardItem(job, "ice"), "ScrollIce", "유파 두루마리 보상")
eq(quests.RewardItem(job, ""), nil, "유파가 없으면 두루마리 없음")

-- ---- 2) 저장 형태 ----
local fresh = schema.default()
expect(fresh.Quest.Index == 1 and fresh.Quest.Accepted == false and fresh.Quest.Progress == 0, "새 플레이어: 첫 퀘스트부터")
local old = schema.default()
old.SchemaVersion, old.Quest = 11, nil
schema.migrate(old)
expect(old.SchemaVersion == schema.CURRENT_VERSION and old.Quest.Index == 1, "v11 → v12 마이그레이션")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_village" }
local pos = { [1] = V(0, 0) }
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
local sceneChanged
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function(fn) sceneChanged = sceneChanged or {}; table.insert(sceneChanged, fn) end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local gained = 0
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function(_, n) gained += n end,
	DamagePlayer = function() end,
	Heal = function() return 0 end,
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local questService = req("ServerScriptService/server/modules/questService")
townMonsters.load()
questService.load()
expect(handlers.QuestTalk ~= nil, "QuestTalk 핸들러 등록")

local npcAt = {}
for _, n in world.scenes.village.npcs do npcAt[n.type] = n end
local function at(npcType)
	where[1] = "town_village"
	pos[1] = V(npcAt[npcType].x * world.scale, (npcAt[npcType].y + 10) * world.scale)
end
local function away() where[1] = "town_village"; pos[1] = V(0, 0) end
local function talkTo(npcType) at(npcType); handlers.QuestTalk(p1, npcType) end
-- 그 씬에서 그 종 몬스터 n마리를 쓰러뜨린다(혼자 다 때림)
local function slay(key, speciesId, n)
	where[1] = "town_" .. key
	local done = 0
	for _, m in townMonsters.Living(key) do
		if done >= n then break end
		if world.species[m.row].id == speciesId then
			townMonsters.Damage(key, m.id, p1, m.maxHp, "test")
			done += 1
		end
	end
	eq(done, n, ("%s에서 %s %d마리 처치"):format(key, speciesId, n))
end
local Q = data[p1].Quest
local function last() local l = sent("QuestUpdated"); return l[#l] end

-- ---- 3) 흐름: 서장 ----
-- m001 스승의 부름(말 걸기, 받자마자 끝)
away()
handlers.QuestTalk(p1, "elder")
eq(Q.Index, 1, "스승 곁이 아니면 아무 일도 없음")
talkTo("merchant")
eq(Q.Index, 1, "주는 사람이 아니면 아무 일도 없음")
clear(); gained = 0
talkTo("elder")
expect(Q.Index == 2 and Q.Accepted == false, "m001: 스승에게 말을 걸면 바로 끝나고 다음 퀘스트로")
eq(gained, LIST[1].exp, "m001 경험치")
local u = last()
expect(u ~= nil and u.args[1] == 2 and u.args[2] == false and u.args[4] == "m001", "QuestUpdated(번호, 받았는가, 진행, 끝낸 id)")

-- m002 첫 수련(말랑이 5)
data[p1].Level = 1
clear()
talkTo("elder")
expect(Q.Accepted == false and noticed("Lv.2"), "레벨이 모자라면 못 받음")
data[p1].Level = 2
slay("field1", "Slime", 2)
eq(Q.Progress, 0, "받기 전에 잡은 것은 세지 않음")
talkTo("elder")
expect(Q.Index == 2 and Q.Accepted == true and Q.Progress == 0, "m002 받음")
clear()
slay("field1", "Slime", 3)
eq(Q.Progress, 3, "말랑이 3마리")
eq(#sent("QuestUpdated"), 3, "잡을 때마다 QuestUpdated")
talkTo("elder")
eq(Q.Index, 2, "다 못 채우면 못 끝냄")
slay("field1", "Slime", 4)
eq(Q.Progress, 5, "목표보다 더 세지 않음")
talkTo("merchant")
eq(Q.Index, 2, "끝낼 사람이 아니면 못 끝냄")
local gold, rice = data[p1].Gold, inventory.CountItem(p1, "Onigiri")
gained = 0
talkTo("elder")
expect(Q.Index == 3 and Q.Accepted == false and Q.Progress == 0, "m002 끝")
eq(data[p1].Gold, gold + kill.gold, "m002 엽전")
eq(inventory.CountItem(p1, "Onigiri"), rice + 5, "m002 주먹밥 5")
eq(gained, kill.exp, "m002 경험치")

-- m003 닌자의 도구(잡화상, 바로 끝) — 가방이 가득 차 있으면 끝나지 않는다
local keep = data[p1].Inventory
local full = {}
for slot = 1, balance.INVENTORY_SLOTS do
	table.insert(full, { Tab = "Use", Slot = slot, ItemId = "Sushi", Count = items.Sushi.StackMax })
end
data[p1].Inventory = full
clear()
talkTo("merchant")
expect(Q.Index == 3 and Q.Accepted == true and noticed("가방"), "가방이 가득 차면 보상을 못 받아 끝나지 않음(받은 상태로 남음)")
data[p1].Inventory = keep
local stars = inventory.CountItem(p1, "Shuriken")
talkTo("merchant")
expect(Q.Index == 4, "m003: 자리가 생기면 다시 말을 걸어 끝냄")
eq(inventory.CountItem(p1, "Shuriken"), stars + 30, "m003 수리검 30")

-- m004 칼을 벼리다(구리 주괴 1 → 대장장이)
data[p1].Level = 3
talkTo("blacksmith")
expect(Q.Index == 4 and Q.Accepted, "m004 받음")
inventory.TakeItem(p1, "CopperBar", inventory.CountItem(p1, "CopperBar")) -- 앞에서 주운 것은 치운다
talkTo("blacksmith")
eq(Q.Index, 4, "주괴가 없으면 못 끝냄")
inventory.AddItem(p1, "CopperBar", 1)
talkTo("blacksmith")
eq(Q.Index, 5, "m004 끝")
eq(inventory.CountItem(p1, "CopperBar"), 3, "주괴 1개를 내고 3개를 받음")

-- ---- 4) 1장 ----
-- m101 버섯돌이 12(약방 주인)
talkTo("potion")
expect(Q.Index == 5 and Q.Accepted, "m101 받음")
slay("field3", "Mushroom", 12)
eq(Q.Progress, 12, "버섯돌이 12마리")
talkTo("potion")
eq(Q.Index, 6, "m101 끝")
-- m102 풀잎 10
data[p1].Level = 4
talkTo("potion")
inventory.TakeItem(p1, "GrassBlade", inventory.CountItem(p1, "GrassBlade"))
inventory.AddItem(p1, "GrassBlade", 9)
talkTo("potion")
eq(Q.Index, 6, "풀잎 9장으로는 못 끝냄")
inventory.AddItem(p1, "GrassBlade", 3)
talkTo("potion")
eq(Q.Index, 7, "m102 끝")
eq(inventory.CountItem(p1, "GrassBlade"), 2, "풀잎 10장만 냄")
-- m103 가기(나비 언덕 1 = hill1): 그 씬에 들어서면 바로 끝난다
data[p1].Level = 6
eq(LIST[7].id, "m103", "일곱 번째 = m103")
eq(LIST[7].scene, "hill1", "m103이 가리키는 씬")
local fire = function(sceneName)
	where[1] = sceneName
	for _, fn in sceneChanged do fn(1, "town_village", sceneName) end
end
fire("town_hill1")
eq(Q.Index, 7, "받기 전에 가 본 것은 치지 않음")
talkTo("elder")
expect(Q.Index == 7 and Q.Accepted, "m103 받음")
fire("town_field1")
eq(Q.Index, 7, "다른 씬에 들어가도 끝나지 않음")
clear(); gained = 0
fire("town_hill1")
expect(Q.Index == 8 and last().args[4] == "m103", "가기: 그 씬에 들어서면 바로 끝남")
eq(gained, LIST[7].exp, "m103 경험치")
-- m104 도토리쥐 15(창고지기) — 나비 언덕 3 · 큰 웅덩이
data[p1].Level = 7
talkTo("storage")
expect(Q.Index == 8 and Q.Accepted, "m104 받음")
slay("hill3", "Mouse", 8)
slay("pond", "Mouse", 7)
eq(Q.Progress, 15, "도토리쥐 15마리(두 맵에 걸쳐)")
talkTo("storage")
eq(Q.Index, 9, "m104 끝")
-- 줄기가 이어져 있다: 마을 → 새싹 들판 1 → 2 → 3 → 나비 언덕 1 → 2 → 3 → 큰 웅덩이, 그리고 되돌아오는 포탈
local chain = { "village", "field1", "field2", "field3", "hill1", "hill2", "hill3", "pond" }
for i = 1, #chain - 1 do
	local function linked(a, b)
		for _, p in world.scenes[a].portals do
			if p.to == b then return true end
		end
		return false
	end
	expect(linked(chain[i], chain[i + 1]) and linked(chain[i + 1], chain[i]), ("포탈 %s ↔ %s"):format(chain[i], chain[i + 1]))
end

-- ---- 5) 전직 퀘스트(m106): 스승에게 받고, 전직한 뒤 다시 말을 걸면 끝 ----
Q.Index, Q.Accepted, Q.Progress = indexOf("m106"), false, 0
data[p1].Level = 10
talkTo("elder")
expect(Q.Accepted, "m106 받음")
talkTo("elder")
eq(Q.Index, indexOf("m106"), "전직 전에는 못 끝냄")
data[p1].Job, data[p1].School = 1, "fire"
local scrolls = inventory.CountItem(p1, "ScrollFire")
talkTo("elder")
eq(Q.Index, indexOf("m106") + 1, "m106 끝")
eq(inventory.CountItem(p1, "ScrollFire"), scrolls + 1, "내 유파의 두루마리 1")

-- ---- 6) 다 끝낸 뒤 ----
Q.Index, Q.Accepted, Q.Progress = quests.COUNT + 1, false, 0
clear()
talkTo("elder")
eq(#sent("QuestUpdated"), 0, "퀘스트를 다 끝냈으면 아무 일도 없음")
