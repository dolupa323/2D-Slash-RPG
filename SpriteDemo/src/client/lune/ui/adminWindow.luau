-- 관리 창 — 관리자(게임의 주인)에게만 보이는 시험용 창. 「메뉴」 안의 「관리」로 연다.
--  사용자 2026-10-11: "저만 쓸수있는 어드민용 탭 만들어주세요 다른 유저들에게는 보이지않고, 어드민만 보이는 어드민관리탭 … 경험치 배율증가, 레벨 조정, 아이템발급 등등
--   여러 테스트용 편의 기능 … 누군가 해킹같은거해서 사용도 못해야하고 오직 어드민만 사용할수있어야합니다."
--  이 창은 단추를 누르면 서버에 「Admin」 패킷으로 부탁만 한다. 들어줄지는 서버가 보낸 사람의 계정 번호로 정한다(server/lune/modules/admin.luau) —
--   관리자가 아닌 사람이 이 창을 억지로 띄워 단추를 눌러도 서버는 아무 일도 하지 않는다. 그래서 창을 감추는 것(메뉴에 「관리」가 안 보인다)은 보기 좋으라고 하는 것이다.
--  탭 넷: 성장(경험치 배율 · 레벨 · 차수 · 스킬과 능력치 · 퀘스트) · 아이템(달돈 · 달가루 · 장비 한 벌 · 소비와 기타 아이템) · 이동(맵을 골라 옮겨 간다) · 전투(체력 · 무적 · 피해 배율)
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
AdminWindow.TABS = { { id = "grow", name = "성장" }, { id = "item", name = "아이템" }, { id = "move", name = "이동" }, { id = "fight", name = "전투" } }
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
	local function ask(what: string, a: any, b: any, c: any)
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
				{ text = "망루의 부관", id = "qboss1", w = 88, on = function() ask("quests", "to", "r1m7") end },
				{ text = "정찰대장", id = "qboss2", w = 72, on = function() ask("quests", "to", "r1m8") end },
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
