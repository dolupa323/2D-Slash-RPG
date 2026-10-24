-- 가방 창 — 화면 오른쪽의 옆 판. 탭 셋(장비 · 소비 · 기타), 세 탭 모두 칸 여섯 x 넷이 보인다(늘리면 48칸까지 — 칸들이 위아래로 스크롤된다).
--  2026-10-15 사용자: "인벤토리 위아래 버튼으로 움직이는게아니라 스크롤이어야합니다. 모바일에서도 정상작동하게"
--   → ▲▼로 한 줄씩 넘기던 것을 없애고 칸들을 스크롤 틀(ScrollingFrame — 마우스 휠 · 손가락으로 밀기)에 넣었다. 오른쪽 끝에 가는 민트 막대.
--   스마트폰: 칸 위를 그냥 밀면 스크롤, 칸을 잠깐(HOLD초) 누르고 있다가 밀면 아이템을 끈다(끄는 동안은 스크롤이 서 있다). PC는 휠로 스크롤하고 끌기는 그대로.
--  사용자 2026-10-08: "지금 인벤토리 구조도 잘못되어있는데 … 품목이 고정되어있고 거기서 수량 1/8 이런식으로 표기하는게 인벤토리가 아닙니다."
--  → 가방은 탭마다 진짜 칸이다(공방 js/lune/design/items.js의 BAGPLAY — 셈은 shared/lune/sim/bag.luau):
--   · 칸에는 장비 하나 또는 소비 · 기타 아이템의 묶음(그림과 오른쪽 아래의 수)이 놓인다. 빈 칸은 비어 있고, 놓인 자리는 내가 옮기기 전까지 그대로다.
--   · 칸을 누르면 그 아이템의 상세가 창 옆의 작은 판에 뜬다(ui/itemDetail.luau) — 할 수 있는 일의 단추가 거기 있다:
--     장착 · 분해 / 사용 · 퀵슬롯 · 버리기 · 나누기 / (창고지기 앞) 맡기기 · (상점 앞) 팔기 · (대장장이의 강화 창) 강화.
--     "장비 탭에서 각각의 장비를 선택하면 … 작은모달이 떠서 아이템 스펙이 나와야합니다. 인벤토리에서 선택도 마찬가지입니다. 기타아이템, 소비아이템 모두 마찬가지입니다."
--   · 칸의 것을 끌어 다른 칸에 놓으면 옮겨진다(다른 것이 있으면 자리를 바꾸고, 같은 묶음이면 합친다). 소비 아이템은 끌어 퀵슬롯(스마트폰: 칸 단추)에 놓는다.
--   · 끌어서 창고 창에 놓으면 맡겨지고(놓은 칸에 — 묶음은 전부), 상점 창에 놓으면 팔지 묻는다
--     (사용자 2026-10-08: "소비, 기타아이템도 창고에 맡길수있어야하고, 상점에 팔기 가능해야하고 묶음나누기 가능해야하고 창고에 드래그앤 드랍으로 맡기기가능해야합니다").
--   · 같은 칸을 두 번 누르면 장비는 장착, 소비 아이템은 사용. 「정렬」은 그 탭을 앞에서부터 채운다.
--  달돈 · 달가루 · 정수는 칸을 차지하지 않는다 — 창 아래에 그림과 숫자로(공방 「돈 · 상점」 탭의 가방 규칙).
--  PC · 스마트폰이 같은 창이다: 누르기 = 톡, 끌기 = 누른 채 움직이기, 두 번 누르기 = 톡톡.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local Format = require(lune.ui.format)
local ItemInfo = require(lune.ui.itemInfo)
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local WORDS = require(lune.data["ui.generated"]).words -- 낱말(장착 · 정렬 …) — 공방에서 정한 것
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local ItemDetail = require(script.Parent.itemDetail)
local Windows = require(script.Parent.windows)
local CountBox = require(script.Parent.countBox) -- 수량 창(2026-10-21)
local CountPick = require(lune.ui.countPick)
local BMW = require(lune.data["bm.generated"]).shop.words -- 캐시 탭의 글(2026-10-21)

local C = Ui.COLOR
local D = Items.data
local BAG = Layout.BAG
local COLS, ROWS = BAG.cols, BAG.rows
local GRID_Y = BAG.gridY -- 칸들의 윗줄
local KEYS = table.clone(D.BAG.keys) -- 탭의 이름표("gear" · "use" · "etc") + 넷째 "cash"(아래)
-- 캐시 탭(2026-10-21 사용자 "인벤토리 가방에 캐시 탭을 넣던지 방법을 고안해서 펫을꺼내거나 넣는것, 라이딩을 타거나 내리는것 다 가능해야하고"):
--  계정이 가진 펫 · 탈것이 칸에 놓인다(가방의 칸을 차지하지 않는다 — 서버의 상점 상태 Cash.view의 pets · mounts). 꺼내 둔 펫 · 타는 탈것은 칸의 오른쪽 아래에 민트 점.
--  누르면 상세 판에 「꺼내기 · 넣기」 / 「타기 · 내리기」 · 「퀵슬롯」 · 두 번 누르면 바로 · 끌어서 퀵슬롯에 놓으면 그 키로(boot의 state.togglePet · toggleRide)
table.insert(KEYS, "cash")
local TABNAMES = table.clone(D.BAG.tabs)
table.insert(TABNAMES, BMW.bagTab)
local DOUBLE = 0.4 -- 이 안에 같은 칸을 다시 누르면 두 번 누른 것(초)
local HOLD = 0.3 -- 스마트폰: 칸을 이만큼(초) 누르고 있다가 밀어야 아이템을 끈다(그 전에 밀면 스크롤)
local BAR = 3 -- 스크롤 막대의 두께(화면 틀의 점 — 칸의 오른쪽 끝에 겹친다)

