-- 「달의 계승자」 — 2026-10-21 사용자 요청 묶음:
--  "스텟, 스킬 초기화 완전무료로 풀겠습니다" · "닉네임 이름표 왼쪽에 레벨 나오게 … 다른사람에게 레벨 보이게" · "명예의 전당 좀더 넓찍하게 … 지금 닉네임 한글자부터 ... 처리 되버립니다"
--  "대영주의 성에도 명예의 전당처럼 순위 표시 있어야합니다" · "검정색 동그랗게 생긴 … 기본펫 하나 … 무료 쿠폰으로 푸는 용도" · "쿠폰 코드 입력창 … 그 기본펫 지급"
--  보는 것: ① 쿠폰의 셈(번호의 꼴 · 한 번만 · 기간 · 펫 · 저장) ② 서버(맞는 번호 → 펫 · 두 번째는 안 됨 · 틀린 번호는 1분에 다섯 번 · 계정에 저장) ③ 기본펫은 상품이 아니다 · 그림 · 아이콘
--   ④ 글이 칸에 들어간다(능력치 「정말 초기화?」 · 쿠폰 창 · 이름표 「Lv.200 열두 자」) ⑤ 명예의 전당 · 대영주의 성의 비석 면에 이름 · 순위가 들어간다(폰 2배 · 1080p 2.5배)
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Rank = req("ReplicatedStorage/shared/lune/sim/rank")
local pixelText = req("Client/ui/pixelText")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("small_o", KIT.font.small_o, {})
pixelText.Register("body_o", KIT.font.body_o, {})
local function W(text: string, font: string?): number
	return (pixelText.Measure(text, font or "small"))
end

