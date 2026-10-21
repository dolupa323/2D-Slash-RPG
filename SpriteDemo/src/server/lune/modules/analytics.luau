-- 플레이어 데이터 기록 — 로블록스의 분석(AnalyticsService)에 보낸다(2026-10-15)
--  사용자: "플레이어 데이터 수집 로블록스에서 어떻게 진행되는지 알아보고 조치합시다"
--  보는 곳: 크리에이터 대시보드 → 경험 → 분석(Analytics)
--   · Funnels: 온보딩(접속 → 캐릭터 → 달빛 꿈의 미션 열하나 → 깨어남 → 첫 퀘스트 → Lv.5 · Lv.10) · MainQuest(1지역 줄 14개) · Part2Quest(2편의 길 열둘 — 2026-10-16) · Level(Lv.1 → 100)
--   · Economy: 달돈(Money)이 어디서 들어오고(퀘스트 · 일일 의뢰 · 몬스터 · 상점에 팔기 · 경매 대금) 어디로 나가는가(상점 · 가방 늘리기 · 제작 · 대장간 · 경매)
--   · Explore(커스텀 이벤트): LevelUp(값 = 그 캐릭터로 논 분) · JobAdvanced(값 = 레벨) · Death(어느 맵) · DailyDone · Enhance(값 = 노린 별 · 결과) · RiftEnter · RiftClear(수정 틈 토벌 — 단계, 2026-10-16) · FieldElite(사냥터 정예를 잡음 — 맵, 2026-10-18)
--  로블록스의 규칙(문서 2026-10 — 조사는 공방 「개발 진행」): 서버에서만 · 게시된 게임에서만 간다(Studio에서는 보내지 않는다 — 여기서도 Studio에서는 부르지 않고 Analytics.log에만 적는다).
--   커스텀 필드 셋 = 직업 · 레벨 구간 · 그때의 것(맵 · 퀘스트) — 값은 글이고 셋의 조합이 8,000을 넘으면 「Other」로 묶인다 · 퍼널은 10개까지 · 커스텀 이벤트 이름은 100개까지이고 지울 수 없다(이름을 늘리지 않는다).
--   1분에 120 + 20 x 동접 — 달돈은 갈래마다 모아 60초에 한 번(맵을 나갈 때 · 게임을 나갈 때도) 보낸다. 대시보드에는 보통 하루 뒤에 나온다(각 쪽의 View Events는 바로).
--  적지 않는 것(제 판단): 사람의 이름 · 캐릭터 이름 · 채팅 · 숫자 id를 필드에 넣지 않는다(이벤트는 로블록스가 이미 그 사람과 잇는다).
--   관리자 · 확인용 캐릭터(LuneGuest) · 봇은 적지 않는다(명예의 전당과 같다 — 개발하며 논 것이 숫자를 흐리지 않게).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage:WaitForChild("shared"):WaitForChild("lune")
local Quests = require(lune.sim.quests)
local Tutorial = require(lune.sim.tutorial)

local Analytics = {}

Analytics.FLUSH = 60 -- 달돈을 모았다가 보내는 틈(초)
Analytics.WATCH = 1 -- 캐릭터가 바뀐 것(레벨 · 차수 · 퀘스트 · 쓰러짐)을 보는 틈(초)
Analytics.KEEP = 300 -- Analytics.log에 남기는 수(시험 · Studio에서 본다)
Analytics.CURRENCY = "Money" -- 달돈(통화는 다섯 개 안 — 지금은 하나)
Analytics.LEVEL_STEPS = 100 -- 퍼널 하나는 100단계까지

-- 온보딩 퍼널의 단계(1부터 · 같은 사람이 다시 보내면 로블록스가 무시한다 — 계정에 한 번)
local ONBOARD_JOIN, ONBOARD_MADE, ONBOARD_DREAM = 1, 2, 3
local ONBOARD_MISSION0 = 3 -- 꿈의 n째 미션을 마침 = 3 + n
local ONBOARD_WOKE = ONBOARD_MISSION0 + Tutorial.TOTAL + 1
local ONBOARD_Q_ACCEPT, ONBOARD_Q_DONE = ONBOARD_WOKE + 1, ONBOARD_WOKE + 2
local ONBOARD_LV = { [5] = ONBOARD_WOKE + 3, [10] = ONBOARD_WOKE + 4 }
Analytics.ONBOARD_LAST = ONBOARD_WOKE + 4