local BagWindow = { side = "right" } -- 가방은 늘 오른쪽에 뜬다(같이 열린 창은 왼쪽으로 간다)
BagWindow.COLS, BagWindow.ROWS = COLS, ROWS

function BagWindow.size(): (number, number)
	return Layout.bagBody(Stage.ratio)
end

-- 가방을 늘리는 단추의 글
function BagWindow.growText(cost: number): string
	return ("+%d칸 %s"):format(D.BAG.step, Format.short(cost))
end

-- 그 장비를 지금 낄 수 있는가(화면의 단추를 켜고 끄는 데 쓴다 — 서버가 다시 본다)
function BagWindow.canWear(me, it): boolean
	return not it.broken and (it.slot ~= "weapon" or it.who == me.class) and me.level >= Items.needLevel(it)
end

-- 지금 낀 것보다 좋은 장비인가(2026-10-18 — 칸의 왼쪽 위에 초록 ▲): 장착할 수 있고, 장착하면 전투력이 오른다(상세 판의 「장착하면 전투력 +n」과 같은 셈)
function BagWindow.better(me, bag, it): boolean
	if not it or it.item or typeof(it.stage) ~= "number" or typeof(it.q) ~= "number" or typeof(it.star) ~= "number" or not BagWindow.canWear(me, it) then
		return false -- (장비의 꼴이 다 갖춰지지 않은 것 — 셈하지 않는다)
	end
	return ItemInfo.wearDiff(it, (bag.equip or {})[it.slot], me.spec or ItemInfo.refSpec(me.level or 1)) > 0 -- (장착한 것의 표가 없으면 빈 몸으로 셈한다)
end

-- 그림과 숫자(달돈 · 달가루 · 정수). (x, y) = 그림의 왼쪽 위 — 숫자는 그 오른쪽에
local function purse(parent: Instance, icon: string, x: number, y: number, w: number)
	Ui.smallIcon(parent, icon, x, y)
	return Ui.text(parent, "", x + 21, y + 4, w - 21)
end
BagWindow.purse = purse

