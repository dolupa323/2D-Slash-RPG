-- 「달의 계승자」 — 뽑기 상자의 연출(2026-11-10 사용자: "랜덤뽑기상자를 달빛상점에서 사면 사자마자 연출이 나오고 뽑기 연출이 나오고 뭐가뜰까 두근두근하다가 짠 …
--  지금 사면 뭐나오는지도 모르고 인벤토리를 가야 알잖아 연출을해야지"). 보는 것:
--   ① 셈(shared/lune/ui/gachaFx.luau): 차례(떨어짐 → 떨림 → 등급의 색 → 부풂 → 튀어나옴 → 이름 → [확인]) · 떨림 동안 빛이 흰빛에서 등급의 색(보통 라벤더 · 드문 것 금빛)으로 ·
--      공개 전에는 나온 것이 안 보이고 · 금빛 조각은 드문 것만 · 번쩍임은 부풂에서 차고 걷힌다 · 빛줄기 · 고리 · 빛 원의 점
--   ② 서버가 알린 뽑기 → 연출의 spec(GachaView.specOf): 펫 · 탈것 · 말풍선 꾸밈의 이름 · 한 줄 · 드문 것 · 다 가진 상자 = 윤슬 조각 x3 · 뽑기 상자가 아니면 nil
--   ③ 화면 없이 지어 본다: 공개 전 나온 것이 안 보인다 · 누르면 공개로 건너뛴다 · [확인]은 공개 뒤에 · [확인]을 누르면 닫히고(그림 · 판을 치운다 · 그리기를 푼다) 닫힌 뒤의 일을 부른다 ·
--      [확인]이 뜬 뒤 close초면 저절로 닫힌다 · 공개된 펫 · 탈것의 한 점은 칸(item) 안 · 화면의 정수 화소
--   ④ 글이 칸에 든다(한 줄 = 400점 폭 · 본문 글씨로 재도 들어간다)
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local GachaFx = req("ReplicatedStorage/shared/lune/ui/gachaFx")
local G = BM.gacha
local S = G.size
local T = GachaFx.times(G)

-- ① 셈
expect(T.tShake > 0 and T.tHint > T.tShake and T.tBurst > T.tHint and T.tPop > T.tBurst and T.tName > T.tPop and T.tOk > T.tName and T.tEnd > T.tOk, "차례: 떨림 → 등급의 색 → 부풂 → 튀어나옴 → 이름 → [확인] → 저절로 닫힘")
expect(T.tPop >= 1.5 and T.tPop <= 3, ("기다림(공개까지) %.2f초 — 두근두근할 만큼 · 지루하지 않게(1.5 ~ 3초)"):format(T.tPop))
local o0 = GachaFx.at(0, G, true)
eq(o0.dim, 0, "처음에는 어둡지 않다(fade초에 걸쳐 어두워진다)")
eq(o0.boxY, -S.fallH, "상자는 위에서 떨어지기 시작한다")
expect(o0.boxShow and not o0.itemShow and o0.tap and not o0.ok, "처음: 상자 · 「누르면 바로 연다」 · 나온 것 · [확인]은 없다")
eq(GachaFx.at(G.fall, G, true).boxY, 0, "fall초에 가운데에 닿는다")
expect(math.abs(GachaFx.at(G.fall + G.bounce / 2, G, true).boxY) >= S.bounceH - 1, "한 번 튀어 오른다")
local maxShake = 0
for i = 0, 40 do
	local t = T.tShake + (T.tBurst - T.tShake) * i / 40
	local o = GachaFx.at(t, G, false)
	maxShake = math.max(maxShake, math.abs(o.boxX))
	expect(math.abs(o.boxX) <= S.shakeAmp[2], "떨림은 shakeAmp 안")
end
expect(maxShake >= S.shakeAmp[2] - 1, "떨림이 끝으로 갈수록 커진다(가장 큰 " .. maxShake .. "점)")
local white = GachaFx.hexRgb(G.color.start)
local function same(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
expect(same(GachaFx.at(T.tShake + 0.01, G, true).color, white), "떨림의 처음 빛 = 흰빛(등급을 아직 알리지 않는다)")
expect(same(GachaFx.at(T.tBurst - 0.001, G, true).color, GachaFx.hexRgb(G.color.rare)), "떨림의 끝 = 드문 것이면 금빛")
expect(same(GachaFx.at(T.tBurst - 0.001, G, false).color, GachaFx.hexRgb(G.color.normal)), "떨림의 끝 = 보통이면 라벤더")
expect(G.color.rare ~= G.color.normal, "두 등급의 색이 다르다")
expect(GachaFx.at(T.tShake + 0.5, G, true).ring > 0 and GachaFx.at(T.tShake + 0.5, G, true).ringR > GachaFx.at(T.tBurst - 0.01, G, true).ringR, "고리가 상자로 모인다")
eq(GachaFx.at(T.tBurst - 0.01, G, true).flash, 0, "부풀기 전에는 번쩍이지 않는다")
expect(GachaFx.at(T.tPop - 0.001, G, true).flash > 0.8, "부풂의 끝에 하얗게 번쩍")
eq(GachaFx.at(T.tPop + G.flashOut + 0.01, G, true).flash, 0, "번쩍임은 flashOut초에 걷힌다")
local pop = GachaFx.at(T.tPop, G, true)
expect(pop.itemShow and not pop.boxShow, "튀어나온 때: 상자가 사라지고 나온 것")
local peak = 0
for i = 0, 30 do
	peak = math.max(peak, GachaFx.at(T.tPop + G.pop * i / 30, G, true).itemK)
end
expect(math.abs(peak - (1 + S.popOver)) < 0.02, ("튀어나오며 넘쳤다(%.2f배) 돌아온다"):format(peak))
expect(math.abs(GachaFx.at(T.tPop + G.pop + 0.01, G, true).itemK - 1) < 1e-9, "그 뒤 제 크기")
expect(GachaFx.at(T.tPop + 0.3, G, true).confetti >= 0, "드문 것: 금빛 조각")
eq(GachaFx.at(T.tPop + 0.3, G, false).confetti, -1, "보통: 금빛 조각이 없다")
expect(GachaFx.at(T.tName, G, true).rare and not GachaFx.at(T.tName, G, false).rare, "「드문 것!」은 드문 것만")
expect(not GachaFx.at(T.tOk - 0.01, G, true).ok and GachaFx.at(T.tOk, G, true).ok, "[확인]은 okAt초 뒤에")
local after = GachaFx.at(T.tOk + 1, G, true)
eq(#GachaFx.beams(after, S), S.rays, "빛줄기 rays줄")
local bs = GachaFx.beams(after, S)
expect(bs[1][3] > bs[2][3], "빛줄기는 길고 짧게 번갈아")
eq(#GachaFx.ringDots(GachaFx.at(T.tShake + 0.5, G, true), S), S.ring, "고리의 점 ring개")
eq(#GachaFx.ringDots(after, S), 0, "열린 뒤 고리는 없다")
eq(#GachaFx.sparks(GachaFx.at(T.tPop + 0.1, G, true).spark, S), S.sparks, "튀어나올 때 조각 sparks개")
eq(#GachaFx.confetti(GachaFx.at(T.tPop + 0.1, G, true).confetti, G), S.confetti, "금빛 조각 confetti개")
local rows = GachaFx.discRows(S.glowR[2])
local top, bottom, widest = math.huge, -math.huge, 0
for _, r in rows do
	top, bottom, widest = math.min(top, r[2]), math.max(bottom, r[2] + 2), math.max(widest, r[3])
end
expect(top >= -S.glowR[2] and bottom <= S.glowR[2] and widest <= S.glowR[2] * 2 and widest >= S.glowR[2] * 2 - 2, "빛 원의 줄이 원 안을 채운다")
expect(S.glowR[1] * 2 > S.box * 0.8, "빛 원이 상자보다 크다(상자에 가려 안 보이던 것 — 2026-11-10 공방 화면)")
expect(S.box % 24 == 0, "상자 = 24점 그림의 정수 배(점이 고르다)")

-- ② spec
local function signal()
	local sig = { fns = {} }
	function sig:Connect(fn)
		table.insert(self.fns, fn)
		return { Disconnect = function() end }
	end
	function sig:Fire(...)
		for _, f in self.fns do
			f(...)
		end
	end
	return sig
end
local made = { texts = {}, boxes = {}, pics = {} }
local function frame(name)
	local f = { Name = name, Visible = true }
	function f:Destroy()
		f.gone = true
	end
	return f
end
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function(_, k)
		return k
	end }),
	box = function(parent, x, y, w, h, color, alpha)
		local b = frame("Box")
		b.parent, b.BackgroundColor3, b.BackgroundTransparency = parent, color, alpha or 0
		table.insert(made.boxes, b)
		return b
	end,
	group = function(parent, x, y, w, h, name)
		local f = frame(name)
		f.parent = parent
		return f
	end,
	pic = function(parent, name, x, y)
		local p = frame("Pic")
		p.pic = name
		table.insert(made.pics, p)
		return p
	end,
	text = function(parent, value, x, y, width, opts)
		local t = { value = value, x = x, y = y, width = width, opts = opts or {}, shown = true }
		function t.show(_, on)
			t.shown = on
		end
		function t.move(_, nx, ny)
			t.x, t.y = nx, ny
		end
		table.insert(made.texts, t)
		return t
	end,
	hit = function(parent)
		local h = frame("Hit")
		h.Activated = signal()
		made.hit = h
		return h
	end,
	tag = function(parent, text)
		local t = { Frame = frame("Tag"), Width = 8 * #text, text = text }
		made.tagLabel = t
		return t
	end,
	tagSkin = function(label, id)
		label.skin = id
	end,
	button = function(parent, text, x, y, w, onClick, opts)
		local b = { frame = frame("Button"), text = text, click = onClick, opts = opts }
		made.ok = b
		return b
	end,
})
local layers = {}
MOCK("Client/lune/stage", {
	uiW = 960,
	uiH = 540,
	uiScale = 2,
	ui = frame("Ui"),
	group = function(parent, name, z)
		local f = frame(name)
		f.z = z
		table.insert(layers, f)
		return f
	end,
})
local sprites = {}
MOCK("Client/lune/sprite", {
	new = function(parent, who, z)
		local c = CHARS.chars[who]
		assert(c, "없는 캐릭터 " .. tostring(who))
		local s = { who = who, char = c, label = frame("Sprite"), sets = {} }
		function s:set(clip, f, x, y, dir, scale)
			table.insert(self.sets, { clip = clip, f = f, x = x, y = y, scale = scale })
			self.label.Visible = true
		end
		function s:destroy()
			self.gone = true
		end
		table.insert(sprites, s)
		return s
	end,
	frameAt = function()
		return 1
	end,
	sizeOn = function(size)
		return size
	end,
})
MOCK("Client/lune/chatBubbles", {
	sample = function(parent, skin, text)
		local b = { frame = frame("Sample"), w = 100, h = 20, skin = skin, text = text }
		made.bubble = b
		return b
	end,
	twinkle = function() end,
})
local bound, unbound = nil, 0
SERVICE("RunService", {
	BindToRenderStep = function(_, name, prio, fn)
		bound = fn
	end,
	UnbindFromRenderStep = function()
		unbound += 1
		bound = nil
	end,
})
NumberSequence = { new = function(a, b)
	return { a, b }
end }
local GachaView = req("Client/lune/ui/gachaView")

local function firstOf(list, rare)
	for _, q in list do
		if (q.rare == true) == rare then
			return q
		end
	end
	return nil
end
for key, b in BM.boxes do
	local pool = {}
	for _, e in b.pool do
		pool[e[1]] = true
	end
	for id in pool do
		local spec = GachaView.specOf(key, id)
		expect(spec ~= nil and spec.got == id and spec.kind == b.kind, key .. ": " .. id .. " → 연출(종류 " .. tostring(spec and spec.kind) .. ")")
		if spec then
			expect(spec.name ~= id and #spec.name > 0, key .. ": 이름이 있다 " .. id .. " = " .. spec.name)
			eq(spec.rare, table.find(b.rare, id) ~= nil, key .. ": 드문 것인가 " .. id)
			eq(spec.box, (function()
				for _, p in BM.products do
					if p.id == key then
						return p.icon
					end
				end
				return nil
			end)(), key .. ": 떨어지는 상자 = 그 상품의 그림")
			-- ④ 글이 칸에 든다(본문 글씨로 재도 — 작은 글씨는 더 좁다)
			local text = req("Client/ui/pixelText")
			expect((text.Measure(spec.line)) <= 400, ("한 줄이 400점 안: %s (%d)"):format(spec.line, (text.Measure(spec.line))))
			expect((text.Measure(spec.name)) <= 600, "이름이 화면 안: " .. spec.name)
		end
	end
	local spare = GachaView.specOf(key, false)
	expect(spare and spare.kind == "spare" and spare.icon == "yunseul" and spare.rare == false, key .. ": 다 가진 상자 → 윤슬 조각")
	eq(spare and spare.name, "윤슬 조각 x" .. BM.rules.random.spare, key .. ": 「윤슬 조각 x3」")
end
eq(GachaView.specOf("money", "pet_bud"), nil, "뽑기 상자가 아니면 연출이 없다")
expect(firstOf(RIDE.mounts, true) ~= nil, "드문 탈것이 있다(별고래 · 달빛 해파리)")

-- ③ 화면 없이
local closed = 0
local spec = GachaView.specOf("mountbox", "mount_whale")
spec.onClose = function()
	closed += 1
end
GachaView.open(spec)
expect(GachaView.isOpen() and bound ~= nil, "열리면 그리기를 건다(BindToRenderStep)")
eq(layers[#layers].z, GachaView.Z, "층 " .. GachaView.Z .. "(달빛 상점의 공간 500 위)")
local whale = sprites[#sprites]
expect(whale and whale.who == "mount_whale", "나온 탈것의 그림(게임의 움직이는 그림)")
advance(1.0)
bound()
eq(#whale.sets, 0, "공개 전에는 나온 것을 그리지 않는다")
expect(made.ok.frame.Visible == false, "공개 전에는 [확인]이 없다")
made.hit.Activated:Fire()
advance(0.05)
bound()
expect(#whale.sets > 0, "누르면 공개로 건너뛴다")
advance(G.pop + 0.05)
bound()
local last = whale.sets[#whale.sets]
local f1 = whale.char.clips.idle.frames[1]
local dot = last.scale * (whale.char.size or 1)
expect(f1[4] * dot <= S.item[1] + 0.01 and f1[5] * dot <= S.item[2] + 0.01, ("별고래가 칸 안(%dx%d점 → %.0fx%.0f)"):format(f1[4], f1[5], f1[4] * dot, f1[5] * dot))
expect(math.abs(dot * 2 - math.floor(dot * 2 + 0.5)) < 1e-6, "한 점 = 화면의 정수 화소(화면 틀 2배에서 " .. dot * 2 .. "화소)")
made.hit.Activated:Fire()
expect(GachaView.isOpen(), "[확인]이 뜨기 전에는 눌러도 닫히지 않는다")
advance(G.okAt + G.fadeIn)
bound()
expect(made.ok.frame.Visible == true, "[확인]이 뜬다")
local nameT
for _, t in made.texts do
	if t.value == "별고래" then
		nameT = t
	end
end
expect(nameT and nameT.shown and nameT.opts.color == "gold", "이름 「별고래」 — 드문 것은 금빛")
local rareShown = false
for _, t in made.texts do
	if t.value == G.words.rare and t.shown then
		rareShown = true
	end
end
expect(rareShown, "「" .. G.words.rare .. "」")
made.ok.click()
expect(not GachaView.isOpen() and unbound >= 1 and whale.gone and layers[#layers].gone, "[확인] → 닫힌다(그림 · 판을 치우고 그리기를 푼다)")
advance(0.01)
eq(closed, 1, "닫힌 뒤의 일(달빛 상점의 미리보기)을 한 번 부른다")

-- 저절로 닫힘 · 다 가진 상자
local spec2 = GachaView.specOf("petbox", false)
GachaView.open(spec2)
local pic = made.pics[#made.pics]
eq(pic.pic, "yunseul", "다 가진 상자: 윤슬 조각의 그림")
advance(T.tEnd + 0.1)
bound()
expect(not GachaView.isOpen(), "[확인]이 뜬 뒤 close초면 저절로 닫힌다")

-- 말풍선 꾸밈
local spec3 = GachaView.specOf("bubblebox", "bub_star")
GachaView.open(spec3)
expect(made.bubble and made.bubble.skin == "bub_star" and made.bubble.text == spec3.name, "말풍선 꾸밈: 그 말풍선에 그 이름")
GachaView.close()
expect(not GachaView.isOpen(), "닫기")

-- 가진 것이 나왔다(2026-11-10 — 중복): 그것을 그대로 보이고 아래 줄에 「이미 가진 것 — 윤슬 조각 n개로」(민트)
local dupSpec = GachaView.specOf("petbox", "pet_silver", 2)
expect(dupSpec.dup == 2 and dupSpec.got == "pet_silver" and string.find(dupSpec.line, "2", 1, true) ~= nil and string.find(dupSpec.line, "윤슬", 1, true) == nil, "가진 펫: 그 펫 · 「하나 더 · 이제 2개」(윤슬 조각 아님) " .. tostring(dupSpec.line))
expect(GachaView.specOf("petbox", "pet_silver", 1).dup == nil, "가진 수 1(처음) = 「하나 더」 줄 없음")
GachaView.open(dupSpec)
local dupLine = nil
for _, t in made.texts do
	if t.value == dupSpec.line then
		dupLine = t
	end
end
expect(dupLine and dupLine.opts.color == "accent", "그 줄은 민트")
GachaView.close()
-- 데미지 스킨: 그 스킨의 숫자 둘(보통 · 크리티컬)을 세 배로 · 이름표 테두리: 내 이름을 그 테두리로 세 배
local dsk = GachaView.specOf("dmgskin", "dsk_aurora")
expect(dsk.kind == "dskin" and dsk.part == "dmg_aurora" and dsk.rare, "데미지 스킨의 숫자판 · 드문 것")
local cd = GachaView.open(dsk)
advance(T.tPop + G.pop + 0.05)
bound()
expect(cd.big and cd.big.Visible and math.abs(cd.bigScale.Scale - 3) < 1e-6, "숫자가 세 배로 보인다")
GachaView.close()
local ntag = GachaView.specOf("tagskin", "ntag_royal")
ntag.who = "달빛나무"
local cn = GachaView.open(ntag)
expect(made.tagLabel and made.tagLabel.text == "달빛나무" and made.tagLabel.skin == "ntag_royal", "이름표 테두리: 내 이름을 그 테두리로")
expect(cn.big ~= nil, "크게 보인다")
GachaView.close()
