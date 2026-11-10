-- 뽑기 상자의 연출(2026-11-10 사용자: "랜덤뽑기상자를 달빛상점에서 사면 사자마자 연출이 나오고 뽑기 연출이 나오고 뭐가뜰까 두근두근하다가 짠 이런 가챠의 맛을 살려야지
--  지금 사면 뭐나오는지도 모르고 인벤토리를 가야 알잖아 연출을해야지 다른 상용화 게임들의 가차 연출을 공부하고 적용해").
--  결제가 끝나면(서버의 CashGot { box = 나온 것 | false }) boot가 GachaView.open을 부른다 → 화면 가득 어두워지고 산 상자가 가운데로 떨어진다 → 떨림이 점점 커지고 빛살 · 고리가 모인다
--   (마지막에 빛이 등급의 색 — 보통 라벤더 · 드문 것 금빛) → 상자가 부풀며 하얗게 번쩍 → 나온 것(펫 · 탈것 = 게임의 움직이는 그림 · 말풍선 꾸밈 = 그 말풍선 · 다 가진 상자 = 윤슬 조각)이
--   튀어나오며 커진다 · 이름 · 한 줄 · 드문 것이면 「드문 것!」과 금빛 조각 · [확인]. 어디를 눌러도 공개로 건너뛴다 · [확인]이 뜬 뒤에 누르면 닫힌다 · 그 뒤 close초가 지나면 저절로 닫힌다.
--  셈 = shared/lune/ui/gachaFx.luau(공방 js/lune/gachaFx.js와 같다) · 수 · 색 · 글 = 공방 design/bm.js의 GACHA(bm.generated의 gacha) · 공방 시험 탭 ?lunedemo=gacha · gacharare · gachaspare · gachabubble
--  화면을 고치는 것은 BindToRenderStep 안에서만(RenderStepped 이벤트를 쓰지 않는다 — 2026-10-10 규칙). 층 600 = 달빛 상점의 공간(500) 위 · 룬 판(900) 아래
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lune = ReplicatedStorage.shared.lune
local BM = require(lune.data["bm.generated"])
local GachaFx = require(lune.ui.gachaFx)
local Ui = require(script.Parent.ui)
local Stage = require(script.Parent.Parent.stage)
local Sprite = require(script.Parent.Parent.sprite)
local Bubbles = require(script.Parent.Parent.chatBubbles)
local Kit = require(script.Parent.kit) -- (데미지 스킨의 숫자 — Kit.dmg · 2026-11-10)

local G = BM.gacha
local S = G.size
local C = Ui.COLOR
local STEP = "LuneGacha"
local WHITE = Color3.new(1, 1, 1)
local CONF = {}
for i, h in G.color.confetti do
	local c = GachaFx.hexRgb(h)
	CONF[i] = Color3.fromRGB(c[1], c[2], c[3])
end
local T = GachaFx.times(G)

local GachaView = {}
GachaView.Z = 600
local cur = nil -- 열린 연출(한 번에 하나)

local function pool(layer: Instance, n: number, z: number, w: number, h: number, color: Color3?): { Frame }
	local out = {}
	for i = 1, n do
		local f = Ui.box(layer, 0, 0, w, h, color or WHITE, 1)
		f.ZIndex = z
		f.Visible = false
		out[i] = f
	end
	return out
end

-- 원(두 점 높이의 띠)을 그 조각들로: 가운데 (cx, cy) · 반지름 R · 짙기 a
local function disc(frames: { Frame }, cx: number, cy: number, R: number, color: Color3, a: number)
	local rows = if a > 0 and R > 0 then GachaFx.discRows(R) else {}
	for i, f in frames do
		local r = rows[i]
		if r then
			f.Position = UDim2.fromOffset(cx + r[1], cy + r[2])
			f.Size = UDim2.fromOffset(r[3], 2)
			f.BackgroundColor3 = color
			f.BackgroundTransparency = 1 - a
			f.Visible = true
		else
			f.Visible = false
		end
	end
end

-- 한 점의 크기(화면 틀의 점): 칸(item[1] x item[2])에 들고 한 점이 item[3]배를 넘지 않게 · 화면의 정수 화소로
local function dotSize(w: number, h: number): number
	local want = math.min(S.item[3], S.item[1] / math.max(1, w), S.item[2] / math.max(1, h))
	local us = Stage.uiScale
	return math.max(1, math.floor(want * us)) / us
end

function GachaView.isOpen(): boolean
	return cur ~= nil
end

function GachaView.close()
	local c = cur
	if not c then
		return
	end
	cur = nil
	pcall(function()
		RunService:UnbindFromRenderStep(STEP)
	end)
	if c.sprite then
		c.sprite:destroy()
	end
	c.layer:Destroy()
	if c.onClose then
		task.spawn(c.onClose)
	end
end

-- 한 장(BindToRenderStep — 연 지 t초)
local function step(c, t: number)
	if t >= T.tEnd then
		GachaView.close()
		return
	end
	local o = GachaFx.at(t, G, c.rare)
	local cx, cy = c.cx, c.cy
	local col = Color3.fromRGB(o.color[1], o.color[2], o.color[3])
	c.dim.BackgroundTransparency = 1 - o.dim
	-- 빛줄기(가운데에서 밖으로 · 끝으로 갈수록 옅다 — UIGradient)
	local beams = GachaFx.beams(o, S)
	for i, b in c.beams do
		local d = beams[i]
		local f = b.frame
		if d then
			local mid = d[2] + d[3] / 2
			f.Position = UDim2.fromOffset(cx + math.cos(d[1]) * mid, cy + math.sin(d[1]) * mid)
			f.Size = UDim2.fromOffset(d[3], S.rayW)
			f.Rotation = math.deg(d[1])
			f.BackgroundColor3 = col
			if b.alpha ~= d[4] then
				b.alpha = d[4]
				b.grad.Transparency = NumberSequence.new(1 - d[4], 1) -- (시작 = 그 짙기 · 끝 = 다 비침)
			end
			f.Visible = true
		else
			f.Visible = false
		end
	end
	-- 빛 원: 바깥(옅게) · 안(짙게)
	disc(c.outer, cx, cy, o.glowR, col, o.glow * 0.45)
	disc(c.inner, cx, cy, math.floor(o.glowR * 0.6), col, o.glow * 0.9)
	-- 모이는 고리
	local ring = GachaFx.ringDots(o, S)
	local rh = math.floor(S.ringDot / 2)
	for i, f in c.ring do
		local d = ring[i]
		if d then
			f.Position = UDim2.fromOffset(cx + d[1] - rh, cy + d[2] - rh)
			f.BackgroundColor3 = col
			f.BackgroundTransparency = 1 - o.ring
			f.Visible = true
		else
			f.Visible = false
		end
	end
	-- 상자
	c.box.Visible = o.boxShow
	if o.boxShow then
		local side = math.floor(S.box * o.boxK + 0.5)
		c.box.Size = UDim2.fromOffset(side, side)
		c.box.Position = UDim2.fromOffset(cx + o.boxX - math.floor(side / 2), cy + o.boxY - math.floor(side / 2))
	end
	-- 나온 것
	local show = o.itemShow and o.itemK > 0
	if c.sprite then
		if show then
			local f1 = c.f1
			local s = c.dot * o.itemK -- 한 점의 크기(화면 틀의 점)
			local char = c.sprite.char
			local ox, oy = char.ox, char.oy
			local px = cx + (ox - f1[6]) * s - f1[4] * s / 2
			local py = cy + o.itemY - f1[5] * s / 2 + (oy - f1[7]) * s
			c.sprite:set("idle", Sprite.frameAt(char, "idle", t - T.tPop), px, py, 1, s / c.base)
		else
			c.sprite.label.Visible = false
		end
	elseif c.bubble then
		c.bubbleGroup.Visible = show
		c.bubbleScale.Scale = math.max(0.01, 2 * o.itemK)
		c.bubbleGroup.Position = UDim2.fromOffset(cx, cy + o.itemY)
		Bubbles.twinkle(c.bubble, t)
	elseif c.big then -- 데미지 스킨의 숫자 · 이름표 테두리(크게 — UIScale)
		c.big.Visible = show
		c.bigScale.Scale = math.max(0.01, c.bigK * o.itemK)
		c.big.Position = UDim2.fromOffset(cx, cy + o.itemY)
	elseif c.pic then
		c.pic.Visible = show
		if show then
			local side = math.floor(S.box * o.itemK + 0.5)
			c.pic.Size = UDim2.fromOffset(side, side)
			c.pic.Position = UDim2.fromOffset(cx - math.floor(side / 2), cy + o.itemY - math.floor(side / 2))
		end
	end
	-- 조각 · 금빛 조각
	local sp = GachaFx.sparks(o.spark, S)
	for i, f in c.sparks do
		local d = sp[i]
		if d then
			f.Size = UDim2.fromOffset(d[3], d[3])
			f.Position = UDim2.fromOffset(cx + d[1], cy + d[2])
			f.BackgroundColor3 = col
			f.BackgroundTransparency = math.max(0, o.spark) * 0.7
			f.Visible = true
		else
			f.Visible = false
		end
	end
	local cf = GachaFx.confetti(o.confetti, G)
	for i, f in c.confetti do
		local d = cf[i]
		if d then
			f.Position = UDim2.fromOffset(cx + d[1], cy + d[2])
			f.BackgroundColor3 = CONF[d[3]] or WHITE
			f.BackgroundTransparency = if o.confetti > 0.7 then (o.confetti - 0.7) / 0.3 else 0
			f.Visible = true
		else
			f.Visible = false
		end
	end
	c.flash.BackgroundTransparency = 1 - o.flash
	-- 글 · [확인]
	c.rareT:show(o.rare)
	c.nameT:show(o.name)
	c.lineT:show(o.name)
	if o.name then
		local k = math.max(0, math.min(1, (t - T.tName) / G.fadeIn))
		local dy = math.floor(6 * (1 - k) + 0.5) -- 이름이 아래에서 올라온다
		c.nameT:move(0, cy + S.nameY + dy)
		c.lineT:move(cx - 200, cy + S.lineY + dy)
	end
	c.tapT:show(o.tap)
	c.ok.frame.Visible = o.ok
end

-- 연다. spec = { box = 상자 그림(24점 그림의 이름), kind = "pet" | "mount" | "bubble" | "spare", got = 나온 것의 이름표(spare면 nil),
--  name = 보일 이름, line = 한 줄, rare = 드문 것인가, icon = spare의 그림(윤슬 조각), onClose = 닫힌 뒤(선택) }
function GachaView.open(spec)
	GachaView.close()
	local uiW, uiH = Stage.uiW, Stage.uiH
	local layer = Stage.group(Stage.ui, "Gacha", GachaView.Z)
	local cx, cy = math.floor(uiW / 2), math.floor(uiH / 2) + S.cy
	local c = { layer = layer, cx = cx, cy = cy, rare = spec.rare == true, onClose = spec.onClose, t0 = os.clock() }
	c.dim = Ui.box(layer, 0, 0, uiW, uiH, C.ink, 1)
	c.dim.ZIndex = 1
	c.dim.Active = true -- 아래의 단추(상점 판 · HUD)로 누름이 새지 않게
	c.beams = {}
	for i = 1, S.rays do
		local f = Ui.box(layer, 0, 0, 1, S.rayW, WHITE, 0)
		f.ZIndex = 2
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Visible = false
		local grad = Instance.new("UIGradient")
		grad.Parent = f
		c.beams[i] = { frame = f, grad = grad, alpha = -1 }
	end
	c.outer = pool(layer, #GachaFx.discRows(S.glowR[2] + 3), 3, 1, 2)
	c.inner = pool(layer, #GachaFx.discRows(math.floor((S.glowR[2] + 3) * 0.6)), 3, 1, 2)
	c.ring = pool(layer, S.ring, 4, S.ringDot, S.ringDot)
	c.box = Ui.pic(layer, spec.box, 0, 0)
	c.box.ZIndex = 5
	-- 나온 것: 펫 · 탈것 = 게임의 그림(서기) · 말풍선 꾸밈 = 그 말풍선(두 배) · 윤슬 조각 = 그림(세 배)
	if (spec.kind == "pet" or spec.kind == "mount") and spec.got then
		local ok, sprite = pcall(Sprite.new, layer, spec.got, 6)
		if ok and sprite then
			c.sprite = sprite
			local f1 = sprite.char.clips.idle.frames[1]
			c.f1 = f1
			c.base = Sprite.sizeOn(sprite.char.size or 1) -- (Sprite:set이 곱하는 그 그림의 크기 — 나눠서 한 점의 크기를 맞춘다)
			c.dot = dotSize(f1[4], f1[5])
		end
	elseif spec.kind == "bubble" and spec.got then
		local g = Ui.group(layer, cx, cy, 1, 1, "Bubble")
		g.ZIndex = 6
		local sc = Instance.new("UIScale")
		sc.Scale = 2
		sc.Parent = g
		c.bubbleGroup, c.bubbleScale = g, sc
		c.bubble = Bubbles.sample(g, spec.got, spec.name or "", 0, 0)
		-- (꼬리 끝이 (0, 0) — 말풍선의 가운데가 가운데에 오게 반쯤 내린다)
		c.bubble.frame.Position = UDim2.fromOffset(-math.floor(c.bubble.w / 2), -math.floor((c.bubble.h + 6) / 2))
	end
	if spec.kind == "dskin" and spec.part then
		-- 데미지 스킨(2026-11-10): 그 스킨의 숫자 둘 — 위 = 보통 「12345」 · 아래 = 크리티컬 「67890」을 세 배로
		local g = Ui.group(layer, cx, cy, 1, 1, "Dmg")
		g.ZIndex = 6
		local sc = Instance.new("UIScale")
		sc.Scale = 3
		sc.Parent = g
		local a = Kit.dmg(g, "12345", Color3.new(1, 1, 1), spec.part, false)
		local b = Kit.dmg(g, "67890", Color3.new(1, 1, 1), spec.part, true)
		a.frame.Position = UDim2.fromOffset(-math.floor(a.width / 2), -a.height - 1)
		b.frame.Position = UDim2.fromOffset(-math.floor(b.width / 2), 1)
		c.big, c.bigScale, c.bigK = g, sc, 3
	elseif spec.kind == "ntag" and spec.got then
		-- 이름표 테두리(2026-11-10): 내 이름을 그 테두리로 세 배
		local g = Ui.group(layer, cx, cy, 1, 1, "Tag")
		g.ZIndex = 6
		local sc = Instance.new("UIScale")
		sc.Scale = 3
		sc.Parent = g
		local label = Ui.tag(g, spec.who or spec.name or "", Color3.new(1, 1, 1), 220, true)
		Ui.tagSkin(label, spec.got)
		label.Frame.Position = UDim2.fromOffset(-math.floor((label.Width or 0) / 2), -6)
		c.big, c.bigScale, c.bigK = g, sc, 3
	end
	if not c.sprite and not c.bubble and not c.big then
		c.pic = Ui.pic(layer, spec.icon or spec.box, 0, 0)
		c.pic.ZIndex = 6
	end
	c.sparks = pool(layer, S.sparks, 7, 3, 3)
	c.confetti = pool(layer, S.confetti, 7, 2, 3)
	c.flash = Ui.box(layer, 0, 0, uiW, uiH, WHITE, 1)
	c.flash.ZIndex = 8
	c.rareT = Ui.text(layer, G.words.rare, 0, cy + S.rareY, uiW, { align = "center", font = "body", outline = true, color = C.gold, z = 9 })
	c.nameT = Ui.text(layer, spec.name or "", 0, cy + S.nameY, uiW, { align = "center", font = "body", outline = true, color = if c.rare then C.gold else C.text, z = 9 })
	c.lineT = Ui.text(layer, spec.line or "", cx - 200, cy + S.lineY, 400, { align = "center", outline = true, color = if spec.dup then C.accent else C.dim, z = 9 }) -- (가진 것이 나왔으면 민트로 「이미 가진 것 — 윤슬 조각 n개로」 · 가장 긴 한 줄 「윤슬 탈것 상자의 탈것 — …」이 본문 글씨로 362점)
	c.tapT = Ui.text(layer, G.words.tap, 0, cy + S.tapY, uiW, { align = "center", outline = true, color = C.dim, z = 9 })
	-- 누름: 공개 전 = 공개로 건너뛴다 · [확인]이 뜬 뒤 = 닫는다
	local hit = Ui.hit(layer)
	hit.ZIndex = 9
	hit.Activated:Connect(function()
		if cur ~= c then
			return
		end
		local t = os.clock() - c.t0
		if t < T.tPop then
			c.t0 = os.clock() - T.tPop
		elseif t >= T.tOk then
			GachaView.close()
		end
	end)
	c.ok = Ui.button(layer, G.words.ok, cx - math.floor(S.okW / 2), cy + S.okY, S.okW, function()
		if cur == c then
			GachaView.close()
		end
	end, { main = true })
	c.ok.frame.ZIndex = 10
	cur = c
	step(c, 0)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value, function()
		if cur == c then
			step(c, os.clock() - c.t0)
		end
	end)
	return c
end

-- 서버가 알린 뽑기(CashGot의 key · { box = 나온 것 | false })를 연출의 spec으로(boot가 쓴다 · 자동 검사가 본다). 뽑기 상자가 아니면 nil
--  나온 것 = 펫 · 탈것(ride.generated의 이름 · 한 줄) · 말풍선 꾸밈(bm.generated의 bubbles) · false = 다 가진 상자 → 윤슬 조각 rules.random.spare개
local Gacha = require(lune.sim.gacha)
local Format = require(lune.ui.format)
local RIDE = require(lune.data["ride.generated"])
local NAMED = {} -- [이름표] = { name, line }
for _, list in { RIDE.pets, RIDE.mounts, (BM.bubbles and BM.bubbles.list) or {}, (BM.dskins and BM.dskins.list) or {}, (BM.nametags and BM.nametags.list) or {} } do -- (데미지 스킨 · 이름표 테두리 — 2026-11-10)
	for _, q in list do
		NAMED[q.id] = q
	end
end
local PROD = {}
for _, p in BM.products do
	PROD[p.id] = p
end
function GachaView.specOf(key: string, got: any, dup: any)
	local b = Gacha.box(key)
	if not b then
		return nil
	end
	local p = PROD[key]
	local spec = { box = (p and p.icon) or key, kind = b.kind, rare = false }
	if typeof(got) == "string" then
		local q = NAMED[got]
		spec.got = got
		spec.name = (q and q.name) or got
		spec.line = (q and q.line) or ""
		spec.rare = table.find(b.rare or {}, got) ~= nil
		spec.part = q and q.part -- (데미지 스킨의 숫자판 — UI 키트의 이름)
		if typeof(dup) == "number" and dup > 1 then -- 가진 것이 나왔다(2026-11-10): 그것을 그대로 보이고 아래 줄에 「이미 가진 것 — 하나 더(가진 수 n)」 · dup = 받은 뒤의 가진 수
			spec.dup = dup
			spec.line = Format.fill(G.words.dup or "", { n = dup })
		end
	else
		local y = PROD.yunseul
		spec.kind = "spare"
		spec.icon = (y and y.icon) or "yunseul"
		spec.name = Format.fill(G.words.spareName, { name = (y and y.name) or "", n = (BM.rules.random and BM.rules.random.spare) or 3 })
		spec.line = G.words.spare
	end
	return spec
end

-- 자동 검사가 연 지 t초의 모습을 그대로 그려 본다(시간을 흘리지 않는다)
function GachaView.stepAt(t: number)
	if cur then
		step(cur, t)
	end
end

return GachaView