function BagWindow.build(body: Frame, ctx, w: number, _h: number)
	local ui = ctx.ui
	local S = ItemCell.size()
	local tab = 1
	local sel = nil :: { tab: string, slot: number, id: any }? -- 고른 칸(id = 장비의 번호 · 묶음의 이름표 — 칸의 것이 바뀌면 고른 것을 푼다)
	local ask = nil :: { kind: string, n: number? }? -- 수를 고르는 중(버리기 · 맡기기 · 팔기 · 나누기 — 장비 팔기는 n 없이 묻기만)
	-- 여러 개 분해(2026-10-22 사용자: "장비 분해를 한번에 여러개 할수있게 해달라" — 공방 시험 탭의 luneTab.js bulkSpec과 같다): 장비 탭 아래 「분해」로 켠다 →
	--  칸을 누르면 고름 · 풂(bulk[장비 번호]) → 옆 판에 고른 수 · 받는 달가루 · [분해] [모두] [취소] → [분해]는 한 번 더 묻는다(bulkAsk) → 서버가 한꺼번에(Bag.dismantleMany)
	local bulk = nil :: { [any]: boolean }?
	local bulkAsk = false
	-- 여러 개 판매(2026-10-23 사용자: "인벤토리에서 모두판매할때 등급에 따라 판매할수있게해줘 낡은만 팔거나, 허름한만 팔거나, 빼어난만 팔거나" — 공방 탭의 bulkSellSpec과 같다):
	--  잡화 상인의 상점 창이 옆에 있으면(ui.service == "shop") 「분해」 자리가 「판매」 → 칸 · 등급 단추(그 등급의 장비를 모두 고름 · 다시 누르면 풂 · ★는 빼고) → [판매]는 한 번 더 묻는다 → 서버 Bag.sellMany
	local bulkMode = "dismantle" -- "dismantle" · "sell"(켤 때 정한다 — 상점 창이 닫히면 판매는 꺼진다)
	local hot: number? = nil -- 끌던 것을 놓을 칸
	local lastClick = { slot = 0, t = 0 }
	local dragEnd = 0 -- 마지막으로 끌기를 끝낸 때(그 직후에 오는 "눌렀다"는 끌기의 끝이지 누른 것이 아니다)
	local view = {}
	local gridRoot: ScrollingFrame -- 칸들의 스크롤 틀(아래에서 만든다 — 탭 단추가 맨 위로 되돌린다)

	local function key(): string
		return KEYS[tab]
	end
	local function unselect()
		sel, ask = nil, nil
	end
	-- 캐시 탭의 칸들: 가진 펫(산 차례) → 가진 탈것 · on = 꺼내 둔 펫 / 타는 탈것(서버의 상점 상태 — 없으면 빈 탭)
	local function cashList()
		local v = ctx.cash and ctx.cash()
		local out = {}
		if not v then
			return out
		end
		local myPet, myRide = ctx.myPet and ctx.myPet(), ctx.myRide and ctx.myRide()
		for _, id in v.pets or {} do
			table.insert(out, { ride = id, kind = "pet", on = (myPet or v.petOut) == id })
		end
		for _, id in v.mounts or {} do
			table.insert(out, { ride = id, kind = "mount", on = myRide == id })
		end
		local mySkin = if ctx.mySkin then ctx.mySkin() else v.wskin
		for _, id in v.wskins or {} do
			table.insert(out, { ride = id, kind = "wskin", on = (mySkin or v.wskin) == id }) -- 캐시 무기(2026-10-23)
		end
		return out
	end
	-- 모든 창을 다시 그린다(상세 판은 하나뿐이라, 여기서 고르면 다른 창이 고른 것은 풀린다)
	local function redraw()
		Windows.refresh(ctx.me())
	end
	local function choose(tabKey: string, slot: number, it)
		sel = { tab = tabKey, slot = slot, id = if it.ride then it.ride elseif it.item then it.item else it.id }
		ask = nil
		ui.detail = "bag"
	end

	local tabs = {}
	local tx = 0
	for i, name in TABNAMES do
		tabs[i] = Ui.tab(body, name, tx, 0, function()
			if tab ~= i then
				tab = i
				unselect()
				bulk, bulkAsk = nil, false -- 여러 개 분해는 장비 탭에서만
				gridRoot.CanvasPosition = Vector2.zero -- 다른 탭은 맨 위부터
				if KEYS[i] == "cash" and not (ctx.cash and ctx.cash()) and ctx.cashFetch then
					ctx.cashFetch() -- 가진 펫 · 탈것을 서버에 묻는다(받으면 다시 그린다)
				end
				redraw()
			end
		end)
		tx += tabs[i].width + 16
	end
	local count = Ui.text(body, "", w - BAG.countW, 0, BAG.countW, { align = "right", color = C.dim }) -- 찬 칸 / 가방의 칸

	-- 고른 칸의 것으로 할 수 있는 일(상세 판의 단추 · 두 번 누르기가 같이 쓴다)
	local function wear(it)
		ctx.send("Item", "equip", it.id)
		unselect()
	end
	local function use(entry)
		local g = Items.goods(entry.item)
		if g and g.kind == "bmRename" and ctx.openRename then
			ctx.openRename() -- 이름 바꾸기 주문서: 새 이름을 적는 칸(상점 창 — 이름이 바뀔 때 서버가 주문서를 쓴다)
			return
		elseif g and (g.kind == "bmDyePoint" or g.kind == "bmDyeRobe") and ctx.openDye then
			ctx.openDye(if g.kind == "bmDyePoint" then "point" else "robe") -- 염색약: 색을 고르는 창(색이 바뀔 때 서버가 염색약을 쓴다 — 2026-10-22)
			return
		end
		ctx.send("Potion", entry.item)
	end
	-- 팔 때 묻는 것: 장비는 팔지 말지만, 묶음은 몇 개를(처음에는 전부). 팔 수 없는 것(퀘스트의 물건)은 nil
	-- 수를 정하는 일(버리기 · 나누기 · 맡기기 · 팔기)은 화면 가운데의 수량 창으로(2026-10-21 사용자: "… 수량 입력하는 모달 받아서 처리해야지 … 모든 곳에서 수량받아서 처리해" —
	--  전에는 상세 판의 「-10 -1 +1 +10」). 처음 수 = 나누기 절반 · 나머지 그 칸의 전부 · 맡기기는 창고에 들어가는 만큼까지
	local function askCount(kind: string, tabKey: string, slot: number, entry)
		local bag = ctx.bag()
		local def = Items.goods(entry.item)
		if not bag or not def then
			return
		end
		local hi = CountPick.hi(kind, entry.n)
		if kind == "store" then
			hi = math.min(hi, Bag.storeRoomInView(bag, entry.item))
		end
		if hi < 1 then
			if kind == "store" then
				ctx.send("Item", "storeIn", tabKey, slot, 1) -- 창고가 가득 찼다(서버가 까닭을 알린다)
			end
			return
		end
		CountBox.open({
			owner = "bag",
			kind = kind,
			icon = def.icon,
			name = def.name,
			hi = hi,
			gainEach = if kind == "sell" then def.sell else nil,
			onYes = function(n: number)
				local action = if kind == "store" then "storeIn" else kind -- "discard" · "sell" · "split"
				ctx.send("Item", action, tabKey, slot, n)
				if kind == "store" and ui.storeShow then
					ui.storeShow(tabKey)
				end
				unselect()
				redraw()
			end,
		})
	end
	local function sellAsk(tabKey: string, entry)
		if tabKey == "gear" then
			return { kind = "sellGear" }
		end
		return nil
	end

	gridRoot = Ui.scroll(body, 0, GRID_Y, COLS * S, ROWS * S, ROWS * S, BAR) -- 칸들(늘린 가방은 위아래로 스크롤)
	gridRoot.Name = "Grid"
	local cells = {}
	-- 화면의 그 자리에 있는 칸(가방의 몇째 칸인가 — 없으면 nil). 끌던 것을 놓을 때 쓴다 — 스크롤 틀 밖(가려진 칸)은 아니다
	local function slotAt(at: Vector2): number?
		local bag = ctx.bag()
		if not ItemCell.over(gridRoot, at) then
			return nil
		end
		local n = ItemCell.at(cells, at)
		return if n and bag and n <= bag.size then n else nil
	end
	local function makeCell(i: number)
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		local cell
		cell = ItemCell.new(gridRoot, col * S, row * S, function(it)
			local n = i
			local now = os.clock()
			-- 끌어서 놓은 것은 누른 것이 아니다(끌기를 끝낼 때 놓은 자리의 칸에도 "눌렀다"가 온다 — 그대로 받으면 방금 옮긴 것의 고르기가 풀린다)
			if ctx.quick.dragging() or now - dragEnd < 0.2 then
				return
			end
			if bulk and key() == "gear" then
				if it and it.id ~= nil then
					bulk[it.id] = if bulk[it.id] then nil else true -- 여러 개 분해: 누르면 고름 · 풂
				end
				bulkAsk = false
				redraw()
				return
			end
			local twice = it ~= nil and lastClick.slot == n and now - lastClick.t < DOUBLE
			lastClick = { slot = if twice then 0 else n, t = now }
			if not it then
				unselect()
			elseif twice and it.ride then
				-- 캐시 탭: 두 번 누르기 = 꺼내기 · 넣기 / 타기 · 내리기
				if it.kind == "pet" and ctx.togglePet then
					ctx.togglePet(it.ride)
				elseif it.kind == "mount" and ctx.toggleRide then
					ctx.toggleRide(it.ride)
				elseif it.kind == "wskin" and ctx.toggleWskin then
					ctx.toggleWskin(it.ride) -- 캐시 무기: 장착 · 해제
				end
			elseif twice then
				-- 두 번 누르기: 장비는 장착, 소비 아이템은 사용
				local me = ctx.me()
				if key() == "gear" and me and BagWindow.canWear(me, it) then
					wear(it)
				elseif key() == "use" then
					use(it)
				end
			else
				choose(key(), n, it)
			end
			redraw()
		end, S)
		cells[i] = cell
		-- 끌기: 칸의 것을 누른 채 움직이면 그림이 따라온다(ui/quickEdit.luau가 끌기를 맡는다).
		--  가방의 다른 칸 = 옮긴다 · 퀵슬롯 = 소비 아이템을 그 칸에 놓는다 · 창고 창 = 맡긴다 · 상점 창 = 팔지 묻는다
		cell.hit.InputBegan:Connect(function(input)
			local it = cell.item
			if not it then
				return
			end
			local from, tabKey = i, key()
			local moved = false
			ctx.quick.press(if tabKey == "use" then it.item elseif tabKey == "cash" then it.ride else nil, nil, input, {
				icon = ItemCell.icon(it),
				size = S,
				hold = HOLD, -- 스마트폰: 잠깐 누르고 있다가 밀어야 끈다(그 전에 밀면 스크롤)
				onStart = function()
					gridRoot.ScrollingEnabled = false -- 끄는 동안은 칸들이 움직이지 않는다
				end,
				onMove = function(at: Vector2)
					moved = true
					local to = slotAt(at)
					if hot ~= to then
						hot = to
						view.refresh()
					end
					if ui.storeHover then
						ui.storeHover(at, tabKey) -- 창고의 놓을 칸이 밝아진다
					end
				end,
				onDrop = function(at: Vector2): boolean
					local to = slotAt(at)
					if tabKey == "cash" then
						return to ~= nil -- 캐시 탭의 칸끼리는 옮기지 않는다(차례는 가진 차례) · 퀵슬롯에 놓는 것은 quickEdit이 한다
					end
					if to and to ~= from then
						ctx.send("Item", "move", tabKey, from, to)
						-- 화면은 바로 옮긴다(서버가 가진 가방이 곧 다시 온다 — 그때 그것으로 맞춘다). 같은 묶음끼리 합치는 것은 서버의 셈을 기다린다
						local bag = ctx.bag()
						local list = if bag then bag[tabKey] else nil
						local a = if list then list[from] else nil
						local b = if list then list[to] else nil
						local merge = tabKey ~= "gear" and a and b and a.item == b.item
						if list and a and not merge then
							list[from], list[to] = b or false, a
						end
						-- 고른 것은 고른 채로 따라간다(합쳐지는 묶음이면 푼다)
						if sel and sel.tab == tabKey and (sel.slot == from or sel.slot == to) then
							if merge then
								unselect()
							else
								sel.slot = if sel.slot == from then to else from
							end
						end
					end
					if to then
						return true -- 가방의 칸에 놓았으면 여기서 끝(퀵슬롯에는 놓지 않는다)
					end
					-- 창고 창 위에 놓았다: 맡긴다(놓은 칸에 — 묶음은 전부)
					if ui.storeDrop and ui.storeDrop(at, tabKey, from) then
						if sel and sel.tab == tabKey and sel.slot == from then
							unselect()
						end
						return true
					end
					-- 대장장이 창 위에 놓았다: 그 장비를 강화할 장비로 올린다(2026-10-15 — 사용자: "강화에 드래그앤 드랍으로 둘수가 없음")
					if tabKey == "gear" and ui.forgeDrop and ui.forgeDrop(at) then
						ctx.toForge(it.id)
						return true
					end
					-- 상점 창 위에 놓았다: 그것을 고르고 팔지 묻는다(상세 판에 — 팔 수 없는 것이면 상세만 뜬다)
					if ui.shopDrop and ui.shopDrop(at) then
						choose(tabKey, from, it)
						ask = sellAsk(tabKey, it)
						if tabKey ~= "gear" and Items.goodsSell(it.item) > 0 then
							askCount("sell", tabKey, from, it) -- 묶음은 수량 창(처음 = 전부)
						end
						redraw()
						return true
					end
					return false
				end,
				onEnd = function()
					if moved then
						dragEnd = os.clock()
					end
					view.refresh() -- 스크롤을 다시 켠다(칸이 넷 줄을 넘을 때)
					if ui.storeHover then
						ui.storeHover(nil, nil)
					end
					if hot then
						hot = nil
						view.refresh()
					end
				end,
			})
		end)
	end

	for i = 1, COLS * ROWS do
		makeCell(i)
	end

	-- 창고에서 끌어 온 것을 놓는 자리(ui/shopWindow.luau의 창고가 묻는다): 가방 창 위인가 · 그 탭의 어느 칸인가.
	--  다른 탭이 열려 있었으면 그 탭으로 넘긴다(찾은 것이 보이게)
	local panel = body.Parent :: GuiObject
	ui.bagDrop = function(at: Vector2, tabKey: string): (boolean, number?)
		if not ItemCell.over(panel, at) then
			return false, nil
		end
		local slot = if tabKey == key() then slotAt(at) else nil
		if tabKey ~= key() then
			tab = table.find(KEYS, tabKey) or tab
			gridRoot.CanvasPosition = Vector2.zero
			unselect()
		end
		return true, slot
	end
	-- 창고에서 「찾기」로 찾았을 때: 가방이 그 탭을 보여 준다(찾은 것이 보이게)
	ui.bagShow = function(tabKey: string)
		if tabKey ~= key() then
			tab = table.find(KEYS, tabKey) or tab
			gridRoot.CanvasPosition = Vector2.zero
			unselect()
		end
	end
	ui.bagHover = function(at: Vector2?, tabKey: string?)
		local to = if at and tabKey == key() then slotAt(at) else nil
		if hot ~= to then
			hot = to
			view.refresh()
		end
	end

	-- 칸 아래: 「정렬」 · 「+4칸 값」, 그 아래 지갑(달돈 · 달가루 · 정수)
	local fy = GRID_Y + ROWS * S + BAG.footY
	local sort = Ui.button(body, WORDS.sort, 0, fy, BAG.sortW, function()
		ctx.send("Item", "sort", key())
		unselect()
		view.refresh()
	end)
	sort.frame.Name = "Sort"
	-- 「분해」(여러 개 분해를 켠다 · 켠 동안은 「취소」 — 장비 탭에서만)
	local bulkBtn = Ui.button(body, WORDS.dismantle, BAG.sortW + BAG.footGap, fy, BAG.bulkW, function()
		if bulk then
			bulk, bulkAsk = nil, false
		else
			bulk, bulkAsk = {}, false
			bulkMode = if ui.service == "shop" then "sell" else "dismantle"
			sel, ask = nil, nil
			ui.detail = "bag"
		end
		redraw()
	end)
	bulkBtn.frame.Name = "Bulk"
	local grow = Ui.button(body, "", w - BAG.growW, fy, BAG.growW, function()
		ctx.send("Item", "grow")
	end, { font = "small" })
	grow.frame.Name = "Grow"
	Ui.line(body, 0, fy + BAG.purseY - 5, w)
	local pw = Layout.purseW(w)
	local money = purse(body, "coin", -3, fy + BAG.purseY, pw)
	local dust = purse(body, "dust", pw - 3, fy + BAG.purseY, pw)
	local essence = purse(body, "orb", pw * 2 - 3, fy + BAG.purseY, pw)

	-- 고른 것의 상세 판(창 옆)
	local function detail(bag, me)
		if ui.detail ~= "bag" then
			unselect() -- 다른 창에서 골랐다
			bulk, bulkAsk = nil, false
		end
		if bulk and bulkMode == "sell" and ui.service ~= "shop" then
			bulk, bulkAsk = nil, false -- 상점 창이 닫혔다: 여러 개 판매를 끈다(분해로 바뀌지 않게)
		end
		if bulk and bulkMode == "sell" and key() == "gear" then
			local W = WORDS.bulkSell
			local ids, gain, first = {}, 0, nil
			local ofGrade = {} -- 등급마다 등급 단추가 고를 장비(★ 빼고)
			for i = 1, bag.size do
				local it = bag.gear[i]
				if it then
					if bulk[it.id] then
						table.insert(ids, it.id)
						gain += Items.sellPrice(it)
						first = first or it
					end
					if (it.star or 0) <= 0 then
						ofGrade[it.q] = ofGrade[it.q] or {}
						table.insert(ofGrade[it.q], it.id)
					end
				end
			end
			for id in bulk do
				if not table.find(ids, id) then
					bulk[id] = nil -- 가방에서 사라진 것
				end
			end
			local spec = { item = first, buttons = {}, chips = {}, onClose = function()
				bulk, bulkAsk = nil, false
				redraw()
			end }
			spec.info = { name = W.title, tone = "text", sub = W.sub, rows = { { W.picked, ("%d개"):format(#ids) }, { W.gain, "+" .. Format.short(gain), "gold" } }, notes = { { W.hint, "dim" } } }
			local grades = {}
			for q, def in Items.data.QUALITY do
				local list = ofGrade[q] or {}
				local on = #list > 0
				for _, id in list do
					on = on and bulk[id] == true
				end
				table.insert(grades, (if on then "1" else "0") .. #list)
				table.insert(spec.chips, { text = def.name, on = on, off = #list == 0, onClick = function()
					for _, id in list do
						bulk[id] = if on then nil else true -- 다 골라져 있으면 풀고, 아니면 모두 고른다
					end
					bulkAsk = false
					redraw()
				end })
			end
			if bulkAsk and #ids > 0 then
				spec.ask = {
					text = Format.fill(W.ask, { n = #ids }) .. "  " .. Format.fill(WORDS.gain, { n = Format.short(gain) }),
					yes = { text = W.go, onClick = function()
						ctx.send("Item", "sellMany", ids)
						bulk, bulkAsk = {}, false -- 판 뒤에도 켜 둔다(이어서 더 고른다)
						redraw()
					end },
					no = { text = WORDS.askNo, onClick = function()
						bulkAsk = false
						redraw()
					end },
				}
			else
				bulkAsk = false
				table.insert(spec.buttons, { text = W.go, main = true, off = #ids == 0, onClick = function()
					bulkAsk = true
					redraw()
				end })
				table.insert(spec.buttons, { text = W.stop, onClick = function()
					bulk, bulkAsk = nil, false
					redraw()
				end })
			end
			spec.key = table.concat({ "bulkSell", #ids, gain, tostring(bulkAsk), table.concat(grades, ","), if first then first.id else 0 }, "|")
			ItemDetail.show("bag", spec)
			return
		end
		if bulk and key() == "gear" then
			-- 여러 개 분해의 판: 고른 장비의 수 · 받는 달가루 · [분해] [모두 · 풀기] [취소] — [분해]는 한 번 더 묻는다
			local W = WORDS.bulk
			local ids, gain, first = {}, 0, nil
			local all, allOn = 0, true -- 「모두」가 고를 것(강화하지 않았고 지금보다 좋지 않은 장비)이 다 골라졌나
			for i = 1, bag.size do
				local it = bag.gear[i]
				if it then
					if bulk[it.id] then
						table.insert(ids, it.id)
						gain += Items.dismantle(it)
						first = first or it
					end
					if (it.star or 0) <= 0 and not BagWindow.better(me, bag, it) then
						all += 1
						allOn = allOn and bulk[it.id] == true
					end
				end
			end
			for id in bulk do
				if not table.find(ids, id) then
					bulk[id] = nil -- 가방에서 사라진 것(서버가 다시 보낸 가방에 없다)
				end
			end
			local spec = { item = first, buttons = {}, onClose = function()
				bulk, bulkAsk = nil, false
				redraw()
			end }
			spec.info = { name = W.title, tone = "text", sub = W.sub, rows = { { W.picked, ("%d개"):format(#ids) }, { W.gain, "+" .. Format.short(gain), "gold" } }, notes = { { W.hint, "dim" } } }
			if bulkAsk and #ids > 0 then
				spec.ask = {
					text = Format.fill(W.ask, { n = #ids }) .. "  " .. Format.fill(WORDS.gainDust, { n = Format.short(gain) }),
					yes = { text = W.go, onClick = function()
						ctx.send("Item", "dismantleMany", ids)
						bulk, bulkAsk = {}, false -- 분해한 뒤에도 여러 개 분해는 켜 둔다(이어서 더 고른다)
						redraw()
					end },
					no = { text = WORDS.askNo, onClick = function()
						bulkAsk = false
						redraw()
					end },
				}
			else
				bulkAsk = false
				table.insert(spec.buttons, { text = W.go, main = true, off = #ids == 0, onClick = function()
					bulkAsk = true
					redraw()
				end })
				table.insert(spec.buttons, { text = if all > 0 and allOn then W.none else W.all, onClick = function()
					local on = not (all > 0 and allOn)
					for i = 1, bag.size do
						local it = bag.gear[i]
						if it and (it.star or 0) <= 0 and not BagWindow.better(me, bag, it) then
							bulk[it.id] = if on then true else nil
						elseif it and not on then
							bulk[it.id] = nil
						end
					end
					redraw()
				end })
				table.insert(spec.buttons, { text = W.stop, onClick = function()
					bulk, bulkAsk = nil, false
					redraw()
				end })
			end
			spec.key = table.concat({ "bulk", #ids, gain, tostring(bulkAsk), tostring(all > 0 and allOn), if first then first.id else 0 }, "|")
			ItemDetail.show("bag", spec)
			return
		end
		if sel and sel.tab == "cash" then
			-- 캐시 탭의 펫 · 탈것(가진 것의 차례가 바뀌어도 이름표로 따라간다)
			local entry = nil
			for _, e in cashList() do
				if e.ride == sel.id then
					entry = e
				end
			end
			if not entry then
				unselect()
				ItemDetail.hide("bag")
				return
			end
			local prod = ctx.cashProduct and ctx.cashProduct(entry.ride)
			local isPet = entry.kind == "pet"
			local isSkin = entry.kind == "wskin" -- 캐시 무기(2026-10-23): 장착 · 해제(퀵슬롯에는 놓지 않는다)
			local spec = { item = entry, buttons = {}, onClose = function()
				unselect()
				redraw()
			end }
			spec.info = {
				name = if prod then prod.name else entry.ride,
				tone = "text",
				sub = (if isSkin then BMW.skinKind elseif isPet then BMW.petKind else BMW.mountKind) .. (if entry.on then " · " .. (if isSkin then BMW.skinTag elseif isPet then BMW.petOutTag else BMW.rideTag) else ""),
				rows = {},
				notes = { { if prod then prod.line or "" else "", "text" }, { if isSkin then BMW.skinHint elseif isPet then BMW.bagHint else BMW.rideHint, "dim" } },
			}
			table.insert(spec.buttons, {
				text = if isSkin then (if entry.on then BMW.skinOff else BMW.skinOn) elseif isPet then (if entry.on then BMW.petOff else BMW.petOn) else (if entry.on then BMW.rideOff else BMW.rideOn),
				main = not entry.on,
				onClick = function()
					if isSkin and ctx.toggleWskin then
						ctx.toggleWskin(entry.ride)
					elseif isPet and ctx.togglePet then
						ctx.togglePet(entry.ride)
					elseif not isPet and ctx.toggleRide then
						ctx.toggleRide(entry.ride)
					end
				end,
			})
			if not isSkin then -- (캐시 무기는 퀵슬롯에 놓지 않는다 — 한 번 장착하면 그대로)
				table.insert(spec.buttons, {
					text = WORDS.quick,
					onClick = function()
						ctx.quick.pick(entry.ride) -- 퀵슬롯이 반짝인다 — 놓을 칸을 누른다
					end,
				})
			end
			spec.key = table.concat({ "cash", entry.ride, tostring(entry.on) }, "|")
			ItemDetail.show("bag", spec)
			return
		end
		local entry = if sel then bag[sel.tab][sel.slot] else nil
		if sel and sel.tab == "gear" and (not entry or entry.id ~= sel.id) then
			-- 고른 장비가 다른 칸으로 갔으면(정렬 · 옮기기) 따라간다
			entry = nil
			for i = 1, bag.size do
				local it = bag.gear[i]
				if it and it.id == sel.id then
					sel.slot, entry = i, it
					break
				end
			end
		elseif sel and sel.tab ~= "gear" and entry and entry.item ~= sel.id then
			entry = nil -- 그 칸에 다른 것이 놓였다(정렬 · 옮기기)
		end
		if not sel or not entry then
			unselect()
			ItemDetail.hide("bag")
			return
		end
		local slot, tabKey, service = sel.slot, sel.tab, ui.service
		local spec = { item = entry, buttons = {}, onClose = function()
			unselect()
			redraw()
		end }
		local function button(text: string, onClick: () -> (), main: boolean?, off: boolean?)
			table.insert(spec.buttons, { text = text, main = main, off = off, onClick = onClick })
		end
		local function stopAsk()
			ask = nil
			view.refresh()
		end
		if tabKey == "gear" then
			local it = entry
			local worn = bag.equip[it.slot]
			local can = BagWindow.canWear(me, it)
			spec.info = ItemInfo.gear(it, me, worn, false)
			if ask and ask.kind == "sellGear" then
				spec.ask = ItemDetail.ask("sellGear", nil, 1, 1, {
					gain = function()
						return Items.sellPrice(it)
					end,
					yes = function()
						ctx.send("Item", "sell", "gear", slot)
						unselect()
						redraw()
					end,
					no = stopAsk,
				})
			elseif ask and ask.kind == "dismantle" then
				-- 분해도 한 번 묻는다(2026-10-18 — 전에는 누르면 바로 사라졌다): 「이 장비를 분해할까요?  달가루 +n」 · 분해 · 취소
				spec.ask = ItemDetail.ask("dismantle", nil, 1, 1, {
					gain = function()
						return Items.dismantle(it)
					end,
					gainWord = "gainDust",
					yes = function()
						ctx.send("Item", "dismantle", it.id)
						unselect()
						redraw()
					end,
					no = stopAsk,
				})
			else
				ask = nil
				button(WORDS.equip, function()
					wear(it)
					redraw()
				end, true, not can)
				button(WORDS.dismantle, function()
					ask = { kind = "dismantle" }
					view.refresh()
				end)
				if service == "store" then
					button(WORDS.toStore, function()
						ctx.send("Item", "storeIn", "gear", slot)
						if ui.storeShow then
							ui.storeShow("gear") -- 창고가 그 탭을 보여 준다(맡긴 것이 보이게)
						end
						unselect()
						redraw()
					end)
				elseif service == "forge" then
					button(WORDS.toForge, function()
						ctx.toForge(it.id)
					end)
				elseif service == "shop" then
					button(WORDS.sell, function()
						ask = { kind = "sellGear" }
						view.refresh()
					end)
				end
			end
			spec.key = table.concat({ "gear", it.id, it.q, it.star, tostring(it.broken), me.level, if worn then worn.id else 0, if worn then worn.star else 0, service or "-", tostring(can), if ask then ask.kind else "-" }, "|")
		else
			local def = Items.goods(entry.item)
			local have = Bag.countIn(bag, entry.item)
			spec.info = ItemInfo.goods(entry.item, me, have)
			ask = nil -- (묶음의 수는 수량 창이 정한다 — 위의 askCount)
			if not ask then
				if tabKey == "use" then
					button(WORDS.use, function()
						use(entry)
					end, true, def.lv ~= false and me.level < def.lv)
					button(WORDS.quick, function()
						ctx.quick.pick(entry.item) -- 퀵슬롯(스마트폰: 칸 단추)이 반짝인다 — 놓을 칸을 누른다
					end)
				end
				button(WORDS.discard, function()
					askCount("discard", tabKey, slot, entry) -- 처음에는 그 칸의 묶음 전부
				end)
				if entry.n > 1 then
					button(WORDS.split, function()
						askCount("split", tabKey, slot, entry) -- 처음에는 절반
					end)
				end
				if service == "store" and def.kind ~= "quest" then -- 퀘스트 물건은 맡길 수 없다(sim/bag.luau의 storeIn)
					button(WORDS.toStore, function()
						if entry.n == 1 then
							ctx.send("Item", "storeIn", tabKey, slot, 1)
							if ui.storeShow then
								ui.storeShow(tabKey)
							end
							unselect()
							redraw()
						else
							askCount("store", tabKey, slot, entry) -- 처음에는 그 칸의 묶음 전부
						end
					end)
				elseif service == "shop" and def.sell > 0 then
					button(WORDS.sell, function()
						askCount("sell", tabKey, slot, entry)
					end)
				end
			end
			spec.key = table.concat({ tabKey, slot, entry.item, entry.n, have, me.level, service or "-" }, "|")
		end
		ItemDetail.show("bag", spec)
	end

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		for i, button in tabs do
			button:setOn(i == tab)
		end
		if key() == "cash" then
			-- 캐시 탭: 가진 펫 · 탈것만(정렬 · 늘리기 없음). 비었으면 안내
			local own = cashList()
			gridRoot.CanvasSize = UDim2.fromOffset(0, ROWS * S)
			gridRoot.ScrollingEnabled = false
			gridRoot.ScrollBarThickness = 0
			count:set(if #own == 0 then BMW.bagEmpty else "")
			detail(bag, me)
			for i, cell in cells do
				cell.frame.Visible = i <= COLS * ROWS
				cell:set(own[i], { selected = sel ~= nil and sel.tab == "cash" and own[i] ~= nil and own[i].ride == sel.id })
			end
			grow.frame.Visible = false
			sort.frame.Visible = false
			bulkBtn.frame.Visible = false
			money:set(Format.short(me.money))
			dust:set(Format.short(bag.dust))
			essence:set(Format.short(bag.essence))
			return
		end
		sort.frame.Visible = true
		bulkBtn.frame.Visible = key() == "gear"
		bulkBtn:setText(if bulk then WORDS.bulk.stop elseif ui.service == "shop" then WORDS.bulkSell.go else WORDS.dismantle) -- 상점 창이 옆에 있으면 「판매」(2026-10-23)
		local list = bag[key()]
		-- 스크롤: 늘린 가방은 네 줄을 넘는다 — 넘는 만큼 칸을 만들고 스크롤 틀의 속을 늘린다
		local rows = math.ceil(bag.size / COLS)
		for i = #cells + 1, rows * COLS do
			makeCell(i)
		end
		local scroll = rows > ROWS
		gridRoot.CanvasSize = UDim2.fromOffset(0, math.max(ROWS, rows) * S)
		gridRoot.ScrollingEnabled = scroll and not ctx.quick.dragging()
		gridRoot.ScrollBarThickness = if scroll then BAR else 0
		local used = 0
		for i = 1, bag.size do
			if list[i] then
				used += 1
			end
		end
		count:set(("%d / %d"):format(used, bag.size))
		detail(bag, me) -- 고른 것이 사라졌으면 여기서 풀린다
		for i, cell in cells do
			cell.frame.Visible = i <= rows * COLS -- 줄여진 적은 없지만, 넘치는 칸은 숨긴다
			local item = list[i] or nil
			local picked = bulk ~= nil and key() == "gear" and item and bulk[item.id] == true -- 여러 개 분해로 고른 칸(2026-10-22)
			cell:set(item, { locked = i > bag.size, selected = picked or (sel ~= nil and sel.tab == key() and sel.slot == i), hot = hot == i, better = key() == "gear" and BagWindow.better(me, bag, item) })
		end
		-- 가방 늘리기(세 탭이 함께 늘어난다 — 값이 적혀 있다). 다 늘렸으면 단추가 없다
		grow.frame.Visible = bag.growCost ~= false
		if bag.growCost ~= false then
			grow:setText(BagWindow.growText(bag.growCost))
			grow:setEnabled(me.money >= bag.growCost)
		end
		sort:setEnabled(used > 1)
		money:set(Format.short(me.money))
		dust:set(Format.short(bag.dust))
		essence:set(Format.short(bag.essence))
	end

	function view.destroy()
		CountBox.hide("bag")
		ItemDetail.hide("bag")
		if ui.detail == "bag" then
			ui.detail = nil
		end
		ui.bagDrop, ui.bagHover, ui.bagShow = nil, nil, nil
	end
	return view
end

return BagWindow