-- 1지역 퀘스트 줄의 차례(after를 따라간다) — MainQuest 퍼널: 1 = 첫 퀘스트를 받음 · k + 1 = k째 퀘스트를 끝냄
local LINE: { any } = {}
do
	local lineDefs = {}
	for _, def in Quests.list do
		if def.line and def.region == "r1" and def.playable then
			table.insert(lineDefs, def)
		end
	end
	local byAfter = {}
	local head = nil
	for _, def in lineDefs do
		if def.after then
			byAfter[def.after] = def
		elseif not head then
			head = def
		end
	end
	local cur = head
	while cur and #LINE < #lineDefs do
		table.insert(LINE, cur)
		cur = byAfter[cur.id]
	end
end
Analytics.LINE = LINE
-- 2편의 길(2026-10-16): 큰 항구로 → 항구의 첫날 → 2편 메인 아홉 → 3차 전직 — Part2Quest 퍼널(1 = 「큰 항구로」를 받음 · k + 1 = k째를 끝냄).
--  2편의 사이드 · 도시 퀘스트는 흩어져 있어(차례가 없다) 퍼널에 넣지 않는다
local LINE2: { any } = {}
for _, id in { "cq01", "cq02", "r2m1", "r2m2", "r2m3", "r2m4", "r2m5", "r2m6", "r2m7", "r2m8", "r2m9", "job3" } do
	local def = Quests.def(id)
	if def and def.playable then
		table.insert(LINE2, def)
	end
end
Analytics.LINE2 = LINE2

-- 돈의 갈래: 어느 요청(Net 이름 · 그 일)이 바꿨는가 → 흐름 · 거래의 꼴 · 품목(itemSku)
--  거래의 꼴은 로블록스의 이름(Shop · Gameplay)을 먼저 쓰고, 경매만 제 이름(Auction — 사람끼리 오가는 돈이라 대시보드에서 따로 거른다)
local function moneyKind(name: string, action: any, gain: boolean): (string, string)
	if name == "Item" then
		if action == "buy" then
			return "Shop", "ShopBuy"
		elseif action == "sell" then
			return "Shop", "NpcSell"
		elseif action == "grow" then
			return "Shop", "BagExpand"
		elseif action == "craft" then
			return "Gameplay", "Craft"
		elseif action == "enhance" or action == "transfer" or action == "restore" then
			return "Gameplay", "Smith"
		end
	elseif name == "Market" then
		if action == "list" then
			return "Auction", if gain then "AuctionRefund" else "AuctionDeposit"
		elseif action == "buy" then
			return "Auction", if gain then "AuctionRefund" else "AuctionBuy"
		end
		return "Auction", if gain then "AuctionCollect" else "AuctionOther"
	elseif name == "Quest" then
		return "Gameplay", "QuestReward"
	elseif name == "Daily" then
		return "Gameplay", "DailyQuest"
	elseif name == "Attend" then
		return "TimedReward", "Attendance" -- 출석 보상(로블록스의 꼴 TimedReward)
	elseif name == "Achieve" then
		return "Gameplay", "Achievement"
	elseif name == "Pickup" or name == "PetPick" or name == "Skill" or name == "tick" then -- PetPick = 펫이 주운 것(2026-10-20)
		return "Gameplay", if gain then "MonsterDrop" else "Other"
	end
	return "Gameplay", "Other"
end
Analytics.moneyKind = moneyKind

