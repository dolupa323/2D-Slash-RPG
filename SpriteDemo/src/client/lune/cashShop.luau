-- 달빛 상점의 공간(2026-10-21 사용자: "달빛상점은 메뉴탭 안에 숨어있는게 아니라, 장비 , 능력치처럼 빠른버튼으로 앞에 나와야하고 ui 처럼 열리는 방식이아니라
--  메이플스토리 캐시샵처럼 아예 무적공간으로 들어가버리는 형태여야합니다. 로벅스 관련 쇼핑을 여유롭게 할수있는거죠 캐시샵은 마을에서만 갈수있구요" ·
--  "캐시샵 들어가고 나서 로딩중 잠시 넣고 그동안 다 로드해서 대기하는시간이 거의 없도록하세요").
--  아래 단추 줄의 「상점」 · ` 키 → (마을에서만) 화면 가득 「…가는 중」 → 그동안 서버에 들어간다고 알리고(server world.luau의 Cash "enter" — 맵에서 빠진다: 안 보이고 맞지 않는다)
--   공간을 막 뒤에서 다 짓고 그 안의 그림을 모두 불러 둔다(Curtain.load) → 달밤 배경 · 위쪽에 제목과 「나가기」 · 왼쪽에 미리보기(내 캐릭터 + 펫 · 탈것 — 상점의 펫 · 탈것 줄을 누르면 그것)
--   · 오른쪽에 상점 판(ui/cashWindow.luau를 그대로). 「나가기」 · ` · Esc → 막 → 서버가 들어간 자리로 다시 보낸다(Revive — boot의 goScene이 맵을 다시 그린다).
--  배치 · 글 = 공방 design/bm.js의 BM_SHOP.space(제가 정한 것) · 공방 시험 탭 ?lunedemo=cashshop
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local BM = require(lune.data["bm.generated"])
local ASSETS = require(lune.data["assets.generated"])
local RIDE = require(lune.data["ride.generated"])
local Layout = require(lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local CashWindow = require(script.Parent.ui.cashWindow)
local Sprite = require(script.Parent.sprite)
local RideView = require(script.Parent.rideView)
local WeaponFx = require(script.Parent.weaponFx) -- 캐시 무기의 피어오르는 점(2026-10-23)
local Curtain = require(script.Parent.curtain)
local Windows = require(script.Parent.ui.windows) -- (공간 안에서 여는 창 — 「확률 보기」 — 을 공간 위로 · 2026-11-10)

local SP = BM.shop.space
local FULL = BM.shop.full -- 화면 가득(2026-11-10 — 메이플 캐시샵처럼: 왼쪽 미리보기 · 오른쪽 상품 카드 · Layout.shopFull)
local W = SP.words
local C = Ui.COLOR
local S = Layout.CASH

local CashShop = {}
CashShop.SPACE = SP
local root: Frame? = nil
local parts: any = nil -- 지은 것들(미리보기 · 상점 판의 view · 고른 펫 · 탈것)
local busy = false
local unResize: (() -> ())? = nil -- 창 크기가 바뀌면 다시 짓는 것을 뺀다(나올 때)

function CashShop.isOpen(): boolean
	return root ~= nil
end

-- 공간의 치수(화면 틀의 점 — 2026-11-10부터 화면 가득: Layout.shopFull. 전의 것 = 가운데 묶음을 k배 Layout.shopSpace)
function CashShop.layout(uiW: number, uiH: number, _us: number?)
	return Layout.shopFull(uiW, uiH, Stage.insetTop)
end

-- 탈것마다 영웅의 발이 탈것의 기준점(발밑)보다 위에 있는 점(탈것 그림의 점 — ride.generated의 seat.dy · 미리보기의 높이를 잰다)
local RIDE_SEAT = {}
for _, q in RIDE.mounts do
	RIDE_SEAT[q.id] = -((q.seat and q.seat.dy) or 0)
end
local L0 -- 지은 때의 치수(Layout.shopFull — 미리보기의 폭 · 높이)
-- 미리보기에 보일 펫 · 탈것: id = 상품의 이름표(pet_ · mount_) · nil = 지금 꺼내 둔 것 · 탄 것
local function setPreview(id: string?)
	if not parts then
		return
	end
	local p = parts
	if id and string.sub(id, 1, 4) == "pet_" then
		p.petId = id
	elseif id and string.sub(id, 1, 6) == "mount_" then
		p.rideId = id
	elseif id and string.sub(id, 1, 6) == "wskin_" then
		p.skinId = id -- 캐시 무기(2026-10-23): 미리보기 영웅이 그 무기를 든다
	end
	p.hero:setLook({ point = p.look and p.look.point, robe = p.look and p.look.robe, skin = p.skinId })
	if p.pet and p.pet.who ~= p.petId then
		p.pet.sprite:destroy()
		p.pet = nil
	end
	if p.petId and not p.pet then
		p.pet = { who = p.petId, sprite = Sprite.new(p.world, p.petId, 2) }
	end
	p.ride:setRide(p.rideId)
	-- 큰 탈것(거대 탈것 「이끼 골렘」 — 2026-10-22)이 미리보기 판에 다 들어가게 판 안의 배율을 줄인다(보통 탈것 · 펫은 그대로 — 판에 들어간다)
	local fit = 1
	local mc = p.rideId and p.ride.mount and p.ride.mount.char
	if mc then
		local f1 = mc.clips.idle.frames[1]
		local ms = Sprite.sizeOn(mc.size or 1)
		local seat = (p.ride.mount and RIDE_SEAT[p.rideId]) or 0
		local needW = ((if f1 then f1[4] else mc.fw) * ms) + 16
		local needH = (seat * ms) + 34 -- 등 높이 + 탄 영웅(약 22점) + 여유
		fit = math.min(1, p.availW / needW, p.availH / needH)
	end
	if fit ~= p.fit then
		p.fit = fit
		local r = p.ratio * fit
		p.scale.Scale = r
		p.world.Size = UDim2.fromOffset(L0.previewW / r, L0.h / r)
		p.cx, p.floor = math.floor(L0.previewW / r / 2), math.floor(p.floorUi / r)
	end
	local name = nil
	if id then
		for _, q in BM.products do
			if q.id == id then
				name = q.name
			end
		end
	end
	if id and not name then
		local q = CashWindow.product(id) -- (상자에서만 나오는 펫 · 탈것 — 상품 목록에 없다: 뽑기 연출을 닫은 뒤 미리보기 · 2026-11-10)
		name = q and q.name
	end
	p.name:set(name or "")
end
CashShop.preview = setPreview
-- 「원래대로」(2026-11-10): 미리보기를 지금 내 것으로(꺼낸 펫 · 탄 탈것 · 낀 캐시 무기)
function CashShop.resetPreview()
	local p = parts
	if not p or not p.ctx then
		return
	end
	local ctx = p.ctx
	p.petId = ctx.myPet()
	p.rideId = ctx.myRide()
	p.skinId = if ctx.mySkin then ctx.mySkin() else nil
	setPreview(nil)
end

-- 한 장 그린다(boot의 그리기 — 상점이 열려 있는 동안 장마다)
function CashShop.step(now: number, dt: number)
	if not parts then
		return
	end
	local p = parts
	local cx, floor = p.cx + 8, p.floor -- 영웅 · 탈것은 가운데에서 8점 오른쪽(펫이 왼쪽에 설 자리 — 공방 탭과 같다)
	-- 탈것이면 영웅을 앉는 자리에 · 펫은 영웅의 뒤(왼쪽 30점)에
	local hx, hy, hs = p.ride:update(now, dt, cx, floor, 1, false, false, false, nil, nil)
	local char = p.hero.char
	p.hero:set("idle", Sprite.frameAt(char, "idle", now, false), hx or cx, hy or floor, 1, hs) -- 탄 동안 작게(게임과 같다)
	p.wfx:step({ p.hero }, dt) -- 캐시 무기의 피어오르는 점
	if p.pet then
		local pc = p.pet.sprite.char
		p.pet.sprite:set("idle", Sprite.frameAt(pc, "idle", now, false), cx - 30, floor, 1)
	end
end

-- 「…가는 중」(공간이 다 지어지고 그림이 다 불러와질 때까지 — 막 위의 글)
local function sayLoading(text: string?)
	if not root then
		return
	end
	local p = parts
	p.loading:set(text or "")
	p.loading:show(text ~= nil)
	p.content.Visible = text == nil
end

-- 공간을 짓는다(보이지 않게 — 그림을 불러온 뒤 sayLoading(nil)로 연다). ctx = boot의 창 ctx(cash · cashDo · bag · me) + who(영웅의 그림 이름) · myPet · myRide · onLeave
--  2026-11-10 사용자 "달빛상점 접속 ui를 좀 메이플 캐시샵처럼 전체화면으로해서 좀 둘러보기도 좋게 개편을 해줘": 가운데의 작은 묶음(k배)을 버리고 화면 가득 —
--   위 줄 = 제목 · 「나가기」 / 왼쪽 = 미리보기(화면 폭의 24% · 내 캐릭터를 게임의 FULL.zoom배 · 「원래대로」) / 오른쪽 = 상품 판(남은 폭 모두 · 상품은 카드 — CashWindow.build의 grid)
--   (메이플 캐시샵 — MapleSEA 공식 안내: 위에 큰 분류 · 작은 분류 탭 · 왼쪽에 내 모습 미리보기 · 아이템 그림 아래 「구매」). 배치 = Layout.shopFull(공방 paint.js cashFullLayout과 같다)
local function build(ctx)
	local uiW, uiH = Stage.uiW, Stage.uiH
	local L = Layout.shopFull(uiW, uiH, Stage.insetTop) -- (위 줄을 Roblox 기본 단추 띠 아래로 — 창 모드: 2026-11-10)
	local r = Stage.group(Stage.ui, "CashShop", 500) -- HUD(100) · 창(150) · 막이 아닌 모든 것 위
	root = r
	local base = Ui.box(r, 0, 0, uiW, uiH, C.ink) -- 그림이 오기 전에도 게임 화면이 비치지 않게
	base.Active = true -- 아래의 단추(HUD · 손가락 단추)로 누름이 새지 않게
	local bg = Instance.new("ImageLabel")
	bg.Name = "Back"
	bg.BackgroundTransparency = 1
	bg.BorderSizePixel = 0
	bg.Image = ASSETS[SP.bg] or ""
	bg.ScaleType = Enum.ScaleType.Crop -- 화면의 꼴이 16:9가 아니어도 가득(넘치는 가장자리만 잘린다)
	bg.Size = UDim2.fromScale(1, 1)
	bg.ZIndex = 2
	bg.Parent = r
	local veil = Ui.box(r, 0, 0, uiW, uiH, C.ink, SP.veil)
	veil.ZIndex = 3
	local content = Ui.group(r, 0, 0, uiW, uiH, "Content")
	content.ZIndex = 4
	local loading = Ui.text(r, "", 0, math.floor(uiH / 2) - 8, uiW, { align = "center", font = "body", color = C.accent, outline = true, z = 5 })
	-- 위 줄: 제목 · 「나가기」
	Ui.text(content, W.title, FULL.pad, L.top + 11, 200, { font = "body", color = C.accent, outline = true })
	Ui.button(content, W.leave, L.leaveX, L.top + 5, SP.leaveW, function()
		CashShop.leave(ctx)
	end).frame.Name = "Leave"
	-- 왼쪽: 미리보기 판 · 제목 · 「원래대로」 · 바닥 · 내 캐릭터(게임 도트를 FULL.zoom배 — 화면의 정수 화소로) · 고른 것의 이름 · 안내
	local pv = Ui.panel(content, L.previewX, L.previewY, L.previewW, L.h)
	pv.Name = "Preview"
	Ui.text(pv, W.preview, 10, 8, L.previewW - 20 - FULL.resetW, { font = "body" })
	Ui.button(pv, W.reset or "", L.previewW - 10 - FULL.resetW, 6, FULL.resetW, function()
		CashShop.resetPreview()
	end, { h = 20, font = "small" }).frame.Name = "Reset"
	local nameText = Ui.text(pv, "", 10, L.h - 46, L.previewW - 20, { align = "center", color = C.gold })
	Ui.text(pv, W.hint, 10, L.h - 28, L.previewW - 20, { align = "center", color = C.dim, lines = 2 })
	local ratio = math.max(1, math.floor(Stage.scale * FULL.zoom + 0.5)) / Stage.uiScale -- (한 점 = 화면의 정수 화소)
	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundTransparency = 1
	world.BorderSizePixel = 0
	world.Size = UDim2.fromOffset(L.previewW / ratio, L.h / ratio)
	world.ZIndex = 3
	world.ClipsDescendants = true
	world.Parent = pv
	local scale = Instance.new("UIScale")
	scale.Scale = ratio -- 판 안은 게임 도트(화면 틀의 점 x ratio = 화면의 정수 화소)
	scale.Parent = world
	local floorUi = L.h - FULL.floor
	Ui.box(pv, 16, floorUi, L.previewW - 32, 2, C.line).ZIndex = 2
	local cx, floor = math.floor(L.previewW / ratio / 2), math.floor(floorUi / ratio)
	local hero = Sprite.new(world, ctx.who(), 3)
	local look = ctx.myLook and ctx.myLook() -- 내 무기 · 로브 색(염색 — 2026-10-22) · 캐시 무기는 장착한 것(setPreview가 입힌다)
	local ride = RideView.new(world, 3, nil)
	L0 = L
	parts = { root = r, content = content, loading = loading, world = world, hero = hero, ride = ride, pet = nil, petId = ctx.myPet(), rideId = ctx.myRide(), name = nameText, cx = cx, floor = floor,
		scale = scale, ratio = ratio, fit = 1, floorUi = floorUi, availW = L.previewW / ratio, availH = floorUi / ratio, -- (큰 탈것은 setPreview가 fit배로 줄인다)
		look = look, skinId = ctx.mySkin and ctx.mySkin() or nil, wfx = WeaponFx.new(), ctx = ctx } -- 캐시 무기(2026-10-23 — 미리보기에서도 점이 피어오른다)
	setPreview(nil)
	-- 오른쪽: 상품 판(카드 — CashWindow.build의 grid). 펫 · 탈것 · 캐시 무기 카드를 누르면 미리보기에
	local panel = Ui.panel(content, L.panelX, L.panelY, L.panelW, L.h)
	panel.Name = "Shop"
	local body = Ui.group(panel, FULL.panelPad, FULL.panelPad, L.bodyW, L.bodyH, "Body")
	local wctx = setmetatable({
		cashFetch = function() end, -- 들어올 때 받은 것을 쓴다(server의 Cash "enter"가 상점의 지금 것을 같이 준다)
		cashPreview = setPreview,
	}, { __index = ctx })
	parts.view = CashWindow.build(body, wctx, L.bodyW, L.bodyH, nil, L)
	return r
end

-- 들어간다. ctx: 창 ctx + who · myPet · myRide(함수) · invoke(일, …) · notice(글) · townOk() · onOpen() · onClose()
function CashShop.enter(ctx)
	if root or busy then
		return
	end
	if not ctx.townOk() then
		ctx.notice(W.townOnly)
		return
	end
	busy = true
	task.spawn(function()
		local t0 = os.clock()
		Curtain.cover()
		local res = ctx.invoke("enter")
		if not (res and res.ok) then
			Curtain.lift()
			busy = false
			ctx.notice((res and res.why) or W.townOnly)
			return
		end
		ctx.setCash(res)
		ctx.onOpen() -- 게임 화면 · HUD를 숨기고 움직이지 않게
		Windows.raise(true) -- 공간 안에서 여는 창(「확률 보기」)이 공간 위에 뜨게(전에는 공간 뒤에 떠서 눌러도 아무것도 안 보였다 — 2026-11-10)
		local ok, err = pcall(build, ctx)
		if not ok then
			warn("[lune] 달빛 상점을 짓지 못했다: " .. tostring(err))
		end
		-- 창 크기가 바뀌면(F11 · 창 모드 · 창 끌어 늘리기 — 2026-11-10) 지금 화면에 맞춰 다시 짓는다(전에는 들어갈 때의 크기 그대로라 「나가기」가 화면 밖 · 띠 밑에 남았다)
		if unResize then
			unResize()
		end
		unResize = Stage.onResize(function()
			CashShop.relayout(ctx)
		end)
		sayLoading(W.loading)
		Curtain.lift(0.12) -- 막을 걷으면 「…가는 중」이 보인다(그 뒤에서 그림을 모두 불러 둔다)
		if root then
			Curtain.load({ root }) -- 배경 · 상품 그림 · 미리보기의 캐릭터 · 펫 · 탈것
		end
		local wait = SP.minLoad - (os.clock() - t0)
		if wait > 0 then
			task.wait(wait)
		end
		sayLoading(nil)
		busy = false
	end)
end

-- 상점의 것이 바뀌었다(받기 · 꺼내기 · 산 것이 들어옴)
function CashShop.refresh(me)
	if parts and parts.view and parts.view.refresh then
		parts.view.refresh(me)
	end
end

-- 화면 크기가 바뀌었다: 공간을 지금 화면에 맞춰 다시 짓는다(서버에는 묻지 않는다 — 들어올 때 받은 상점의 것 그대로)
local function clearParts()
	if parts then
		if parts.pet then
			parts.pet.sprite:destroy()
		end
		parts.hero:destroy()
		parts.wfx:destroy() -- (캐시 무기의 점)
		parts.ride:destroy()
	end
	if root then
		root:Destroy()
	end
	root, parts = nil, nil
end
function CashShop.relayout(ctx)
	if not root or busy then
		return
	end
	clearParts()
	local ok, err = pcall(build, ctx)
	if not ok then
		warn("[lune] 달빛 상점을 다시 짓지 못했다: " .. tostring(err))
	end
end

-- 나온다: 막 → 공간을 치운다 → 서버가 들어간 자리로 다시 보낸다(Revive → boot의 goScene이 맵을 다시 그리고 막을 걷는다)
function CashShop.leave(ctx)
	if not root or busy then
		return
	end
	busy = true
	task.spawn(function()
		sayLoading(W.back)
		Curtain.cover()
		if unResize then
			unResize()
			unResize = nil
		end
		clearParts()
		while Windows.anyOpen() do -- (공간 안에서 연 창 — 「확률 보기」 — 을 닫는다)
			if not Windows.closeTop() then
				break
			end
		end
		Windows.raise(false)
		ctx.onClose()
		ctx.invoke("leave") -- 서버가 Revive를 보낸다 → boot의 goScene이 맵을 다시 그리고 막을 걷는다
		ctx.afterLeave() -- (끝내 Revive가 오지 않으면 막을 걷는다 — 검은 화면에 멈추지 않게)
		busy = false
	end)
end

return CashShop
