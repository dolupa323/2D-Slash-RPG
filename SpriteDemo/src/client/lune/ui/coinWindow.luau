-- 숯돌의 화로(2026-11-05 — 공방 js/lune/design/bosscoin.js · 메이플의 앱솔랩스 · 아케인셰이드 코인처럼). 화롯골의 대장장이 숯돌에게 말을 걸면 가방과 나란히 뜬다. arg = 세트("fireheart").
--  사용자: "보스잡아서 나오는 코어랑 합쳐서 코인을 만들고 그걸로 150제 장비를 구할수 있는거야 메이플 스우, 데미안, 루시드, 윌 같은 방식이다".
--  대장장이 창의 「제작」 줄과 같은 짜임(줄마다 윗줄 [그림] 이름 · [단추] / 아랫줄 [재료 그림] 이름 가진/든 수 — 모자라면 흐림 · 다 있으면 초록):
--   첫 줄 = 「화심 주화」(거인의 심장핵 1 + 거인의 불씨핵 20 → [벼리기]) · 그 아래 = 화심 세트(내 직업의 무기 · 투구 · 갑옷 · 건틀릿 · 장화 — 화심 주화 5 · 2 → [교환]) · 장비 그림을 누르면 상세 판.
--   맨 아래 = 방금 벼린 것 · 안내(Lv.150부터 · 경매장에 올릴 수 없다). 셈 = sim/bosscoin.luau · 서버 = world.luau의 Item "coinMake" · "coinBuy"(숯돌 곁에서만).
--  모양은 공방 시험 탭 js/lune/ui/paint.js의 paintCoinShop과 같다(치수 = UILAYOUT.coinshop).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local BossCoin = require(lune.sim.bosscoin)
local ItemInfo = require(lune.ui.itemInfo)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local ItemDetail = require(script.Parent.itemDetail)

local C = Ui.COLOR
local S = Layout.COINSHOP
local IC = Layout.SHOP.iconS
local TX = IC + 6
local WD = BossCoin.WORDS

local CoinWindow = {}
CoinWindow.ROWS = 6 -- 주화 한 줄 + 장비 다섯 줄(무기 · 방어구 넷)

function CoinWindow.size(): (number, number)
	return S.w, S.h
end
function CoinWindow.title(_arg: any): string?
	return WD.title
end

-- 그 장비의 상세 판(만들기 전의 것 — 「팔면 · 분해하면」은 뺀다)
function CoinWindow.info(u, me, bag)
	local item = Items.makeUnique(u.id)
	local info = ItemInfo.gear(item, { level = me.level, class = me.class, spec = me.spec, equip = bag and bag.equip }, bag and bag.equip[u.slot] or nil, false)
	local notes = {}
	for _, n in info.notes do
		if n[2] ~= "dim" then
			table.insert(notes, n)
		end
	end
	table.insert(notes, { WD.note, "dim" })
	info.notes = notes
	return info, item
end

-- 성능의 이름(「빼어난」)
local function qualityName(q: number): string
	local Q = Items.data.QUALITY[q]
	return if Q then Q.name else ""
end

-- 줄의 재료 글 「거인의 불씨핵 12/20」 · 다 있는가
local function part(bag, id: string, need: number)
	local g = Items.goods(id)
	local have = Bag.countIn(bag, id)
	return Format.fill(WD.part, { name = if g then g.name else id, have = math.min(have, 9999), need = need }), have >= need, if g then g.icon else ""
end

function CoinWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	local view = {}
	local set = BossCoin.set(arg) or BossCoin.DATA.sets[1]
	local ui = ctx.ui
	local rows = {}
	local bw = S.btnW
	local busyAt = -9
	for i = 1, CoinWindow.ROWS do
		local y = (i - 1) * S.row
		local row = {}
		row.cell = Ui.slot(body, 0, y, IC)
		row.cell.frame.Name = "Icon"
		row.icon = Ui.smallIcon(row.cell.frame, "coin", 3, 3)
		Ui.hit(row.cell.frame).Activated:Connect(function()
			local me, bag = ctx.me(), ctx.bag()
			if row.u and me then
				local info, item = CoinWindow.info(row.u, me, bag)
				ItemDetail.show("coinshop", { key = "coin:" .. row.u.id, info = info, item = item, buttons = {} })
			end
		end)
		row.name = Ui.text(body, "", TX, y + 5, w - TX - bw - 8, { font = "body" })
		row.btn = Ui.button(body, if i == 1 then WD.make else WD.buy, w - bw, y + 1, bw, function()
			-- 빨리 두 번 누르면 두 번 쓴다 — 0.8초 안의 다시 누름은 받지 않는다(대장장이의 제작과 같다)
			if os.clock() - busyAt <= 0.8 or not set then
				return
			end
			busyAt = os.clock()
			if i == 1 then
				ctx.send("Item", "coinMake", set.id, 1)
			elseif row.u then
				ctx.send("Item", "coinBuy", set.id, row.u.id)
			end
		end, { h = S.btnH })
		row.btn.frame.Name = if i == 1 then "Make" else "Buy" .. i
		row.mats = {}
		for k = 1, 2 do
			local mx = TX + (k - 1) * S.matW
			row.mats[k] = { icon = Ui.smallIcon(body, "coin", mx, y + 25), text = Ui.text(body, "", mx + 21, y + 29, S.matW - 25, { color = C.dim }) }
		end
		rows[i] = row
	end
	local ny = CoinWindow.ROWS * S.row + S.noteY
	local result = Ui.text(body, "", 0, ny, w, { color = C.accent })
	Ui.text(body, WD.note, 0, ny + 16, w, { color = C.dim, lines = 2 })

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me or not set then
			return
		end
		-- 첫 줄: 주화
		local coin = Items.goods(set.coin.id)
		local r1 = rows[1]
		Ui.setWorldIcon(r1.icon, if coin then coin.icon else "coin")
		r1.name:set(Format.fill(WD.have, { name = if coin then coin.name else "" }) .. " " .. Format.comma(Bag.countIn(bag, set.coin.id)))
		r1.name:color(C.gold)
		local okAll = true
		for k, need in { { set.core, set.coin.core }, { set.sub.id, set.coin.sub } } do
			local text, ok, icon = part(bag, need[1], need[2])
			Ui.setWorldIcon(r1.mats[k].icon, icon)
			r1.mats[k].text:set(text)
			r1.mats[k].text:color(if ok then C.green else C.dim)
			okAll = okAll and ok
		end
		r1.btn:setEnabled(okAll)
		-- 장비: 내 직업의 무기 · 방어구 넷
		local list = BossCoin.gear(set, me.class)
		for i = 2, CoinWindow.ROWS do
			local row = rows[i]
			local u = list[i - 1]
			row.u = u
			local on = u ~= nil
			row.cell.frame.Visible, row.btn.frame.Visible = on, on
			row.name:show(on)
			row.mats[1].text:show(on)
			row.mats[2].text:show(on)
			if u then
				local item = Items.makeUnique(u.id)
				Ui.setWorldIcon(row.icon, ItemCell.icon(item))
				row.name:set(u.name)
				row.name:color(ItemCell.color(item))
				local text, ok, icon = part(bag, set.coin.id, u.cost)
				Ui.setWorldIcon(row.mats[1].icon, icon)
				row.mats[1].text:set(text)
				row.mats[1].text:color(if ok then C.green else C.dim)
				Ui.setWorldIcon(row.mats[2].icon, nil)
				row.mats[2].text:set(Format.fill(WD.gearSub, { lv = u.stage, q = qualityName(u.q) }))
				row.mats[2].text:color(C.dim)
				row.btn:setEnabled(ok)
			end
		end
		local made = ui and ui.coinResult
		result:set(if made then Format.fill(WD.made, { name = made }) else "")
	end
	function view.destroy()
		ItemDetail.hide("coinshop")
		if ui then
			ui.coinResult = nil
		end
	end
	return view
end

return CoinWindow