-- ---------- 보내기 ----------
local service: any = nil -- AnalyticsService(게시된 게임의 서버) · false(Studio · 시험)
local function svc(): any
	if service == nil then
		local ok, studio = pcall(function()
			return RunService:IsStudio()
		end)
		if not ok or studio then
			service = false
		else
			local got, s = pcall(function()
				return game:GetService("AnalyticsService")
			end)
			service = if got and s then s else false
		end
	end
	return service
end
-- (시험) 보내는 곳을 바꾼다 — nil이면 다시 찾는다
function Analytics.setService(s: any)
	service = s
end

Analytics.log = {} :: { any }
local function remember(row)
	table.insert(Analytics.log, row)
	if #Analytics.log > Analytics.KEEP then
		table.remove(Analytics.log, 1)
	end
end

-- 커스텀 필드(값은 글 · 없는 것은 뺀다)
local function fieldsOf(f: { any }?): any
	if not f then
		return nil
	end
	local keys = { "CustomField01", "CustomField02", "CustomField03" }
	local out = {}
	local any = false
	for i, k in keys do
		local v = f[i]
		if v ~= nil and v ~= "" then
			local ok, name = pcall(function()
				return (Enum.AnalyticsCustomFieldKeys :: any)[k].Name
			end)
			out[if ok and typeof(name) == "string" then name else k] = tostring(v)
			any = true
		end
	end
	return if any then out else nil
end

local function emit(kind: string, player: any, args: { any }, f: { any }?)
	remember({ kind = kind, user = player and player.UserId, args = args, fields = f })
	local s = svc()
	if not s then
		return
	end
	local fields = fieldsOf(f)
	pcall(function()
		if kind == "onboard" then
			s:LogOnboardingFunnelStepEvent(player, args[1], args[2], fields)
		elseif kind == "funnel" then
			s:LogFunnelStepEvent(player, args[1], args[2], args[3], args[4], fields)
		elseif kind == "custom" then
			s:LogCustomEvent(player, args[1], args[2], fields)
		elseif kind == "economy" then
			local flow = if args[1] == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
			s:LogEconomyEvent(player, flow, Analytics.CURRENCY, args[2], args[3], args[4], args[5], fields)
		end
	end)
end

-- ---------- 누구를 적는가 ----------
local hooks = {
	skip = function(_s): boolean
		return false
	end,
}
-- skip(s) = 적지 않는 사람(관리자 · 확인용 · 봇) — world.luau가 준다
function Analytics.init(o: { skip: (any) -> boolean })
	hooks.skip = o.skip
end

local function tracked(s): boolean
	return s ~= nil and s.player ~= nil and not hooks.skip(s)
end

-- 레벨 구간(커스텀 필드 둘째): 1~30은 다섯씩(배우는 구간), 그 뒤는 열씩
function Analytics.band(level: number): string
	if level <= 30 then
		local lo = math.floor((level - 1) / 5) * 5 + 1
		return ("Lv%02d-%02d"):format(lo, lo + 4)
	end
	local lo = math.floor((level - 1) / 10) * 10 + 1
	return ("Lv%02d-%02d"):format(lo, lo + 9)
end

local function fieldsFor(s, ctx: string?, level: number?): { any }
	local h = s.hero
	return { h.class, Analytics.band(level or h.level), ctx }
end

local function charKey(s): string
	return ("%d-%s"):format(s.player.UserId, tostring(s.cid or "?"))
end

-- ---------- 온보딩 · 퍼널 · 커스텀 ----------
function Analytics.onboard(s, step: number, name: string)
	if not tracked(s) then
		return
	end
	s.anBoard = s.anBoard or {}
	if s.anBoard[step] then
		return -- 이 접속에서 이미 보냈다(로블록스도 두 번째는 무시하지만 한도를 쓴다)
	end
	s.anBoard[step] = true
	emit("onboard", s.player, { step, ("%02d %s"):format(step, name) }, if s.hero then fieldsFor(s) else nil)
end

function Analytics.custom(s, name: string, value: number, ctx: string?)
	if not tracked(s) or not s.hero then
		return
	end
	emit("custom", s.player, { name, value }, fieldsFor(s, ctx))
end

