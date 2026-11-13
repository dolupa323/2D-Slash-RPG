-- 관리 창 — 관리자(게임의 주인)에게만 보이는 시험용 창. 「메뉴」 안의 「관리」로 연다.
--  사용자 2026-10-11: "저만 쓸수있는 어드민용 탭 만들어주세요 다른 유저들에게는 보이지않고, 어드민만 보이는 어드민관리탭 … 경험치 배율증가, 레벨 조정, 아이템발급 등등
--   여러 테스트용 편의 기능 … 누군가 해킹같은거해서 사용도 못해야하고 오직 어드민만 사용할수있어야합니다."
--  이 창은 단추를 누르면 서버에 「Admin」 패킷으로 부탁만 한다. 들어줄지는 서버가 보낸 사람의 계정 번호로 정한다(server/lune/modules/admin.luau) —
--   관리자가 아닌 사람이 이 창을 억지로 띄워 단추를 눌러도 서버는 아무 일도 하지 않는다. 그래서 창을 감추는 것(메뉴에 「관리」가 안 보인다)은 보기 좋으라고 하는 것이다.
--  탭 넷: 성장(경험치 배율 · 레벨 · 차수 · 스킬과 능력치 · 퀘스트) · 아이템(달돈 · 달가루 · 장비 한 벌 · 소비와 기타 아이템 · 경매장의 시험 물건) · 이동(맵을 골라 옮겨 간다) · 전투(체력 · 무적 · 피해 배율)
--  아래 줄에 서버의 대답이 뜬다(「Lv.30 · 1차」 · 「없는 단계다」).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local SCENES = require(lune.data["scenes.generated"])
local WORLDMAP = require(lune.data["worldmap.generated"])
local ITEMS = require(lune.data["items.generated"])
local N = require(lune.config.numbers)
local Lang = require(lune.lang)
local Format = require(lune.ui.format)
local Ui = require(script.Parent.ui)
local MACRO = require(lune.data["macro.generated"]) -- 매크로 탭의 등급 이름 · 문턱(2026-11-09)
local function MACROGRADE(score: number): string
	local G = MACRO.record.grade
	return if score >= G.severe then "severe" elseif score >= G.problem then "problem" elseif score >= G.watch then "watch" else "none"
end
local ViewOpts = require(script.Parent.Parent.viewOpts)

local C = Ui.COLOR

local AdminWindow = {}
AdminWindow.LANG_W = 60 -- 아래 줄 오른쪽의 언어 단추(2026-10-27)

-- 언어 단추의 글 = 누르면 바뀔 말(지금 한국어면 「English」 · 영문이면 「한국어」 — 「한국어」는 영문으로 바꾸지 않는다: Lang.KEEP)
function AdminWindow.langLabel(): string
	return if Lang.code == "en" then "한국어" else "English"
end

-- 한국어 ↔ English(사용자 2026-10-27: "관리탭에서 영문, 한글 바꿀수있게"): 게임 설정 창의 「언어」와 같은 값을 바꾸고 계정에 저장한다
function AdminWindow.switchLang(ctx)
	ViewOpts.lang = if Lang.code == "en" then "ko" else "en"
	ViewOpts.applyLang()
	if ctx.saveSound then
		ctx.saveSound()
	end
end
AdminWindow.W, AdminWindow.H = 480, 360 -- (356 x 300 → 480 x 360 — 2026-11-09 매크로 탭의 계정 기록 · 폰 화면 틀 768 x 432에 들어가는 만큼)
AdminWindow.TABS = { { id = "grow", name = "성장" }, { id = "item", name = "아이템" }, { id = "move", name = "이동" }, { id = "fight", name = "전투" }, { id = "acct", name = "계정" }, { id = "macro", name = "매크로" }, { id = "ban", name = "정지" }, { id = "event", name = "이벤트" }, { id = "comp", name = "뽑기 보상" } } -- 뽑기 보상 = 뽑기 겹침 보상 보내기(2026-11-10) · 계정 = 쿠폰 기록 지우기(2026-10-21) · 매크로 = 매크로 확인(2026-10-23) · 정지 = 닉네임으로 영구 정지(2026-10-26) · 이벤트 = 기간 이벤트의 사탕 지급(2026-10-29)
AdminWindow.XP = { 1, 2, 5, 10, 50, 100 } -- 경험치 배율(서버가 같은 표로 다시 본다)
AdminWindow.DMG = { 1, 5, 20, 100 } -- 피해 배율
AdminWindow.BOSS_SHOW = { 100, 75, 60, 50, 40 } -- 보스의 그림 크기 미리보기(서 있는 그림의 몇 %)
AdminWindow.LEVELS = { 10, 20, 30, 60, 100, 150 } -- 바로 가는 레벨
AdminWindow.STAGES = { 1, 10, 20, 30, 60, 100, 120, 140 } -- 한 벌을 받는 장비의 단계(120 · 140 — 2026-11-04 사용자 "100레벨장비까지밖에 못받는데?": 게임의 장비는 140단계까지)
AdminWindow.RARE = { 0, 25, 100 } -- 주간 보스의 이름 붙은 장비 확률(%) — 0 = 설계의 값(2026-10-27 사용자 "나는 이런 희귀아이템 확률조절해서 테스트할수있게해줘")
AdminWindow.rare = 1 -- 지금 고른 것(RARE의 차례 — 서버의 세션에만 걸린다: 다시 들어오면 설계의 값)
AdminWindow.CANDY_ME = { 100, 1000, 5000 } -- 이벤트 탭: 나에게 주는 사탕의 수
AdminWindow.CANDY_TO = { 10, 100, 1000 } -- 이벤트 탭: 닉네임에게 주는 사탕의 수(서버가 다시 본다 — 한 번에 9,999까지)
AdminWindow.FIX_N = { 1, 2, 3, 5, 10 } -- 보상 탭: 한 번에 보내는 겹침 보상의 횟수(서버가 다시 본다 — 1~99)
AdminWindow.fix = { name = "", box = 1, look = nil } -- 보상 탭: 적은 닉네임 · 고른 상자(차례) · 조회한 것 { head, lines }
AdminWindow.LINES = 5 -- 이동 탭의 한 쪽 = 다섯 줄(한 줄에 맵 셋 — 영문의 긴 이름이면 둘)

-- 매크로 기록의 행동 이름(2026-11-09 — sim/macro.luau Macro.act의 kind): "s:<스킬>" = 스킬의 이름 · pick 줍기 · potion 물약 · hop 문
local ACT_NAME = nil
function AdminWindow.actName(kind: string): string
	if not ACT_NAME then
		ACT_NAME = { pick = "줍기", potion = "물약", hop = "문" }
		local CL = require(lune.data["classes.generated"])
		for _, c in CL.classes do
			for _, t in c.tiers or {} do
				for _, sk in t.skills or {} do
					ACT_NAME["s:" .. sk.id] = sk.name
				end
			end
		end
	end
	return ACT_NAME[kind] or string.gsub(kind, "^s:", "")
end
-- 장면의 이름(없으면 이름표 그대로)
function AdminWindow.mapName(key: any): string
	local sc = typeof(key) == "string" and SCENES.scenes[key]
	return if sc and sc.name then sc.name else tostring(key or "-")
end
function AdminWindow.size(): (number, number)
	return AdminWindow.W, AdminWindow.H
end

-- 맵의 묶음(이동 탭): 지역마다의 장면들 — 월드맵의 지역 차례, 그 밖(실내 · 숨은 방)은 「그 밖」
function AdminWindow.places()
	local groups, seen = {}, {}
	for _, rid in WORLDMAP.order do
		local region = WORLDMAP.regions[rid]
		local list = {}
		for _, n in region.nodes do
			for _, key in n.scenes do
				if SCENES.scenes[key] and not seen[key] then
					seen[key] = true
					table.insert(list, { key = key, name = SCENES.scenes[key].name })
				end
			end
		end
		table.insert(groups, { id = rid, name = region.name, list = list })
	end
	local rest = {}
	for key, sc in SCENES.scenes do
		if not seen[key] then
			table.insert(rest, { key = key, name = sc.name })
		end
	end
	table.sort(rest, function(a, b)
		return a.key < b.key
	end)
	table.insert(groups, { id = "etc", name = "그 밖", list = rest })
	return groups