-- ① 쿠폰의 셈
eq(Cash.couponCode(" dong-geuli "), "DONGGEULI", "빈칸 · 줄표를 빼고 대문자로")
eq(Cash.couponCode("abc 123"), "ABC123", "가운데 빈칸도 뺀다")
eq(Cash.couponCode(""), nil, "빈 글은 아니다")
eq(Cash.couponCode("쿠폰"), nil, "한글은 번호가 아니다")
eq(Cash.couponCode(string.rep("A", 25)), nil, "25자는 너무 길다")
eq(Cash.couponCode(42), nil, "글이 아니면 아니다")
local acct = Account.new()
local def = { code = "TESTPET", pet = "pet_crow" }
local ok, got = Cash.redeem(acct, def, 1000)
expect(ok and got.pet == "pet_crow", "쓰면 펫을 받는다")
expect(acct.bm.pets.pet_crow == true and acct.bm.petOut == "pet_crow", "꺼내 둔 펫이 없으면 바로 꺼낸다")
local ok2, why2 = Cash.redeem(acct, def, 1001)
expect(not ok2 and why2 == "이미 쓴 쿠폰이다", "한 계정에 한 번")
local acct2 = Account.new()
acct2.bm.pets.pet_silver, acct2.bm.petsOut, acct2.bm.petOut = true, { "pet_silver" }, "pet_silver" -- (꺼내 둔 펫들 = petsOut — 2026-10-30 펫 셋)
expect(Cash.redeem(acct2, def, 1000), "다른 계정은 또 쓴다")
eq(acct2.bm.petOut, "pet_silver", "꺼내 둔 펫은 그대로")
eq(#acct2.bm.petsOut, 1, "꺼내 둔 펫이 있으면 쿠폰 펫은 더 꺼내지 않는다(자리가 남아도 — 가방에서 꺼낸다)")
expect(not Cash.redeem(Account.new(), { code = "LATE", pet = "pet_crow", till = 500 }, 1000), "기간이 지났다")
expect(not Cash.redeem(Account.new(), { code = "SOON", pet = "pet_crow", from = 2000 }, 1000), "아직 아니다")
local back = Cash.unpack(Cash.pack(acct.bm), Account.MAX)
eq(back.coupons.TESTPET, 1000, "쓴 쿠폰이 저장된다")
expect(back.pets.pet_crow == true, "받은 펫이 저장된다")
local oldSave = Cash.pack(Cash.new())
oldSave.coupons = nil
expect(next(Cash.unpack(oldSave, Account.MAX).coupons) == nil, "예전 저장(쿠폰이 없던 때)도 읽는다")

-- ③ 기본펫: 상품이 아니다 · 펫 표에 있다 · 그림 · 아이콘
local listed = false
for _, p in BM.products do
	listed = listed or p.id == "pet_crow"
end
expect(not listed, "쿠폰 펫은 달빛 상점의 상품이 아니다(쿠폰으로만)")
local inRide = nil
for _, q in RIDE.pets do
	if q.id == "pet_crow" then
		inRide = q
	end
end
expect(inRide ~= nil and inRide.free == "coupon" and inRide.name == "아기 재까마귀", "펫 표에 쿠폰 펫으로")
expect(Cash.PET.pet_crow ~= nil, "서버의 펫 표에도(꺼내기 · 넣기)")
expect(CHARS.chars.pet_crow ~= nil and CHARS.chars.pet_crow.clips.idle ~= nil, "그림(서기)")
-- 이어서 사용자 "그냥 펫 검정동글이말고 재까마귀 몬스터 모델 그대로 가져다가써서 몬스터보다는 크기가 작게해서 펫크기 맞춰가지고 펫으로 쓰자 쿠폰펫"(2026-10-21):
--  쿠폰 펫 = 아기 재까마귀(pet_crow) — 몬스터 재까마귀(crow)의 서기 그림을 그대로 · 다른 펫과 같은 배율로(몬스터는 1배)
do
	local mon, pet = CHARS.chars.crow, CHARS.chars.pet_crow
	eq(#pet.clips.idle.frames, #mon.clips.idle.frames, "몬스터의 서기 장 수 그대로")
	for i, f in pet.clips.idle.frames do
		eq(table.concat(f, ","), table.concat(mon.clips.idle.frames[i], ","), ("서기 %d장 = 몬스터의 그 장(그림판의 같은 칸)"):format(i))
	end
	expect(mon.size == nil or mon.size == 1, "몬스터는 1배")
	eq(pet.size, CHARS.chars.pet_silver.size, "펫은 다른 펫과 같은 배율(점의 굵기가 같다)")
	expect(pet.size < 1, "몬스터보다 작다")
end
expect(KIT.parts.icons.icons.ride_pet_crow ~= nil and KIT.parts.pics.icons.ride_pet_crow ~= nil, "아이콘 18점 · 24점")

-- ④ 글이 칸에 들어간다
local ST = UI.layout.stat
expect(W("정말 초기화?", "body_o") <= ST.resetW - 6, ("능력치 창의 「정말 초기화?」 %d점 — 단추 %d점 안"):format(W("정말 초기화?", "body_o"), ST.resetW - 6))
local CP = UI.layout.coupon
local CW = CP.words
eq(#string.split(pixelText.Wrap(CW.guide, CP.w), "\n"), 2, "쿠폰 창의 안내는 두 줄")
expect(W(CW.use, "body_o") <= CP.btnW - 6, "「사용」이 단추에 들어간다")
expect(not string.find(CW.use, "다$"), "단추에 「~다」를 쓰지 않는다")
local gotText = string.gsub(CW.got, "{name}", "아기 재까마귀")
expect(#string.split(pixelText.Wrap(gotText, CP.w), "\n") <= 2, "받았다는 글은 두 줄 안 — " .. gotText)
for _, why in { "없는 쿠폰 번호다", "이미 쓴 쿠폰이다", "잠시 뒤에 다시 적어 주세요", "저장하지 못했다 — 잠시 뒤에 다시 적어 주세요" } do
	expect(#string.split(pixelText.Wrap(why, CP.w), "\n") <= 2, "까닭이 두 줄 안 — " .. why)
end
local longName = "은빛달토끼를좋아하는용사"
-- 이름표: 판 안에는 이름만 · 레벨은 판 바깥 왼쪽(이어서 사용자 "이름테두리 바깥에 레벨표기입니다. 이 박스 안으로 들어오는게 아니라")
expect(W(longName, "small_o") <= 220, ("이름표 판 안의 이름 「%s」 %d점 — 220점 안"):format(longName, W(longName, "small_o")))
expect(W("Lv.200", "small_o") <= 80, "판 바깥의 레벨 「Lv.200」이 80점 안")

-- ⑤ 비석 면: 순위 번호(15점) · 이름 · 값(가장 넓은 값) — hallStones.luau와 같은 셈
local function stones(key: string)
	local out = {}
	for _, n in SCENES.scenes[key].npcs or {} do
		if n.stone and typeof(n.face) == "table" then
			table.insert(out, n)
		end
	end
	return out
end
local hall, castle = stones("in_hall"), stones("ct_castle")
eq(#hall, 3, "명예의 전당의 비석 셋")
eq(#castle, 3, "대영주의 성의 판 셋")
local boards = {}
for _, n in castle do
	boards[n.board] = true
end
expect(boards.robux and boards.power and boards.level, "성의 판 = 후원 · 전투력 · 레벨")
local VALUES = { "999,999", "99,999", "Lv.200" } -- 후원(로벅스) · 전투력 · 레벨의 넓은 값(후원 1,000만 이상이면 폰에서 이름이 여덟 자)
for _, n in hall do
	expect(n.face[3] - n.face[1] + 1 >= 80, n.id .. ": 비석 면의 폭 80점 이상(전에는 36)")
end
for _, ratio in { 2, 2.5 } do
	for _, set in { { hall, "명예의 전당", 8, 10 }, { castle, "대영주의 성", 3, 3 } } do
		for _, n in set[1] do
			local pad = n.pad or 3
			local w = (n.face[3] + 1 - n.face[1]) * ratio - pad * 2
			local h = (n.face[4] + 1 - n.face[2]) * ratio - pad * 2 - 1
			local rows = math.min(Rank.TOP, math.floor(h / 14))
			local want = if ratio == 2 then set[3] else set[4]
			expect(rows >= want, ("%s %s(배율 %.1f): 순위 %d줄 — %d줄 이상"):format(set[2], n.id, ratio, rows, want))
			local valueW = W(VALUES[if (n.board or n.id):find("robux") then 1 elseif (n.board or n.id):find("power") then 2 else 3])
			local nameW = w - 15 - valueW - 4
			local chars = 0
			for k = 1, 12 do
				if W(string.sub(longName, 1, k * 3)) <= nameW then
					chars = k
				end
			end
			local need = if ratio == 2.5 then 12 else 9
			expect(chars >= need, ("%s %s(배율 %.1f): 이름 자리 %d점 — 한글 %d자(%d자 이상)"):format(set[2], n.id, ratio, nameW, chars, need))
		end
	end
end

-- ⑦ 깨진 글(2026-10-21 퍼블리시한 게임의 오류 보고: pixelText:55 invalid UTF-8 code 554번)
do
	local broken = "가나" .. string.sub("다", 1, 2) -- 「다」의 앞 두 바이트만(반쪽 글자)
	expect(utf8.len(broken) == nil, "(반쪽 글자를 만들었다)")
	local okM, w = pcall(pixelText.Measure, broken, "small")
	expect(okM and typeof(w) == "number" and w > 0, "반쪽 글자가 있어도 폭을 잰다(오류 없이)")
	local fixed = pixelText.Clean(broken)
	expect(utf8.len(fixed) ~= nil and string.sub(fixed, 1, 6) == "가나", "반쪽 글자는 「?」로 — 앞의 글은 그대로: " .. fixed)
	eq(pixelText.Clean("달빛나그네"), "달빛나그네", "온전한 글은 그대로")
	local okF, fit = pcall(pixelText.Fit, broken .. "라마바사아자차카", 30, 1, "small")
	expect(okF and utf8.len(fit) ~= nil, "줄여도 온전한 글")
	-- 한글로 줄인 끝의 빈칸만 지운다(%s는 한글의 가운데 바이트를 빈칸으로 볼 수 있다)
	for _, name in { "은빛달토끼를좋아하는용사", "가나다라마바사아자차카타", "한글 이름 줄이기 시험" } do
		local f = pixelText.Fit(name, 40, 1, "small")
		expect(utf8.len(f) ~= nil and string.sub(f, -3) == "…", "줄인 이름이 온전한 글 — " .. f)
	end
	local Cash2 = req("ReplicatedStorage/shared/lune/sim/cash")
	eq(Cash2.couponCode(" dong geuli	"), "DONGGEULI", "쿠폰 번호의 빈칸 · 탭을 뺀다")
end

-- ⑥ 달빛 상점(2026-10-21 사용자: "달빛패스 일딴 비활성화해 그리고 달빛상점에서 펫은 펫 탭으로 따로 빼고 편의 가 아니라 그리고 지금 달빛상점 들어가면 ui가 너무 작아 모바일에서도 반응형")
do
	local SHOP = BM.shop
	local keys = {}
	for _, t in SHOP.tabs do
		keys[t[1]] = t[2]
	end
	eq(keys.pet, "펫", "「펫」 탭이 있다")
	eq(keys.pass, nil, "「패스」 탭은 없다(꺼 둠)")
	for _, q in RIDE.pets do
		if not q.free then
			expect(table.find(SHOP.rows.pet, q.id) ~= nil and table.find(SHOP.rows.conv, q.id) == nil, q.id .. ": 펫 탭에 있고 편의 탭에는 없다")
		end
	end
	local pass
	for _, p in BM.products do
		if p.id == "pass" then
			pass = p
		end
	end
	expect(pass ~= nil and not Cash.ready(pass), "달빛 패스는 살 수 없다(준비 중)")
	local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
	local SP = SHOP.space
	for _, c in { { 960, 540, 2, "PC 1080p" }, { 1152, 648, 1, "PC 1366x768" }, { 960, 540, 4, "PC 4K" }, { 768, 432, 0.9, "폰" }, { 768, 432, 1.6, "큰 폰 · 태블릿" } } do
		local L = Layout.shopSpace(c[1], c[2], c[3])
		local w, h = L.total * L.k, L.panelH * L.k
		expect(L.k >= 1.1, ("%s: 상점 묶음을 키운다(%.2f배)"):format(c[4], L.k))
		expect(L.x0 >= 0 and L.x0 + w <= c[1], ("%s: 가로가 화면 안(%d ~ %d / %d)"):format(c[4], L.x0, math.floor(L.x0 + w), c[1]))
		expect(L.y0 >= SP.topH and L.y0 + h <= c[2] - SP.bottom + 0.5, ("%s: 세로가 위 줄 아래 · 화면 안(%d ~ %d / %d)"):format(c[4], L.y0, math.floor(L.y0 + h), c[2]))
	end
	eq(Layout.shopSpace(960, 540, 2).k, 1.5, "1080p = 1.5배(한 점 3화소)")
end

-- ② 서버
local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = json(x)
	end
	return out
end
local disk = {}
local handlers, fired = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local names = {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return json(disk[id]) end,
	saveAccount = function(id, value)
		disk[id] = json(value)
		return true
	end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id)
		if names[key] ~= nil and names[key] ~= id then
			return false
		end
		names[key] = id
		return true
	end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, json(fn(nil)) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Coupons = req("ServerScriptService/server/lune/modules/coupons")
World.start()
local p = { UserId = 7001, Name = "user7001", DisplayName = "user7001", attrs = {} }
p.SetAttribute = function(self, k, v) self.attrs[k] = v end
p.Kick = function() end
handlers.Ready(p)
local made = handlers.Chars(p, "create", "쿠폰손님", "riven")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local code = Coupons.LIST[1].code
eq(Coupons.LIST[1].pet, "pet_crow", "처음의 쿠폰 = 기본펫")
local r = handlers.Coupon(p, string.lower(code))
expect(r and r.ok and r.pet == "pet_crow", "맞는 번호(작은 글자로 적어도)면 펫을 받는다")
expect(s.acct.bm.pets.pet_crow and s.acct.bm.petOut == "pet_crow", "계정에 들어오고 바로 꺼낸다")
expect(disk[p.UserId] and disk[p.UserId].bm and disk[p.UserId].bm.coupons and disk[p.UserId].bm.coupons[code] ~= nil, "바로 저장한다(쓴 쿠폰과 펫을 한 번에)")
local cashGot = false
for _, f in fired do
	cashGot = cashGot or (f.name == "CashGot" and f.args[1] == "pet_crow")
end
expect(cashGot, "화면에 알린다(가진 것을 다시 읽는다)")
local r2 = handlers.Coupon(p, code)
expect(r2 and not r2.ok and r2.why == "이미 쓴 쿠폰이다", "두 번째는 안 된다")
for i = 1, 5 do
	local bad = handlers.Coupon(p, "WRONG" .. i)
	expect(bad and not bad.ok and bad.why == "없는 쿠폰 번호다", "틀린 번호 " .. i)
end
local sixth = handlers.Coupon(p, "WRONG6")
expect(sixth and not sixth.ok and sixth.why == "잠시 뒤에 다시 적어 주세요", "틀린 번호는 1분에 다섯 번까지")
World.removePlayer(p)

-- 쓴 쿠폰의 보상을 지금의 목록에 맞춘다(쿠폰 펫을 바꿨다 — 사용자 "지금 내 테스트 계정에서 다시 쿠폰을 입력할수없어서 동글이는 사라지고, 재까마귀를 테스트할수도없어")
do
	local old = Account.new()
	old.bm.coupons[code] = 1000 -- 예전에 쓴 쿠폰(그때의 펫은 지금 없다)
	disk[7002] = json(Account.pack(old))
	local q = { UserId = 7002, Name = "user7002", DisplayName = "user7002", attrs = {} }
	q.SetAttribute = function(self, k, v) self.attrs[k] = v end
	q.Kick = function() end
	handlers.Ready(q)
	local sq = World.session(q)
	expect(sq.acct.bm.pets.pet_crow == true and sq.acct.bm.petOut == "pet_crow", "이미 쓴 쿠폰의 계정이 들어오면 지금의 쿠폰 펫(아기 재까마귀)을 받는다")
	expect(disk[7002].bm.pets and table.find(disk[7002].bm.pets, "pet_crow") ~= nil, "바로 저장한다")
	World.removePlayer(q)
end

-- 관리자의 「쿠폰 기록 지우기」(2026-10-21 사용자: "쿠폰 기록을 초기화해줘 쿠폰등록하는것부터 영상을찍어야해")
do
	local Admin = req("ServerScriptService/server/lune/modules/admin")
	local aid = next(Admin.IDS)
	local pa = { UserId = aid, Name = "admin", DisplayName = "admin", attrs = {} }
	pa.SetAttribute = function(self, k, v) self.attrs[k] = v end
	pa.Kick = function() end
	handlers.Ready(pa)
	local mk = handlers.Chars(pa, "create", "쿠폰영상", "axion")
	handlers.Chars(pa, "enter", mk.id)
	local sa = World.session(pa)
	expect(handlers.Coupon(pa, code).ok, "관리자도 쿠폰을 쓴다")
	expect(sa.acct.bm.pets.pet_crow and sa.acct.bm.petOut == "pet_crow", "쿠폰 펫을 받았다")
	sa.acct.bm.pets.pet_silver = true -- 산 펫은 지우지 않는다
	local res = handlers.Admin(pa, "coupons")
	expect(res and res.ok, "쿠폰 기록을 지운다 — " .. tostring(res and res.msg))
	expect(next(sa.acct.bm.coupons) == nil, "쓴 쿠폰이 없다")
	expect(not sa.acct.bm.pets.pet_crow and sa.acct.bm.petOut == false, "쿠폰 펫도 빠지고 꺼내 둔 것도 넣었다")
	expect(sa.acct.bm.pets.pet_silver == true, "산 펫은 그대로")
	expect(disk[aid] and (disk[aid].bm.coupons == nil or next(disk[aid].bm.coupons) == nil), "바로 저장한다")
	local again = handlers.Coupon(pa, code)
	expect(again and again.ok and sa.acct.bm.pets.pet_crow, "다시 처음부터 쿠폰을 쓸 수 있다")
	local np = { UserId = 7003, Name = "user7003", DisplayName = "user7003", attrs = {} }
	np.SetAttribute = function(self, k, v) self.attrs[k] = v end
	np.Kick = function() end
	handlers.Ready(np)
	local mk2 = handlers.Chars(np, "create", "보통손님", "riven")
	handlers.Chars(np, "enter", mk2.id)
	eq(handlers.Admin(np, "coupons"), nil, "관리자가 아니면 듣지 않는다")
	World.removePlayer(pa)
	World.removePlayer(np)
end