-- ---------- 달돈: 갈래마다 모은다 ----------
local function addMoney(s, name: string, action: any, delta: number)
	if delta == 0 or not s.anMoney then
		return
	end
	local gain = delta > 0
	local tx, sku = moneyKind(name, action, gain)
	local key = (if gain then "Source" else "Sink") .. "|" .. tx .. "|" .. sku
	s.anMoney[key] = (s.anMoney[key] or 0) + math.abs(delta)
end

-- 모은 달돈을 보낸다(갈래마다 한 번 — 잔고는 보내는 때의 것)
function Analytics.flush(s)
	if not s.anMoney or not s.hero then
		return
	end
	local keys = {}
	for k in s.anMoney do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in keys do
		local amount = s.anMoney[k]
		local flow, tx, sku = string.match(k, "^(%a+)|(%a+)|(%a+)$")
		if amount > 0 and flow then
			emit("economy", s.player, { flow, amount, math.max(0, s.hero.money), tx, sku }, fieldsFor(s))
		end
	end
	table.clear(s.anMoney)
	s.anFlushT = 0
end

-- ---------- 캐릭터가 바뀐 것을 본다 ----------
local function snapshot(h)
	local q = {}
	for id, st in h.quests do
		q[id] = if st.done then "done" else "active"
	end
	return { level = h.level, job = h.job, money = h.money, alive = h.alive, tut = h.tut.step, tutDone = h.tut.done, quests = q }
end

-- 세계에 들어왔다(캐릭터를 골랐다)
function Analytics.begin(s)
	if not tracked(s) or not s.hero then
		s.an = nil
		return
	end
	s.an = snapshot(s.hero)
	s.anMoney = {}
	s.anT, s.anFlushT = 0, 0
	if not s.hero.tut.done then
		Analytics.onboard(s, ONBOARD_DREAM, "달빛 꿈")
	end
end

-- 세계에서 나간다(캐릭터 고르기 · 게임을 나감): 모은 달돈을 보내고 그친다
function Analytics.finish(s)
	if s.an then
		Analytics.watch(s)
		Analytics.flush(s)
	end
	s.an, s.anMoney = nil, nil
end