end

-- 받을 수 있는 소비 · 기타 아이템(퀘스트의 물건은 뺀다 — 그것은 「퀘스트의 할 일 채우기」로)
function AdminWindow.goods()
	local out = {}
	for _, g in ITEMS.GOODS do
		if not g.quest then
			table.insert(out, { id = g.id, name = g.short or g.name, n = if g.kind == "potion" then 50 elseif g.kind == "scroll" then 10 else 50 })
		end
	end
	return out
end

function AdminWindow.build(body: Frame, ctx, w: number, h: number)
	local view = {}
	local tab = "grow"
	local page: Frame? = nil
	local alive = true
	local quality, star = 3, 0 -- 받을 장비의 성능(1 낡은 ~ 5 빼어난) · 별
	local placeGroup, placePage = 1, 1
	local goodsPage = 1
	local macroGot = nil -- 매크로 탭: 서버가 보낸 이 서버의 사람들 · 최근 일(탭을 열 때 · 「이 서버」)
	local macroMode, macroName, macroRec, macroTop = "list", "", nil, nil -- 매크로 탭(2026-11-09): "list" 이 서버 · "top" 위험 순위 · "rec" 한 계정의 기록 · 적은 닉네임
	local macroAll, macroAllPage = nil, 1 -- 매크로 탭 「접속자」(2026-11-12): 모든 서버의 접속자(점수 높은 차례) · 쪽
	local macroAllInfo = {} :: any -- 이 서버의 판 pv · 사냥 시간 제한 hc · 가장 새 판 top(2026-11-13)
	local macroTopPage = 1 -- 매크로 탭 「모든 계정」의 쪽(2026-11-12)
	local macroTopInfo = { pages = 1, total = 0, more = false } -- 서버가 쪽마다 보낸다(2026-11-13 — 모든 계정: 쪽마다 서버에 묻는다)
	local banName, banGot = "", nil -- 정지 탭: 적은 닉네임 · 서버가 찾아 준 그 사람(계정 번호 · 로블록스 이름)
	local candyName, eventPick = "", 1 -- 이벤트 탭: 받을 사람의 닉네임 · 고른 이벤트
	local tabs = {}
	-- 탭 줄: 언어를 바꾸면 이름의 폭이 달라져 다시 놓는다
	local function layTabs()
		for _, item in tabs do
			if item.frame then
				item.frame:Destroy()
			end
		end
		table.clear(tabs)
		local tx = 0
		for _, t in AdminWindow.TABS do
			local item
			item = Ui.tab(body, t.name, tx, 0, function()
				tab = t.id
				view.draw()
			end)
			if item.frame then
				item.frame.Name = "Tab_" .. t.id -- 탭마다 이름(Play에서 가려 누를 수 있게)
			end
			tabs[t.id] = item
			tx += item.width + 16
		end
	end
	layTabs()
	Ui.line(body, 0, 20, w)
	Ui.line(body, 0, h - 20, w)
	local status = Ui.text(body, "관리자에게만 보이는 창이다", 0, h - 15, w - AdminWindow.LANG_W - 6, { color = C.dim })
	-- 언어 단추(아래 줄 오른쪽 — 어느 탭에서나): 한국어 ↔ English
	local langBtn
	langBtn = Ui.button(body, AdminWindow.langLabel(), w - AdminWindow.LANG_W, h - 18, AdminWindow.LANG_W, function()
		AdminWindow.switchLang(ctx)
		langBtn:setText(AdminWindow.langLabel())
		layTabs()
		view.draw()
	end, { h = 16, font = "small" })
	langBtn.frame.Name = "Do_lang"

	-- 서버에 부탁한다(대답이 오면 아래 줄에 적는다)
	local function ask(what: string, a: any, b: any, c: any, after: ((any) -> ())?) -- after = 대답을 받은 뒤(확성기: 보냈으면 칸을 비운다)
		status:set("…")
		status:color(C.dim)
		task.spawn(function()
			local got = ctx.admin(what, a, b, c)
			if not alive then
				return
			end
			if typeof(got) ~= "table" then
				status:set("서버가 듣지 않았다(관리자가 아니다)")
				status:color(C.red)
			else
				status:set(tostring(got.msg or ""))
				status:color(if got.ok then C.green else C.red)
			end
			if after then
				after(got)
			end
		end)
	end
	-- 「모든 계정」의 n쪽을 서버에 묻는다(2026-11-13 — 쪽마다 · 서버가 순위판을 그 쪽까지 읽는다)
	function view.topPage(n: number)
		ask("macroTop", n, nil, nil, function(got)
			if alive and typeof(got) == "table" and got.ok then
				macroTop, macroMode = got.top or {}, "top"
				macroTopPage = got.page or n
				macroTopInfo = { pages = got.pages or 1, total = got.total or #macroTop, more = got.more == true }
				if tab == "macro" then
					view.draw()
				end
			end
		end)
	end

	-- 한 줄: 왼쪽에 이름, 그 옆에 단추들. 돌려주는 것: 다음 줄의 y
	--  단추는 글이 들어가게 넓히고(영문은 길다 — 2026-10-27), 창의 폭을 넘으면 다음 줄로 넘긴다
	local function row(parent: Frame, y: number, label: string, buttons, bw: number?)
		Ui.text(parent, label, 0, y + 6, 78, { color = C.dim })
		local x = 82
		local width = bw or 40
		for _, b in buttons do
			local bwidth = math.max(b.w or width, Ui.measure(b.text) + 8)
			if x > 82 and x + bwidth > w then
				x, y = 82, y + 26
			end
			Ui.button(parent, b.text, x, y, bwidth, b.on, { h = 22, main = b.main == true }).frame.Name = "Do_" .. (b.id or b.text)
			x += bwidth + 4
		end
		return y + 28
	end

	function view.draw()
		if page then
			page:Destroy()
		end
		for id, t in tabs do
			t:setOn(id == tab)
		end
		local p = Ui.group(body, 0, 28, w, h - 52, "Page")
		page = p
		local me = ctx.me()
		local on = (me and me.admin) or { xp = 1, dmg = 1, god = false }
		local level = if me then me.level else 1
		local y = 0
		if tab == "grow" then
			local xs = {}
			for _, v in AdminWindow.XP do
				table.insert(xs, { text = "x" .. v, id = "xp" .. v, main = on.xp == v, on = function() ask("xp", v) end })
			end
			y = row(p, y, "경험치 배율", xs)
			y = row(p, y, ("레벨(지금 %d)"):format(level), {
				{ text = "-10", id = "lvm10", on = function() ask("level", math.max(1, level - 10)) end },
				{ text = "-1", id = "lvm1", on = function() ask("level", math.max(1, level - 1)) end },
				{ text = "+1", id = "lvp1", on = function() ask("level", math.min(N.LEVEL_CAP, level + 1)) end },
				{ text = "+10", id = "lvp10", on = function() ask("level", math.min(N.LEVEL_CAP, level + 10)) end },
			})
			local ls = {}
			for _, v in AdminWindow.LEVELS do
				table.insert(ls, { text = tostring(v), id = "lv" .. v, main = level == v, on = function() ask("level", v) end })
			end
			y = row(p, y, "레벨로 바로", ls)
			local js = {}
			for j = 1, 4 do
				table.insert(js, { text = j .. "차", id = "job" .. j, main = me ~= nil and me.job == j, on = function() ask("job", j) end })
			end
			y = row(p, y, "차수", js)
			y = row(p, y, "스킬", {
				{ text = "모두 마스터", id = "skmax", w = 86, on = function() ask("skills", "max") end },
				{ text = "되돌리기", id = "skreset", w = 70, on = function() ask("skills", "reset") end },
			})
			y = row(p, y, "능력치", { { text = "되돌리기", id = "streset", w = 70, on = function() ask("stats", "reset") end } })
			y = row(p, y, "퀘스트", { { text = "하는 중인 것의 할 일 채우기", id = "qfill", w = 170, on = function() ask("quests", "fill") end } })
			-- 스토리 보스 · 사당 지하를 바로 해 볼 때: 그 메인을 받은 것으로 한다(앞의 메인은 끝낸 것으로 · 레벨이 모자라면 올린다) → 「이동」 탭에서 망루 꼭대기로(「불타는 마을」은 마을의 달의 사당으로)
			y = row(p, y, "보스 퀘스트", {
				{ text = "성벽 거인", id = "qboss1", w = 76, on = function() ask("quests", "to", "r1m7") end }, -- 2026-10-15 보스의 새 이름(망루의 부관 → 성벽 거인 · 정찰대장 → 쇠사슬 간수)
				{ text = "쇠사슬 간수", id = "qboss2", w = 88, on = function() ask("quests", "to", "r1m8") end },
				{ text = "불타는 마을", id = "qcellar", w = 86, on = function() ask("quests", "to", "r1m9") end }, -- 사당 지하(달의 사당 안의 포탈로 내려간다 — 2026-10-13)
			})
			-- 문으로 들어가는 보스전(2026-10-27 그림자 사수): 보스 퀘스트를 끝낸 것으로 · 레벨 · 이번 주 기록을 지우고 그 보스의 문 앞으로
			y = row(p, y, "보스전", {
				{ text = "사수", id = "wkshadow", w = 40, on = function() ask("week", "shadowarcher") end },
				{ text = "부단장", id = "wkvice", w = 52, on = function() ask("week", "fallenknight") end }, -- 2026-10-28
				{ text = "두목", id = "wkthief", w = 40, on = function() ask("week", "thiefboss") end }, -- 2026-10-28 셋째(기믹 보스) — 셋이 한 줄에 들도록 폭은 글자에 맞춘다(넓으면 줄이 넘어 창 밖으로 나간다)
				{ text = "용암", id = "wklava", w = 40, on = function() ask("week", "lavagiant") end }, -- 2026-11-04 넷째(용암 거인 · Lv.150) — 넷이 한 줄에 들도록 넷 모두 짧게(사수 · 부단장 · 두목 · 용암)
			})
			Ui.text(p, "레벨 · 차수를 바꾸면 능력치와 스킬을 다시 찍는다.", 0, y + 4, w, { color = C.off })
		elseif tab == "item" then
			y = row(p, y, "달돈", {
				{ text = "+1만", id = "m1", w = 56, on = function() ask("money", 10000) end },
				{ text = "+100만", id = "m2", w = 64, on = function() ask("money", 1000000) end },
				{ text = "+1억", id = "m3", w = 56, on = function() ask("money", 100000000) end },
			})
			y = row(p, y, "달가루", {
				{ text = "+100", id = "d1", w = 56, on = function() ask("dust", 100) end },
				{ text = "+1만", id = "d2", w = 56, on = function() ask("dust", 10000) end },
				{ text = "+100만", id = "d3", w = 64, on = function() ask("dust", 1000000) end },
			})
			-- 장비 한 벌: 성능과 별을 고르고 단계를 누른다
			local qname = ITEMS.QUALITY[quality].name
			y = row(p, y, "장비의 성능 · 별", {
				{ text = qname, id = "q", w = 70, on = function()
					quality = quality % #ITEMS.QUALITY + 1
					view.draw()
				end },
				{ text = ("별 %d"):format(star), id = "star", w = 56, on = function()
					-- 0 → 5 → 10 → 15 → 20 → 22(가장 높은 별 — 2026-11-04 사용자 "나 장비 22성 만들수있게 해줘") → 0
					star = if star >= 22 then 0 elseif star >= 20 then 22 else star + 5
					view.draw()
				end },
			})
			local ss = {}
			for _, v in AdminWindow.STAGES do
				table.insert(ss, { text = "Lv." .. v, id = "g" .. v, w = 42, on = function() ask("gear", v, quality, star) end })
			end
			y = row(p, y, "장비 한 벌 받기", ss)
			-- 소비 · 기타 아이템: 한 쪽에 여덟(두 줄 x 넷)
			local goods = AdminWindow.goods()
			local pages = math.max(1, math.ceil(#goods / 8))
			goodsPage = math.clamp(goodsPage, 1, pages)
			Ui.text(p, ("소비 · 기타(%d/%d)"):format(goodsPage, pages), 0, y + 6, 78, { color = C.dim })
			Ui.button(p, "다음", w - 44, y, 44, function()
				goodsPage = goodsPage % pages + 1
				view.draw()
			end, { h = 22 }).frame.Name = "Do_goodsNext"
			y += 28
			for i = 1, 8 do
				local g = goods[(goodsPage - 1) * 8 + i]
				if g then
					local col, line = (i - 1) % 4, math.floor((i - 1) / 4)
					Ui.button(p, ("%s %d"):format(g.name, g.n), col * 90, y + line * 26, 86, function()
						ask("goods", g.id, g.n)
					end, { h = 22, font = "small" }).frame.Name = "Do_goods_" .. g.id
				end
			end
			-- 경매장을 혼자서 해 볼 때: 「시험 판매자」의 물건 셋(내 직업의 무기 · 모자 · 물약)을 올린다 → 은달 항구의 경매사에게서 산다. 다 보면 치운다
			row(p, y + 56, "경매장 시험", {
				{ text = "시험 물건 올리기", id = "mkfill", w = 112, on = function() ask("market", "fill") end },
				{ text = "치우기", id = "mkclear", w = 56, on = function() ask("market", "clear") end },
			})
		elseif tab == "move" then
			local groups = AdminWindow.places()
			placeGroup = math.clamp(placeGroup, 1, #groups)
			-- 지역의 단추들: 창의 폭을 넘으면 다음 줄로 넘긴다
			local gx, gy = 0, 0
			for i, g in groups do
				local bwidth = Ui.measure(g.name) + 12
				if gx + bwidth > w then
					gx, gy = 0, gy + 23
				end
				Ui.button(p, g.name, gx, gy, bwidth, function()
					placeGroup, placePage = i, 1
					view.draw()
				end, { h = 20, font = "small", main = i == placeGroup }).frame.Name = "Do_group_" .. g.id
				gx += bwidth + 3
			end
			local top = gy + 28
			local list = groups[placeGroup].list
			-- 맵 단추: 한 줄에 셋 — 이름이 단추에 들어가지 않으면(영문의 긴 이름) 둘(2026-10-27)
			local cols = 3
			for _, at in list do
				if Ui.measure(at.name) + 8 > math.floor((w - 6) / 3) then
					cols = 2
					break
				end
			end
			local bw = math.floor((w - (cols - 1) * 3) / cols)
			local per = AdminWindow.LINES * cols
			local pages = math.max(1, math.ceil(#list / per))
			placePage = math.clamp(placePage, 1, pages)
			for i = 1, per do
				local at = list[(placePage - 1) * per + i]
				if at then
					local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
					Ui.button(p, at.name, col * (bw + 3), top + line * 26, bw, function()
						ask("goto", at.key)
					end, { h = 22, font = "small" }).frame.Name = "Do_goto_" .. at.key
				end
			end
			if pages > 1 then
				Ui.text(p, ("%d / %d"):format(placePage, pages), 0, top + 5 * 26 + 6, 60, { color = C.dim })
				Ui.button(p, "다음 쪽", w - 60, top + 5 * 26, 60, function()
					placePage = placePage % pages + 1
					view.draw()
				end, { h = 22, font = "small" }).frame.Name = "Do_placeNext"
			end
		elseif tab == "macro" then
			-- 매크로(2026-10-23 매크로 확인 · 2026-11-09 계정마다의 기록 — server modules/macroGuard.luau · sim/macro.luau Macro.recordView):
			--  사용자 2026-11-09 "계정마다 종속된 로그기록이랑 점수를 내가 계속 볼수있어야해 초기화되는게아니라 … 종합점수로 쭉 내가 유저로그를 볼수있어야해 … 경고 주고 개선되는지도 파악할수있어야해"
			--  위 줄: 닉네임 → 「기록」(그 계정의 기록 — 접속하지 않았어도 저장된 것) · 「위험 순위」(모든 서버 — 종합 점수 높은 차례) · 「이 서버」(지금 이 서버의 사람들)
			local LV = { high = "의심 높음", mid = "의심 중간", low = "의심 낮음" }
			local WHAT = { issue = "문제를 받음", pass = "통과", wrong = "틀림", fail = "놓침", force = "관리자가 보냄", clear = "관리자가 풂", warn = "경고", jail = "감옥", unjail = "감옥에서 나옴" } -- (감옥 — 2026-11-11)
			local GR = MACRO.record.words.grade
			local function refresh()
				ask("macroList", nil, nil, nil, function(got)
					if alive and typeof(got) == "table" and got.ok then
						macroGot = got
						if tab == "macro" then
							view.draw()
						end
					end
				end)
			end
			local function openRec(name: string)
				ask("macroFind", name, nil, nil, function(got)
					if alive and typeof(got) == "table" and got.ok and typeof(got.record) == "table" then
						macroRec, macroMode = got.record, "rec"
						if tab == "macro" then
							view.draw()
						end
					end
				end)
			end
			-- (단추의 폭 = 글의 폭 + 10 — 영문이 길다)
			local bwFind = math.max(40, Ui.measure("기록", "small") + 10)
			local bwTop = math.max(64, Ui.measure("모든 계정", "small") + 10) -- (「위험 순위」 → 「모든 계정」 — 2026-11-12: 접속하지 않은 사람도)
			local bwHere = math.max(60, Ui.measure("이 서버", "small") + 10)
			local bwAll = math.max(60, Ui.measure("접속자", "small") + 10) -- (「모든 서버」 → 「접속자」 — 지금 모든 서버에 있는 사람)
			local xHere = w - bwHere
			local xAll = xHere - 4 - bwAll
			local xTop = xAll - 4 - bwTop
			local xFind = xTop - 4 - bwFind
			local field = Ui.field(p, 0, 0, xFind - 4, 22, "닉네임")
			field.Name = "MacroInput"
			field.Text = macroName
			field:GetPropertyChangedSignal("Text"):Connect(function()
				macroName = field.Text
			end)
			Ui.button(p, "기록", xFind, 0, bwFind, function() openRec(field.Text) end, { h = 22, font = "small", main = true }).frame.Name = "Do_macroFind"
			Ui.button(p, "모든 계정", xTop, 0, bwTop, function()
				view.topPage(1)
			end, { h = 22, font = "small" }).frame.Name = "Do_macroTop"
			Ui.button(p, "이 서버", xHere, 0, bwHere, function()
				macroMode = "list"
				refresh()
			end, { h = 22, font = "small" }).frame.Name = "Do_macroRefresh"
			-- 모든 서버의 접속자(2026-11-12 사용자: "매크로 점수 내가 같은서버인유저밖에 못봐 모든유저를 확인하고 …") — server adminCmd.luau(30초마다 서버마다 적는다)
			Ui.button(p, "접속자", xAll, 0, bwAll, function()
				ask("macroAll", nil, nil, nil, function(got)
					if alive and typeof(got) == "table" and got.ok then
						macroAll, macroAllPage, macroMode = got.all or {}, 1, "all"
						macroAllInfo = { pv = got.pv, hc = got.hc == true }
						if tab == "macro" then
							view.draw()
						end
					end
				end)
			end, { h = 22, font = "small" }).frame.Name = "Do_macroAll"
			y = 28
			local function line(text: string, color, lines: number?)
				Ui.text(p, text, 0, y, w, { color = color or C.text, lines = lines })
				y += 14 * (lines or 1)
			end
			local function md(t: number?): string -- 날짜 · 시각(KST)
				return if t then os.date("!%m-%d %H:%M", t + 9 * 3600) else "-"
			end
			if macroMode == "rec" and macroRec then
				-- 한 계정의 기록: 종합 점수 · 항목 · 날마다 · 의심 구간(언제 · 어디서 · 어떻게) · 경고(전 · 뒤)
				local r = macroRec
				local hot = r.grade == "severe" or r.grade == "problem"
				line(("%s · 종합 %d(%s) · %s"):format(tostring(r.name), r.score or 0, GR[r.grade] or "", if r.online then "이 서버에 있다" else "저장된 기록"), if hot and not r.human and r.proof ~= false then C.red else C.text)
				if r.proof == false and hot then
					line("증거 없음 — 확인을 놓친 채 사냥 · 기계 같은 키 누름이 없다: 감옥 · 의심 높음 · 자동 경고 없음(확인만 조금 자주)", C.gold) -- (2026-11-14 사용자 "지금 매크로가 아니라 애먼사람만 정지시키고있는데?")
				end
				if r.human then
					line("사람으로 봄 — 미끼 · 확인 · 룬 · 손이 깨끗하다: 감옥 · 자동 경고 없음", C.green) -- (2026-11-12 사용자 "사람다운 신호가 사람이라고 판단되면 감옥에 넣지않기로 하자")
				end
				local pt = r.parts or {}
				local bait = r.bait or { 0, 0 }
				line(("행동 %d · 미끼 %d(주움 %d/%d) · 확인 %d · 룬 %d · 손 %d"):format(pt.behave or 0, pt.bait or 0, bait[1] or 0, bait[2] or 0, pt.check or 0, pt.rune or 0, pt.input or 0), C.dim) -- (2026-11-13: 손 = 키 · 터치의 기록 · 창 밖은 점수에 넣지 않는다 — 사용자 "지금 창내림 세는것도 의미가 없고")
				-- 바로 하는 조치(2026-11-12 사용자: "즉시 경고메시지보내고 … 경험치 쿠폰도 … 제재도 즉시 … 깜빵에 바로 … 날파리를 날릴수도" · "룬의 저주 … 풀어줄수있는기능도"):
				--  어느 서버에 있든 · 접속하지 않았어도(다음에 들어올 때) — server world.luau onAdmin "macroAct" · adminCmd.luau. 정지는 정지 탭과 같은 길(바로 모든 서버에서 내보낸다)
				do
					local acts = {
						{ "경고", "warn" }, { "감옥 10분", "jail", 10 }, { "감옥 60분", "jail", 60 }, { "풀기", "unjail" }, { "날파리", "fly" }, { "날파리 거두기", "unfly" }, -- (거두기 — 2026-11-12)
						{ "저주 풀기", "uncurse" }, { "쿠폰 +1", "coupon", 1 }, { "쿠폰 +10", "coupon", 10 }, { "정지", "ban" },
					}
					local bx, by = 0, y + 2
					for i, act in acts do
						local bw = math.max(44, Ui.measure(act[1], "small") + 12)
						if bx + bw > w then
							bx, by = 0, by + 24
						end
						Ui.button(p, act[1], bx, by, bw, function()
							ask("macroAct", r.name, act[2], act[3], function(got)
								if alive and typeof(got) == "table" and got.ok and typeof(got.record) == "table" then
									macroRec = got.record
									if tab == "macro" then
										view.draw()
									end
								end
							end)
						end, { h = 22, font = "small", main = act[2] == "warn" or act[2] == "ban" }).frame.Name = "Do_macroAct" .. i
						bx += bw + 4
					end
					y = by + 26
				end
				Ui.line(p, 0, y + 1, w)
				y += 4
				for i, d in r.days or {} do
					if i > 5 then
						break
					end
					local k = tostring(d.key)
					-- 두 줄(2026-11-13): 둘째 줄 = 확인을 자리 비움으로 놓친 수(점수에 넣지 않는다) · 길 위 별똥별을 주운 수(사람의 증거가 아니다) · 키(한 프레임도 안 된 몫 · 누른 수) · 터치(같은 점의 몫 · 터치 수)
					local function pc(a: number?, b: number?): string
						return if (b or 0) > 0 then ("%d%%"):format(math.floor((a or 0) / (b :: number) * 100 + 0.5)) else "-"
					end
					line(("%s-%s · 사냥 %d분 · 행동 %d · 미끼 %d/%d · 확인 %d/%d/%d · 룬 %d분 · 재접속 %d · 점수 %d\n   자리 비움 %d · 길 위 미끼 %d · 키 %s(%d) · 터치 같은 점 %s(%d)"):format(string.sub(k, 5, 6), string.sub(k, 7, 8), d.m or 0, d.ls or 0, d.bg or 0, (d.bg or 0) + (d.bm or 0), d.ci or 0, d.cp or 0, d.cf or 0, d.rc or 0, d.rl or 0, d.score or 0,
						d.ca or 0, d.br2 or 0, pc(d.kz, d.kt), d.kt or 0, pc(d.ts, d.tt), d.tt or 0), -- 재접속 = 사냥 중에 나갔다 15분 안에 다시 들어온 수(2026-11-13)
						if (d.score or 0) >= MACRO.record.grade.problem then C.red else C.off, 2)
				end
				if #(r.days or {}) == 0 then
					line("사냥한 기록이 없다", C.off)
				end
				Ui.line(p, 0, y + 1, w)
				y += 4
				for i, e in r.eps or {} do
					if i > 2 then
						break
					end
					local how = typeof(e.how) == "table" and e.how or {}
					local parts = {}
					if typeof(how.loop) == "table" then
						local names = {}
						for kind in string.gmatch(tostring(how.loop.seq or ""), "[^|]+") do
							table.insert(names, AdminWindow.actName(kind))
						end
						table.insert(parts, ("%s · %s초 · %d바퀴 · 흔들림 %d%%"):format(table.concat(names, ">"), tostring(how.loop.lap or 0), how.loop.laps or 0, how.loop.cv or 0))
					end
					if typeof(how.route) == "table" then
						table.insert(parts, ("같은 길 %d칸 · %s초 · %d바퀴"):format(how.route.n or 0, tostring(how.route.lap or 0), how.route.laps or 0))
					end
					if how.sim then
						table.insert(parts, ("1분 되풀이 %d%%"):format(how.sim))
					end
					line(("%s ~ %s · %s · 최고 %d"):format(md(e.t0), string.sub(md(e.t1), 7), AdminWindow.mapName(e.map), e.peak or 0), C.text)
					line(if #parts > 0 then table.concat(parts, " · ") else "-", C.dim, 2)
				end
				if #(r.eps or {}) == 0 then
					line("의심 구간이 없다", C.off)
				end
				Ui.line(p, 0, y + 1, w)
				y += 4
				for i, wn in r.warns or {} do
					if i > 2 then
						break
					end
					line(("%s 경고(%s) 점수 %d · 전 %s → 뒤 %s"):format(md(wn.t), if wn.by == "admin" then "관리자" else "자동", wn.s or 0, if wn.before then tostring(wn.before) else "-", if wn.after then tostring(wn.after) else "-"), C.text)
				end
				if #(r.warns or {}) == 0 then
					line("경고한 적이 없다", C.off)
				end
			elseif macroMode == "all" and macroAll then
				-- 모든 서버의 접속자(점수 높은 차례 · 한 쪽에 PER명) — 줄을 누르면 그 계정의 기록(아래에 바로 하는 조치 단추)
				local PER = 12
				local pages = math.max(1, math.ceil(#macroAll / PER))
				macroAllPage = math.clamp(macroAllPage, 1, pages)
				line(("모든 서버의 접속자 %d명 · 종합 점수 높은 차례 · %d / %d쪽"):format(#macroAll, macroAllPage, pages), C.dim)
				-- 판(2026-11-13 사용자 "라이브버전에서 사냥시간제한 있는버전인지 없는버전인지 어떻게알아?"): 이 서버의 판 · 사냥 시간 제한 · 가장 새 판보다 옛 판인 서버에 있는 사람 수
				do
					local top, old = macroAllInfo.pv or 0, 0
					for _, r in macroAll do
						top = math.max(top, r.pv or 0)
					end
					for _, r in macroAll do
						if (r.pv or top) < top then
							old += 1
						end
					end
					line(("이 서버: 판 %d · 사냥 시간 제한 %s · 가장 새 판 %d%s"):format(macroAllInfo.pv or 0, if macroAllInfo.hc then "켜짐" else "꺼짐", top, if old > 0 then (" · 옛 판 서버에 %d명"):format(old) else ""), if old > 0 or macroAllInfo.hc then C.red else C.dim)
					macroAllInfo.top = top
				end
				for i = (macroAllPage - 1) * PER + 1, math.min(#macroAll, macroAllPage * PER) do
					local r = macroAll[i]
					local name = tostring(r.n or r.uid)
					local tags = {}
					if (r.j or 0) > 0 then
						table.insert(tags, ("감옥 %d분"):format(math.ceil(r.j / 60)))
					end
					if (r.rc or 0) > 0 then
						table.insert(tags, ("저주 %d"):format(r.rc))
					end
					if r.hu then
						table.insert(tags, "사람")
					end
					if r.here then
						table.insert(tags, "이 서버")
					end
					if r.pv and macroAllInfo.top and r.pv < macroAllInfo.top then
						table.insert(tags, ("옛 판 %d"):format(r.pv)) -- (그 서버는 다시 시작하기 전까지 옛 코드 — 2026-11-13)
					end
					local text = ("%d. %s Lv.%d · 종합 %d(%s) · %s · 채널 %d%s"):format(i, name, r.l or 0, r.s or 0, GR[r.g or "none"] or "", AdminWindow.mapName(r.m), r.ch or 1, if #tags > 0 then " · " .. table.concat(tags, " · ") else "")
					Ui.button(p, text, 0, y, w, function() openRec(name) end, { h = 16, font = "small" }).frame.Name = "Do_macroAllRow" .. i
					y += 18
				end
				if #macroAll == 0 then
					line("아무도 없다", C.off)
				end
				if pages > 1 then
					Ui.button(p, "이전", 0, y + 4, 52, function()
						macroAllPage -= 1
						view.draw()
					end, { h = 22, font = "small" }).frame.Name = "Do_macroAllPrev"
					Ui.button(p, "다음", 56, y + 4, 52, function()
						macroAllPage += 1
						view.draw()
					end, { h = 22, font = "small" }).frame.Name = "Do_macroAllNext"
				end
			elseif macroMode == "top" and macroTop then
				-- 「모든 계정」(2026-11-12 사용자: "접속자 뿐만아니라 비접속자도 내가 지표를 볼수있어야지"): 모든 계정(모든 서버 · 나간 사람도 마지막 점수) · 높은 차례 · 12명씩 쪽
				--  2026-11-13 사용자 "모든계정 누르면 왜 모든계정이 안나오고 11명만나와?": 전에는 종합 30 넘는 50명만 — 이제 모든 계정 · 쪽마다 서버에 묻는다(macroTop = 그 쪽의 줄)
				--  줄 = 순서 · 이름 · 종합(등급) · 마지막으로 적은 때 · 접속 중 · 사람으로 봄 — 누르면 그 계정의 기록(접속하지 않았어도 저장된 것 · 위에 바로 하는 조치 단추)
				local pages = macroTopInfo.pages
				line(("모든 계정 %d명%s · 접속하지 않은 사람도 · %d / %d쪽%s"):format(macroTopInfo.total, if macroTopInfo.more then " 넘게" else "", macroTopPage, pages, if macroTopInfo.more then "+" else ""), C.dim)
				for k, r in macroTop do
					local i = r.i or k
					local name = tostring(r.name)
					local tags = {}
					table.insert(tags, if r.on then "접속 중" else ("마지막 %s"):format(md(r.at)))
					if r.hu then
						table.insert(tags, "사람")
					end
					Ui.button(p, ("%d. %s · %d(%s) · %s"):format(i, name, r.score or 0, GR[MACROGRADE(r.score or 0)] or "", table.concat(tags, " · ")), 0, y, w, function() openRec(name) end, { h = 16, font = "small" }).frame.Name = "Do_macroTopRow" .. i
					y += 18
				end
				if #macroTop == 0 then
					line("아무도 없다", C.off)
				end
				if pages > 1 or macroTopInfo.more then
					Ui.button(p, "이전", 0, y + 4, 52, function()
						view.topPage(math.max(1, macroTopPage - 1))
					end, { h = 22, font = "small" }).frame.Name = "Do_macroTopPrev"
					Ui.button(p, "다음", 56, y + 4, 52, function()
						view.topPage(macroTopPage + 1)
					end, { h = 22, font = "small" }).frame.Name = "Do_macroTopNext"
				end
			else
				if not macroGot then
					refresh()
				else
					local shown = 0
					for _, r in macroGot.rows or {} do
						if shown >= 4 then
							break
						end
						shown += 1
						local state = (if (r.jail or 0) > 0 then (" · 감옥 %d분"):format(math.ceil(r.jail / 60)) else "") .. (if r.pending then " · 문제 중" elseif r.stopped then " · 보상 멈춤" else "") .. (if (r.jails or 0) > 0 then (" · 갇힘 %d번"):format(r.jails) else "") -- (감옥 — 2026-11-11: 남은 분 · 갇힌 횟수)
						local text = ("%s Lv.%d · %s · 종합 %d · 사냥 %d분 · 놓침 %d%s"):format(tostring(r.name), r.level or 0, LV[r.suspect] or "", r.total or 0, r.huntMin or 0, r.fails or 0, state)
						Ui.text(p, text, 0, y + 6, w - 148, { color = if r.suspect == "high" or r.stopped or r.grade == "severe" or (r.jail or 0) > 0 then C.red else C.text })
						local name = tostring(r.name)
						Ui.button(p, "기록", w - 146, y, 46, function() openRec(name) end, { h = 22, font = "small" }).frame.Name = "Do_macroRec" .. shown
						Ui.button(p, "보내기", w - 96, y, 46, function() ask("macroSend", r.uid, nil, nil, function() refresh() end) end, { h = 22, font = "small" }).frame.Name = "Do_macroSend" .. shown
						Ui.button(p, "풀기", w - 46, y, 46, function() ask("macroClear", r.uid, nil, nil, function() refresh() end) end, { h = 22, font = "small" }).frame.Name = "Do_macroClear" .. shown
						y += 26
						-- 행동 로그 분석의 까닭(2026-11-09 — server macroGuard.luau Guard.logView): 지금의 점수 · 1분 되풀이 · 같은 고리 · 같은 길
						local lg = r.log
						if typeof(lg) == "table" and (lg.score or 0) > 0 then
							local parts = { ("로그 %d"):format(lg.score or 0) }
							if typeof(lg.sim) == "table" then
								table.insert(parts, ("1분 되풀이 %d%%(흔들림 %d)"):format(lg.sim[1] or 0, lg.sim[2] or 0))
							end
							if typeof(lg.loop) == "table" then
								table.insert(parts, ("같은 고리 %d%% · 흔들림 %d%% · %d바퀴"):format(lg.loop[1] or 0, lg.loop[2] or 0, lg.loop[3] or 0))
							end
							if typeof(lg.route) == "table" then
								table.insert(parts, ("같은 길 %d%% · 흔들림 %d%% · %d바퀴"):format(lg.route[1] or 0, lg.route[2] or 0, lg.route[3] or 0))
							end
							Ui.text(p, table.concat(parts, " · "), 8, y - 2, w - 8, { color = if (lg.score or 0) >= 75 then C.red else C.dim })
							y += 14
						end
					end
					if shown == 0 then
						Ui.text(p, "아무도 없다", 0, y + 6, w, { color = C.off })
						y += 26
					end
					Ui.line(p, 0, y + 2, w)
					y += 8
					for i, e in macroGot.log or {} do
						if i > 3 then
							break
						end
						local ago = math.max(0, math.floor((os.time() - (e.t or 0)) / 60))
						Ui.text(p, ("%d분 전 · %s · %s%s"):format(ago, tostring(e.name), WHAT[e.what] or tostring(e.what), if e.what == "jail" and e.n then (" (%d번째 · %d분)"):format(e.n, math.ceil((e.wait or 0) / 60)) elseif e.n then (" (24시간 안 %d번째)"):format(e.n) else ""), 0, y, w, { color = C.off })
						y += 14
					end
				end
			end
		elseif tab == "ban" then
			-- 정지(2026-10-26 사용자: "클라 라는 닉네임 유저 찾아서 ip 까지 딴다음에 아예 게임못하게 정지시켜"): 닉네임을 적고 「찾기」로 누구인지 본 뒤 「정지」 —
			--  서버가 로블록스의 정지(BanAsync — 영구 · 부계정도)를 건다(server/lune/modules/ban.luau). 「풀기」 = 정지를 푼다
			Ui.text(p, "닉네임", 0, 6, 78, { color = C.dim })
			local field = Ui.field(p, 82, 0, w - 82, 22, "정지할 사람의 닉네임")
			field.Name = "BanInput"
			field.Text = banName
			field:GetPropertyChangedSignal("Text"):Connect(function()
				banName = field.Text
				if banGot and banGot.name ~= banName then
					banGot = nil -- 찾은 뒤 이름을 고쳤다: 찾은 사람을 지운다(다시 찾기)
				end
			end)
			local function act(action: string)
				local name = field.Text
				ask("ban", name, action, nil, function(got)
					if alive and typeof(got) == "table" and got.uid then
						banGot = { name = name, uid = got.uid, roblox = got.roblox, done = if got.ok and action ~= "find" then action else nil }
						if tab == "ban" then
							view.draw()
						end
					end
				end)
			end
			y = row(p, 28, "", {
				{ text = "찾기", id = "banFind", w = 56, on = function() act("find") end },
				{ text = "정지", id = "banDo", w = 56, main = true, on = function() act("ban") end },
				{ text = "풀기", id = "banUndo", w = 56, on = function() act("unban") end },
			})
			if banGot then
				Ui.text(p, ("계정 번호 %d · 로블록스 @%s"):format(banGot.uid, tostring(banGot.roblox)), 0, y + 2, w, { color = C.text }).label.Frame.Name = "BanWho" -- (Ui.text에는 .frame이 없다 — 2026-10-26 능력치 창)
				if banGot.done then
					Ui.text(p, if banGot.done == "ban" then "영구 정지됨" else "정지 풀림", 0, y + 16, w, { color = if banGot.done == "ban" then C.red else C.green })
				end
			end
			y += 36
			Ui.text(p, "닉네임의 계정을 이 게임에서 영구 정지한다.", 0, y, w, { color = C.off })
			Ui.text(p, "접속 중이면 바로 쫓겨나고 다시 못 들어온다.", 0, y + 14, w, { color = C.off })
			Ui.text(p, "로블록스가 같은 사람의 부계정으로 보는 계정도 막는다.", 0, y + 28, w, { color = C.off })
			Ui.text(p, "IP는 로블록스가 주지 않아 쓰지 않는다.", 0, y + 42, w, { color = C.off })
			Ui.text(p, "풀기 = 정지를 푼다 · 관리자는 정지할 수 없다.", 0, y + 56, w, { color = C.off })
		elseif tab == "event" then
			-- 기간 이벤트의 사탕(2026-10-29 사용자: "나 어드민 호박사탕 지급 탭 만들어주고"): 나에게 · 닉네임에게 — 서버가 이 서버에 있으면 바로 · 다른 서버에 있으면 곧 ·
			--  접속하지 않았으면 다음에 그 캐릭터로 들어올 때(server/lune/modules/gifts.luau). 이벤트가 닫혀 있어도 준다(상점은 기간에만 열린다)
			local EventMod = require(lune.sim.event)
			local evs = EventMod.DATA.list
			eventPick = math.clamp(eventPick, 1, math.max(1, #evs))
			local e = evs[eventPick]
			if not e then
				Ui.text(p, "이벤트가 없다", 0, 6, w, { color = C.off })
				return
			end
			local evButtons = {}
			for i, q in evs do
				table.insert(evButtons, { text = q.name, id = "ev_" .. q.id, w = 80, main = i == eventPick, on = function()
					eventPick = i
					view.draw()
				end })
			end
			y = row(p, y, "이벤트", evButtons)
			local candyShown = e.candy.id
			for _, g in ITEMS.GOODS do
				if g.id == e.candy.id then
					candyShown = g.name
				end
			end
			local open = EventMod.on(e.id)
			Ui.text(p, ("%s · %s"):format(candyShown, if open then "지금 열림" else "지금 닫힘"), 82, y - 2, w - 82, { color = if open then C.green else C.off })
			y += 18
			local mine = {}
			for _, n in AdminWindow.CANDY_ME do
				table.insert(mine, { text = "+" .. Format.comma(n), id = "candyMe" .. n, w = 52, on = function() ask("candy", e.id, "", n) end })
			end
			table.insert(mine, { text = "모두 빼기", id = "candyClear", w = 64, on = function() ask("candyClear", e.id) end })
			y = row(p, y, "나에게", mine)
			Ui.text(p, "닉네임", 0, y + 6, 78, { color = C.dim })
			local field = Ui.field(p, 82, y, w - 82, 22, "받을 사람의 닉네임")
			field.Name = "CandyInput"
			field.Text = candyName
			field:GetPropertyChangedSignal("Text"):Connect(function()
				candyName = field.Text
			end)
			y += 28
			local to = {}
			for _, n in AdminWindow.CANDY_TO do
				table.insert(to, { text = "+" .. Format.comma(n), id = "candyTo" .. n, w = 52, on = function() ask("candy", e.id, field.Text, n) end })
			end
			y = row(p, y, "닉네임에게", to)
			Ui.text(p, "이 서버에 있으면 바로 · 다른 서버에 있으면 곧 받는다.", 0, y + 4, w, { color = C.off })
			Ui.text(p, "접속하지 않았으면 다음에 그 캐릭터로 들어올 때 받는다.", 0, y + 18, w, { color = C.off })
			Ui.text(p, "받는 사람의 화면 위에 「운영자의 선물」 알림이 뜬다.", 0, y + 32, w, { color = C.off })
		elseif tab == "comp" then
			-- 겹침 보상 보내기(2026-11-10 사용자: "이미 샀는데 증발된사람들한테 소급적용 해줘야해 이미 날아간사람은 사기를당한거잖아 돈관련된건 철저하게해야해"):
			--  뽑기 상자에서 가진 것이 나와 윤슬 조각으로 바뀌었던 사람(S386 ~ S393)에게 — 무엇이 겹쳤는지는 저장되지 않아, 받은 사람이 그 상자에서 나온 가진 것을 골라 하나 더 받는다
			--  (서버 world.luau onAdmin "dupfix" → 달빛 상점 선물 상자 → sim/cash.luau dupfix · 가방 「캐시」 탭의 「겹침 보상 받기」)
			local BMD = require(lune.data["bm.generated"])
			local Gacha = require(lune.sim.gacha)
			local boxes = {}
			for _, pr in BMD.products do
				if Gacha.box(pr.id) then
					table.insert(boxes, pr)
				end
			end
			local F = AdminWindow.fix
			F.box = math.clamp(F.box, 1, math.max(1, #boxes))
			local boxButtons = {}
			for i, pr in boxes do
				table.insert(boxButtons, { text = pr.name, id = "fixBox_" .. pr.id, w = 80, main = i == F.box, on = function()
					F.box = i
					view.draw()
				end })
			end
			y = row(p, y, "상자", boxButtons)
			Ui.text(p, "닉네임", 0, y + 6, 78, { color = C.dim })
			local field = Ui.field(p, 82, y, w - 82, 22, "받을 사람의 닉네임(비우면 나)")
			field.Name = "FixInput"
			field.Text = F.name
			field:GetPropertyChangedSignal("Text"):Connect(function()
				F.name = field.Text
			end)
			y += 28
			local sendButtons = {}
			for _, n in AdminWindow.FIX_N do
				table.insert(sendButtons, { text = ("%d번"):format(n), id = "fixSend" .. n, w = 44, on = function()
					local pr = boxes[F.box]
					if pr then
						ask("dupfix", pr.id, field.Text, n)
					end
				end })
			end
			y = row(p, y, "보내기", sendButtons)
			-- 조회(2026-11-10 사용자 "정확히 파악해야 내가 보상을하지"): 그 닉네임의 상자마다 산 수(로블록스 판매 기록) · 가진 수 · 사라진 수 · 준 수 — 서버가 셈만 한다
			y = row(p, y, "조회", { { text = "바로잡기 보기", id = "fixLook", w = 100, on = function()
				ask("dupfixLook", field.Text, nil, nil, function(got)
					if alive and typeof(got) == "table" then
						F.look = { head = tostring(got.msg or ""), lines = if typeof(got.lines) == "table" then got.lines else {} }
						if tab == "comp" then
							view.draw()
						end
					end
				end)
			end } })
			if F.look then
				Ui.text(p, F.look.head, 0, y, w, { color = C.text })
				y += 14
				for i, line in F.look.lines do
					if i > 6 then
						break -- (상자는 다섯 + 남은 것 한 줄)
					end
					Ui.text(p, line, 0, y, w, { color = C.green })
					y += 14
				end
				y += 4
			end
			Ui.text(p, "상자를 산 사람: 들어오면 저절로 받은 것을 거두고 안 연 상자(산 수 + 3) · 선택 상자.", 0, y, w, { color = C.off })
			Ui.text(p, "보내기 = 그 사람의 「보관함」에 그 상자의 선택 상자(하나를 골라 받는다).", 0, y + 14, w, { color = C.off })
		elseif tab == "acct" then
			-- 쿠폰 기록 지우기(2026-10-21 사용자: "쿠폰 기록을 초기화해줘 쿠폰등록하는것부터 영상을찍어야해") — 내 계정의 쓴 쿠폰 · 쿠폰 펫 · 쿠폰 탈것을 지운다(서버의 CashServer.resetCoupons)
			y = row(p, y, "쿠폰", { { text = "쓴 기록 지우기", id = "couponReset", w = 110, on = function() ask("coupons") end } })
			Ui.text(p, "쓴 쿠폰 기록과 쿠폰으로 받은 펫을 지운다.", 0, y + 4, w, { color = C.off })
			Ui.text(p, "쿠폰을 처음 넣는 것부터 다시 해 볼 때 — 메뉴 → 「쿠폰」.", 0, y + 18, w, { color = C.off })
			y += 44
			-- 확성기(2026-10-21 사용자: "모든 서버에 확성기로 말할수있나? 어드민기능으로 확성기같은게 필요한데"): 적고 「보내기」(또는 Enter) → 모든 서버의 모두에게
			--  화면 위 큰 알림 「공지」 + 채팅 알림 글(서버가 글을 거른 뒤 — server/lune/modules/megaphone.luau · 80자까지 · 5초에 한 번)
			Ui.text(p, "확성기", 0, y + 6, 78, { color = C.dim })
			local SENDW = 64
			local field = Ui.field(p, 82, y, w - 82 - SENDW - 4, 22, "모든 서버에 보낼 글(80자까지)")
			field.Name = "MegaphoneInput"
			local function send()
				ask("megaphone", field.Text, nil, nil, function(got)
					if typeof(got) == "table" and got.ok then
						field.Text = "" -- 보냈으면 비운다(못 보냈으면 적은 글을 그대로 둔다)
					end
				end)
			end
			Ui.button(p, "보내기", w - SENDW, y, SENDW, send, { h = 22, main = true }).frame.Name = "Do_megaphone"
			field.FocusLost:Connect(function(enter: boolean)
				if enter then
					send()
				end
			end)
			Ui.text(p, "지금 돌아가는 모든 서버의 모두에게 — 화면 위 큰 알림 「공지」 + 채팅.", 0, y + 28, w, { color = C.off })
			y += 48
			-- 칭호 넣어 보기(2026-10-26 사용자: "나 어드민으로 껴볼수있게 해야지 난디자인을 봐야하는데"): 칭호마다 단추 하나(받고 바로 단다) · 「빼기」 = 모두 뺀다. 이 캐릭터에만(세계 기록은 그대로)
			local TitlesMod = require(game:GetService("ReplicatedStorage").shared.lune.sim.titles)
			-- 칭호가 셋(운영자 · 최초의 계승자 · 만월의 계승자)이라 한 줄에 칭호만 · 「빼기」는 다음 줄(운영자 칭호는 관리자에게 늘 있어 빼기 = 떼기만)
			-- 2026-10-27: 직업마다의 「가장 앞선 자」 다섯이 더해져 단추가 여덟이 되자 줄이 셋으로 접혀 아래 「순위 사슴」이 창 밖으로 밀렸다(시험 30)
			--   → 직업 칭호 다섯은 단추 하나(누를 때마다 다음 직업의 것을 받아 단다 — 색을 차례로 본다) · 「모두 빼기」도 같은 줄에
			local list, firsts = {}, {}
			for _, t in TitlesMod.LIST do
				if t.rule == "classFirst" then
					table.insert(firsts, t)
				else
					table.insert(list, { text = t.name, id = "title_" .. t.id, w = 80, on = function() ask("title", t.id) end })
				end
			end
			if #firsts > 0 then
				table.insert(list, { text = firsts[1].name .. " ▸", id = "titleClass", w = 80, on = function()
					AdminWindow.classTitle = (AdminWindow.classTitle or 0) % #firsts + 1
					ask("title", firsts[AdminWindow.classTitle].id)
				end })
			end
			table.insert(list, { text = "모두 빼기", id = "titleOff", w = 64, on = function() ask("title", "") end })
			y = row(p, y, "칭호", list)
			-- 순위 사슴(2026-10-26 사용자: "1위는 금은동 다주고 … 그리고 나도 볼수있어야지"): 백금 · 실버 · 동색 사슴을 내 계정에 넣는다 · 뺀다(가방 「캐시」 탭에서 탄다)
			y = row(p, y, "순위 사슴", {
				{ text = "셋 받기", id = "rankMountsGive", w = 64, on = function() ask("rankMounts", "give") end },
				{ text = "빼기", id = "rankMountsTake", w = 48, on = function() ask("rankMounts", "take") end },
			})
			Ui.text(p, "칭호 · 순위 사슴을 내 것에 넣어 모습을 본다(사슴은 가방 「캐시」 탭).", 0, y + 4, w, { color = C.off })
		else
			y = row(p, y, "체력", { { text = "가득 채우기(쓰러졌으면 일어난다)", id = "heal", w = 200, on = function() ask("heal") end } })
			y = row(p, y, "무적", {
				{ text = "켜기", id = "godOn", w = 56, main = on.god == true, on = function() ask("god", true) end },
				{ text = "끄기", id = "godOff", w = 56, main = on.god ~= true, on = function() ask("god", false) end },
			})
			local ds = {}
			for _, v in AdminWindow.DMG do
				table.insert(ds, { text = "x" .. v, id = "dmg" .. v, main = on.dmg == v, on = function() ask("dmg", v) end })
			end
			y = row(p, y, "피해 배율", ds)
			-- 희귀 장신구(2026-10-27): 확률 = 누를 때마다 설계의 값(2%) → 25% → 100% — 내가 든 파티의 격파에만(다른 사람의 격파에는 걸리지 않는다) · 흑수정 마안을 가방에 바로
			local rp = AdminWindow.RARE[AdminWindow.rare]
			y = row(p, y, "희귀 장신구", {
				{ text = if rp == 0 then "확률 기본" else ("확률 %d%%"):format(rp), id = "rare", w = 82, main = rp ~= 0, on = function()
					AdminWindow.rare = AdminWindow.rare % #AdminWindow.RARE + 1
					ask("rare", AdminWindow.RARE[AdminWindow.rare])
				end },
				-- (보스마다 하나 — 2026-10-29 불씨 도둑 두목의 허리띠를 더하며 이름을 짧게: 창의 높이가 정해져 있어 줄이 늘지 않게)
				{ text = "마안 받기", id = "unique", w = 76, on = function() ask("unique", "archer_eye") end }, -- 흑수정 마안(그림자 사수 · 하드)
				{ text = "견장 받기", id = "unique2", w = 76, on = function() ask("unique", "vice_pauldron") end }, -- 검은 맹세 견장(타락한 부단장 · 하드 — 2026-10-28)
				{ text = "허리띠 받기", id = "unique3", w = 84, on = function() ask("unique", "thief_belt") end }, -- 잿불 도적의 허리띠(불씨 도둑 두목 · 하드 — 2026-10-29)
			})
			-- 잠수 방지 날파리(2026-10-28): 2분 기다리지 않고 지금 나에게 부른다(사냥터에서만 — 무적이면 찔려도 피해가 없다)
			y = row(p, y, "날파리", { { text = "지금 부르기", id = "fly", w = 96, on = function() ask("fly") end } })
			-- 보상의 방(2026-10-28): 보스를 잡지 않고 상자를 열어 본다(나 혼자 · 이번 주의 격파를 적지 않는다)
			y = row(p, y, "보상의 방", {
				{ text = "노말", id = "boxN", w = 56, on = function() ask("box", "normal") end },
				{ text = "하드", id = "boxH", w = 56, on = function() ask("box", "hard") end },
			})
			-- 보스의 그림 크기 미리보기(화면 쪽만 — 서버에 묻지 않는다): 받은 동작 그림을 작게 그릴수록 또렷하다. 고른 크기를 알려 주면 설계값(공방 bosses.js의 BOSS_SHOW)으로 굳힌다
			local now = ctx.bossShow and ctx.bossShow() -- 고운 그림이 없으면 nil(이 줄을 그리지 않는다)
			if now then
				local bs = {}
				for _, v in AdminWindow.BOSS_SHOW do
					table.insert(bs, { text = v .. "%", id = "boss" .. v, w = 44, main = now == v, on = function()
						ctx.bossShow(v)
						view.draw()
					end })
				end
				y = row(p, y, "보스 크기", bs)
			end
			Ui.text(p, "배율과 무적은 저장되지 않는다(다시 들어오면 꺼져 있다).", 0, y + 4, w, { color = C.off })
			Ui.text(p, "피해 배율은 보이는 전투력과 순위를 바꾸지 않는다.", 0, y + 18, w, { color = C.off })
			if now then
				Ui.text(p, "보스 크기는 그림만 바꿔 본다(맞는 자리는 그대로).", 0, y + 32, w, { color = C.off })
			end
		end
	end

	-- 내 상태가 오면(레벨 · 배율이 바뀌었다) 다시 그린다
	local last = ""
	function view.refresh(me)
		local a = (me and me.admin) or {}
		local sig = table.concat({ tostring(me and me.level), tostring(me and me.job), tostring(a.xp), tostring(a.dmg), tostring(a.god) }, "|")
		if sig ~= last then
			last = sig
			view.draw()
		end
	end

	function view.destroy()
		alive = false
		if page then
			page:Destroy()
			page = nil
		end
	end
	view.refresh(ctx.me())
	return view
end

return AdminWindow
