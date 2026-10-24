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
local Ui = require(script.Parent.ui)

local C = Ui.COLOR

local AdminWindow = {}
AdminWindow.W, AdminWindow.H = 356, 300
AdminWindow.TABS = { { id = "grow", name = "성장" }, { id = "item", name = "아이템" }, { id = "move", name = "이동" }, { id = "fight", name = "전투" }, { id = "acct", name = "계정" }, { id = "macro", name = "매크로" } } -- 계정 = 쿠폰 기록 지우기(2026-10-21) · 매크로 = 매크로 확인(2026-10-23)
AdminWindow.XP = { 1, 2, 5, 10, 50, 100 } -- 경험치 배율(서버가 같은 표로 다시 본다)
AdminWindow.DMG = { 1, 5, 20, 100 } -- 피해 배율
AdminWindow.BOSS_SHOW = { 100, 75, 60, 50, 40 } -- 보스의 그림 크기 미리보기(서 있는 그림의 몇 %)
AdminWindow.LEVELS = { 10, 20, 30, 60, 100, 150 } -- 바로 가는 레벨
AdminWindow.STAGES = { 1, 10, 20, 30, 60, 100 } -- 한 벌을 받는 장비의 단계
AdminWindow.PER_PAGE = 15 -- 이동 탭의 한 쪽(세 줄 x 다섯)

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
	local macroGot = nil -- 매크로 탭: 서버가 보낸 이 서버의 사람들 · 최근 일(탭을 열 때 · 「새로 고침」)
	local tabs = {}
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
	Ui.line(body, 0, 20, w)
	Ui.line(body, 0, h - 20, w)
	local status = Ui.text(body, "관리자에게만 보이는 창이다", 0, h - 15, w, { color = C.dim })

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

	-- 한 줄: 왼쪽에 이름, 그 옆에 단추들. 돌려주는 것: 다음 줄의 y
	local function row(parent: Frame, y: number, label: string, buttons, bw: number?)
		Ui.text(parent, label, 0, y + 6, 78, { color = C.dim })
		local x = 82
		local width = bw or 40
		for _, b in buttons do
			local bwidth = b.w or width
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
				{ text = "+1", id = "lvp1", on = function() ask("level", math.min(N.MAX_LEVEL, level + 1)) end },
				{ text = "+10", id = "lvp10", on = function() ask("level", math.min(N.MAX_LEVEL, level + 10)) end },
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
					star = if star >= 20 then 0 else star + 5
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
			local per = AdminWindow.PER_PAGE
			local pages = math.max(1, math.ceil(#list / per))
			placePage = math.clamp(placePage, 1, pages)
			for i = 1, per do
				local at = list[(placePage - 1) * per + i]
				if at then
					local col, line = (i - 1) % 3, math.floor((i - 1) / 3)
					Ui.button(p, at.name, col * 119, top + line * 26, 116, function()
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
			-- 매크로 확인(2026-10-23 — server modules/macroGuard.luau): 이 서버의 사람들(의심이 높은 차례) · 그 사람에게 지금 문제 보내기 · 보상 멈춤 풀기 · 최근 일
			local LV = { high = "의심 높음", mid = "의심 중간", low = "의심 낮음" }
			local WHAT = { issue = "문제를 받음", pass = "통과", wrong = "틀림", fail = "놓침", force = "관리자가 보냄", clear = "관리자가 풂" }
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
			Ui.button(p, "새로 고침", w - 76, 0, 76, refresh, { h = 22, font = "small" }).frame.Name = "Do_macroRefresh"
			Ui.text(p, "이 서버의 사람들 · 놓치면 사냥 보상 멈춤(정지는 하지 않는다)", 0, 6, w - 84, { color = C.dim })
			y = 28
			if not macroGot then
				refresh()
			else
				local shown = 0
				for _, r in macroGot.rows or {} do
					if shown >= 5 then
						break
					end
					shown += 1
					local state = if r.pending then " · 문제 중" elseif r.stopped then " · 보상 멈춤" else ""
					local line = ("%s Lv.%d · %s · 사냥 %d분 · 놓침 %d%s"):format(tostring(r.name), r.level or 0, LV[r.suspect] or "", r.huntMin or 0, r.fails or 0, state)
					Ui.text(p, line, 0, y + 6, w - 100, { color = if r.suspect == "high" or r.stopped then C.red else C.text })
					Ui.button(p, "보내기", w - 96, y, 46, function() ask("macroSend", r.uid, nil, nil, function() refresh() end) end, { h = 22, font = "small" }).frame.Name = "Do_macroSend" .. shown
					Ui.button(p, "풀기", w - 46, y, 46, function() ask("macroClear", r.uid, nil, nil, function() refresh() end) end, { h = 22, font = "small" }).frame.Name = "Do_macroClear" .. shown
					y += 26
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
					Ui.text(p, ("%d분 전 · %s · %s%s"):format(ago, tostring(e.name), WHAT[e.what] or tostring(e.what), if e.n then (" (24시간 안 %d번째)"):format(e.n) else ""), 0, y, w, { color = C.off })
					y += 14
				end
			end
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
