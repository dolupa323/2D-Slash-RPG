-- 「달의 계승자」 — 2편(Lv.30~59)의 퀘스트를 하나씩 끝까지(2026-10-16): 은달 항구의 흩어진 퀘스트(cq) · 2편의 메인 · 사이드 · 3차 전직.
--  보는 것: 앞 퀘스트를 끝내고 · 레벨이 되면 받을 수 있다 → 할 일(잡기 · 모으기 · 들르기 · 만나기 · 자리)을 실제 셈으로 채운다 → 돌려줄 수 있다 → 보상을 받는다(가방 · 달돈 · 경험치).
--   (호감도는 뺐다 — 사용자 2026-10-16 "호감도는 왜만드는거고": 「우호」부터 열리는 퀘스트도 없다)
--   할 일의 자리(↑ 자리 · 들르기 맵)가 게임의 장면에 있는지, 모으는 물건이 가방에 들어가는 아이템인지도 함께 본다 — 한 번도 끝까지 해 보지 않은 퀘스트가 없게.
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

local list = {}
for _, def in Quests.list do
	if def.playable and (def.city or def.region == "r2" or def.id == "job3") then
		table.insert(list, def)
	end
end
expect(#list >= 40, ("2편의 퀘스트가 넉넉하다(%d)"):format(#list))

local n = 0
for i, def in list do
	local h = Hero.new(5600 + i, "riven")
	h.level = math.max(def.lv, 1)
	-- 앞 퀘스트들을 끝낸 것으로(줄을 거슬러)
	local a = def.after
	local guard = 0
	while a and guard < 40 do
		h.quests[a] = { done = true, c = {} }
		local prev = Quests.def(a)
		a = prev and prev.after
		guard += 1
	end
	-- 전직 퀘스트는 앞의 전직을 마친 캐릭터(3차 = 2차를 마침)
	if def.kind == "job" then
		h.job = (def.job or 3) - 1
	end
	expect(def.rapport == nil, def.id .. ": 호감도의 자물쇠가 없다")
	eq(Quests.state(h.quests, h.level, def.id), "open", def.id .. " 「" .. def.name .. "」: 받을 수 있다")
	local ok, why = Quests.accept(h.quests, h.level, def.id)
	expect(ok, def.id .. ": 받는다 " .. tostring(why))
	if ok then
		for si, step in def.steps do
			if step.type == "kill" then
				for _ = 1, step.n do
					Quests.onKill(h.quests, step.mob, def.scene)
				end
			elseif step.type == "gather" then
				expect(step.item ~= nil and Items.goods(step.item) ~= nil, def.id .. ": 모으는 물건 「" .. tostring(step.name) .. "」은 가방의 아이템이다")
				if step.item and Items.goods(step.item) then
					Bag.give(h, step.item, step.n)
					Quests.sync(h.quests, function(item)
						return Bag.count(h, item)
					end)
				end
			elseif step.type == "visit" then
				expect(SCENES.scenes[step.at] ~= nil, def.id .. ": 들를 맵 " .. tostring(step.at) .. "이 게임에 있다")
				Quests.onVisit(h.quests, step.at)
			elseif step.type == "meet" then
				local stands = false
				for _, sc in SCENES.scenes do
					for _, nn in sc.npcs or {} do
						stands = stands or nn.id == step.npc
					end
				end
				expect(stands, def.id .. ": 만날 사람 " .. tostring(step.npc) .. "이 게임의 장면에 서 있다")
				Quests.onMeet(h.quests, step.npc)
			elseif step.type == "use" then
				expect(SCENES.scenes[def.scene] ~= nil and step.x ~= nil, def.id .. ": ↑ 자리가 게임의 장면에 있다")
				for _ = 1, step.n do
					Quests.use(h.quests, def.id, def.scene, step.x, step.y)
				end
			else
				expect(false, def.id .. ": 모르는 할 일 " .. tostring(step.type) .. " (" .. si .. ")")
			end
		end
		expect(Quests.isReady(h.quests, def.id), def.id .. " 「" .. def.name .. "」: 할 일을 다 하면 돌려줄 수 있다")
		local money0 = h.money
		local got, why2 = Hero.questDone(h, def.id)
		expect(got ~= nil, def.id .. ": 보상을 받는다 " .. tostring(why2))
		if got then
			n += 1
			expect(h.quests[def.id].done, def.id .. ": 끝났다")
			expect(h.money >= money0, def.id .. ": 달돈은 줄지 않는다")
			expect(got.gifts == nil, def.id .. ": 보상에 선물이 없다")
		end
	end
end
eq(n, #list, "2편의 퀘스트를 모두 끝까지 했다")