function Analytics.watch(s)
	local was = s.an
	local h = s.hero
	if not was or not h then
		return
	end
	local key = charKey(s)
	-- 꿈(튜토리얼)의 미션
	if h.tut.step > was.tut then
		for k = was.tut, math.min(h.tut.step - 1, Tutorial.TOTAL) do
			local def = Tutorial.STEPS[k]
			Analytics.onboard(s, ONBOARD_MISSION0 + k, "꿈 " .. ((def and (def.title or def.id)) or tostring(k)))
		end
	end
	if h.tut.done and not was.tutDone then
		Analytics.onboard(s, ONBOARD_WOKE, "꿈에서 깸")
	end
	-- 레벨
	if h.level > was.level then
		for lv = was.level + 1, h.level do
			if lv <= Analytics.LEVEL_STEPS then
				emit("funnel", s.player, { "Level", key, lv, ("Lv.%d"):format(lv) }, fieldsFor(s, nil, lv))
			end
			emit("custom", s.player, { "LevelUp", math.floor((h.played or 0) / 6) / 10 }, fieldsFor(s, ("Lv%02d"):format(lv), lv))
			if ONBOARD_LV[lv] then
				Analytics.onboard(s, ONBOARD_LV[lv], ("Lv.%d"):format(lv))
			end
		end
	end
	-- 전직
	if h.job > was.job then
		for j = was.job + 1, h.job do
			emit("custom", s.player, { "JobAdvanced", h.level }, fieldsFor(s, ("job%d"):format(j)))
		end
	end
	-- 2편의 길
	for i, def in LINE2 do
		local st = h.quests[def.id]
		local now = if st then (if st.done then "done" else "active") else nil
		local before = was.quests[def.id]
		if now ~= before then
			if i == 1 and now ~= nil and before == nil then
				emit("funnel", s.player, { "Part2Quest", key, 1, ("P01 %s 받음"):format(def.name) }, fieldsFor(s, def.id))
			end
			if now == "done" then
				emit("funnel", s.player, { "Part2Quest", key, i + 1, ("P%02d %s 끝"):format(i, def.name) }, fieldsFor(s, def.id))
			end
		end
	end
	-- 퀘스트 줄
	for i, def in LINE do
		local st = h.quests[def.id]
		local now = if st then (if st.done then "done" else "active") else nil
		local before = was.quests[def.id]
		if now ~= before then
			if i == 1 and now ~= nil and before == nil then
				emit("funnel", s.player, { "MainQuest", key, 1, ("Q01 %s 받음"):format(def.name) }, fieldsFor(s, def.id))
				Analytics.onboard(s, ONBOARD_Q_ACCEPT, "첫 퀘스트 받음")
			end
			if now == "done" then
				emit("funnel", s.player, { "MainQuest", key, i + 1, ("Q%02d %s 끝"):format(i, def.name) }, fieldsFor(s, def.id))
				if i == 1 then
					Analytics.onboard(s, ONBOARD_Q_DONE, "첫 퀘스트 끝")
				end
			end
		end
	end
	-- 쓰러짐(어느 맵에서)
	if was.alive and not h.alive then
		emit("custom", s.player, { "Death", 1 }, fieldsFor(s, string.match(s.scene or "", "^(.-)#%d+$") or s.scene)) -- 따로 된 방(r1c4#57)은 그 장면의 이름으로(방마다 값이 늘지 않게 — 2026-10-21)
	end
	-- 요청 밖에서 바뀐 달돈(바닥에 떨어진 돈을 저절로 주웠다 등)
	if not s.anBusy and h.money ~= was.money then
		addMoney(s, "tick", nil, h.money - was.money)
	end
	s.an = snapshot(h)
end

-- 시계: 1초마다 보고, 60초마다 달돈을 보낸다
function Analytics.tick(s, dt: number)
	if not s.an then
		return
	end
	s.anT += dt
	s.anFlushT += dt
	if s.anT >= Analytics.WATCH then
		s.anT = 0
		Analytics.watch(s)
	end
	if s.anFlushT >= Analytics.FLUSH then
		Analytics.flush(s)
	end
end

local LOOK = { Quest = true, Tut = true, Item = true, Daily = true, Market = true, Travel = true, Return = true }
-- 요청(Net.OnServer)을 감싼다: 그 요청이 바꾼 달돈을 그 갈래에 적고, 바뀐 것을 바로 본다. 돌려주는 값은 그대로
function Analytics.wrap(name: string, fn: (...any) -> ...any, sessionOf: (any) -> any): (...any) -> ...any
	return function(player, ...)
		local s = sessionOf(player)
		local h = s and s.an and s.hero
		if not h then
			return fn(player, ...)
		end
		local action = ...
		local before = h.money
		s.anBusy = (s.anBusy or 0) + 1
		local out = table.pack(pcall(fn, player, ...)) -- 요청이 터져도 「요청 중」 표시는 걷는다(오류는 그대로 다시 던진다)
		s.anBusy = if s.anBusy and s.anBusy > 1 then s.anBusy - 1 else nil
		if s.hero == h and s.an then
			addMoney(s, name, action, h.money - before)
			s.an.money = h.money
			if LOOK[name] then
				Analytics.watch(s) -- 퀘스트 · 꿈 · 가방 · 의뢰 · 경매 · 이동은 바로 본다(싸움 · 줍기는 1초 시계가 본다 — 자주 오는 요청이라)
			end
		end
		if not out[1] then
			error(out[2], 0)
		end
		return table.unpack(out, 2, out.n)
	end
end

-- 계정에 들어옴 · 캐릭터를 만듦(온보딩의 앞 두 단계)
function Analytics.joined(s)
	Analytics.onboard(s, ONBOARD_JOIN, "접속")
end
function Analytics.made(s)
	Analytics.onboard(s, ONBOARD_MADE, "캐릭터 만듦")
end

return Analytics
