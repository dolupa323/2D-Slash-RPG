-- 「달의 계승자」 — 쿠폰 탈것 「떠도는 책」(mount_book · 2026-10-21).
--  사용자: "간단한 탈것 하나 만들어볼래? 무료로뿌릴거고 쿠폰용이야 애니메이션 소요가 심하지않게 이미 있는 떠도는 책 몬스터에서 위에 플레이어가 타는형식으로
--   라이딩 만들고 이동속도는 유료보다 느리게 그냥 플레이어 이동속도로 만들어줘"
--  보는 것: ① 탈것 표(쿠폰 · 걷는 빠르기 1 — 유료 셋은 mountSpeed) ② 달빛 상점의 상품이 아니다 ③ 그림 = 몬스터 「떠도는 책」의 장 수 · 칸 크기 그대로 · 서기 · 뛰기 · 점프와 영웅 앞에 다시 그리는 것 · 아이콘
--   ④ 쿠폰의 셈(탈것을 받고 고른 것이 없으면 고른다 · 이미 고른 것은 그대로) ⑤ 서버(번호 → 탈것 · 저장 · 쓴 쿠폰을 지금의 목록에 맞춤 · 관리자의 쿠폰 기록 지우기가 탈것도 뺀다)
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Quick = req("ReplicatedStorage/shared/lune/ui/quick")

-- ① 탈것 표
local book = nil
for _, m in RIDE.mounts do
	if m.id == "mount_book" then
		book = m
	elseif not m.free then
		expect(m.speed == nil, m.id .. ": 유료 탈것은 따로 빠르기를 적지 않는다(mountSpeed)")
	end
end
expect(book ~= nil, "탈것 표에 「떠도는 책」")
eq(book.name, "떠도는 책", "이름")
eq(book.free, "coupon", "쿠폰으로만 받는다")
eq(book.speed, 1, "걷는 빠르기 그대로(빠르기 배수 1)")
expect(RIDE.mountSpeed > book.speed, ("유료 탈것(%.1f배)보다 느리다"):format(RIDE.mountSpeed))
expect(typeof(book.line) == "string" and book.line ~= "", "가방의 설명 한 줄")
expect(Cash.MOUNT.mount_book ~= nil, "서버의 탈것 표에도(타기 · 내리기)")
eq(Quick.ride("mount_book"), "mount", "퀵슬롯에 놓으면 탈것")

-- ② 상품이 아니다
for _, p in BM.products do
	expect(p.id ~= "mount_book", "달빛 상점의 상품이 아니다(쿠폰으로만)")
end
for _, ids in BM.shop.rows do
	expect(table.find(ids, "mount_book") == nil, "상점의 어느 탭에도 없다")
end

-- ③ 그림
do
	local mon, c = CHARS.chars.book, CHARS.chars.mount_book
	expect(c ~= nil, "탈것의 그림")
	eq(c.fw, mon.fw, "칸 폭 = 몬스터의 칸")
	eq(c.fh, mon.fh, "칸 높이 = 몬스터의 칸")
	eq(c.ox, mon.ox, "기준점(가로) = 몬스터의 것")
	expect(c.oy > mon.oy, "땅에서 띄운다(책갈피 끈이 땅에 끌리지 않게)")
	eq(c.size, CHARS.chars.mount_wolf.size, "다른 탈것과 같은 배율")
	for _, clip in { "idle", "run", "jump" } do
		expect(c.clips[clip] ~= nil and c.clips[clip .. "_front"] ~= nil, clip .. ": 탈것과 영웅 앞에 다시 그리는 것")
		eq(#c.clips[clip].frames, #mon.clips.idle.frames, clip .. ": 몬스터의 여섯 장")
		eq(#c.clips[clip .. "_front"].frames, #c.clips[clip].frames, clip .. ": 앞에 다시 그리는 것도 같은 장 수")
		-- 책 전체를 영웅 앞에(이어서 사용자 "책 라이딩 z인덱스가 플레이어가 더 높으면 안됩니다 . 책이 우선으로 보여져야해요"): 앞에 다시 그리는 장 = 탈것의 그 장(그림판의 같은 칸)
		for i, f in c.clips[clip].frames do
			eq(table.concat(c.clips[clip .. "_front"].frames[i], ","), table.concat(f, ","), ("%s %d장: 책 전체가 영웅 앞에"):format(clip, i))
		end
		for _, v in book.bob[clip] do
			eq(v, 0, clip .. ": 영웅이 흔들리지 않는다(세로)")
		end
		for _, v in book.bobx[clip] do
			eq(v, 0, clip .. ": 영웅이 흔들리지 않는다(가로)")
		end
	end
	expect(c.clips.run.fps > c.clips.idle.fps, "달릴 때 책장이 더 빨리 퍼덕인다")
	expect(book.seat.dy < 0, "영웅은 책 위에 앉는다")
end
expect(KIT.parts.icons.icons.ride_mount_book ~= nil and KIT.parts.pics.icons.ride_mount_book ~= nil, "아이콘 18점 · 24점")

-- ④ 쿠폰의 셈
do
	local acct = Account.new()
	local ok, got = Cash.redeem(acct, { code = "TESTBOOK", mount = "mount_book" }, 1000)
	expect(ok and got.mount == "mount_book" and got.pet == nil, "쓰면 탈것을 받는다")
	expect(acct.bm.mounts.mount_book == true and acct.bm.mount == "mount_book", "고른 탈것이 없으면 그것을 고른다")
	expect(acct.bm.petOut == false, "펫은 그대로(없다)")
	local acct2 = Account.new()
	acct2.bm.mounts.mount_wolf, acct2.bm.mount = true, "mount_wolf"
	expect(Cash.redeem(acct2, { code = "TESTBOOK", mount = "mount_book" }, 1000), "다른 계정도 쓴다")
	eq(acct2.bm.mount, "mount_wolf", "이미 고른 탈것은 그대로")
	local bad, why = Cash.redeem(Account.new(), { code = "NOPE", mount = "mount_none" }, 1000)
	expect(not bad and why == "없는 탈것이다", "없는 탈것이면 쓰지 않는다")
	local back = Cash.unpack(Cash.pack(acct.bm), Account.MAX)
	expect(back.mounts.mount_book == true and back.mount == "mount_book", "받은 탈것이 저장된다")
end

-- ⑤ 서버
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
local Admin = req("ServerScriptService/server/lune/modules/admin")
World.start()
local code = nil
for _, def in Coupons.LIST do
	if def.mount == "mount_book" then
		code = def.code
	end
end
expect(code ~= nil, "「떠도는 책」을 주는 쿠폰 번호가 있다")
expect(Cash.couponCode(code) == code, "번호의 꼴(대문자 · 숫자 · 24자 안) — " .. tostring(code))
local function person(id: number, name: string)
	local p = { UserId = id, Name = "u" .. id, DisplayName = "u" .. id, attrs = {} }
	p.SetAttribute = function(self, k, v) self.attrs[k] = v end
	p.Kick = function() end
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "riven")
	handlers.Chars(p, "enter", made.id)
	return p, World.session(p)
end
local p, s = person(7201, "책타는손님")
local r = handlers.Coupon(p, string.lower(code))
expect(r and r.ok and r.mount == "mount_book", "맞는 번호면 탈것을 받는다 — " .. tostring(r and r.why))
expect(s.acct.bm.mounts.mount_book and s.acct.bm.mount == "mount_book", "계정에 들어오고 고른 탈것이 된다")
expect(disk[p.UserId] and disk[p.UserId].bm.mounts and table.find(disk[p.UserId].bm.mounts, "mount_book") ~= nil, "바로 저장한다")
local cashGot = false
for _, f in fired do
	cashGot = cashGot or (f.name == "CashGot" and f.player == p and f.args[1] == "mount_book")
end
expect(cashGot, "화면에 알린다(가진 것을 다시 읽는다)")
local r2 = handlers.Coupon(p, code)
expect(r2 and not r2.ok and r2.why == "이미 쓴 쿠폰이다", "두 번째는 안 된다")
local rideRes = handlers.Cash(p, "ride", "mount_book")
expect(rideRes and rideRes.ok and rideRes.riding and s.riding == true, "받은 탈것에 탄다")
local off = handlers.Cash(p, "ride", false)
expect(off and off.ok and not off.riding, "내린다")
World.removePlayer(p)

-- 쓴 쿠폰을 지금의 목록에 맞춘다(쿠폰의 탈것이 없는 계정)
do
	local old = Account.new()
	old.bm.coupons[code] = 1000
	disk[7202] = json(Account.pack(old))
	local q = { UserId = 7202, Name = "u7202", DisplayName = "u7202", attrs = {} }
	q.SetAttribute = function(self, k, v) self.attrs[k] = v end
	q.Kick = function() end
	handlers.Ready(q)
	local sq = World.session(q)
	expect(sq.acct.bm.mounts.mount_book == true and sq.acct.bm.mount == "mount_book", "쓴 쿠폰의 탈것이 없으면 넣어 준다")
	World.removePlayer(q)
end

-- 관리자의 「쿠폰 기록 지우기」가 쿠폰 탈것도 뺀다(산 탈것은 그대로)
do
	local pa = { UserId = next(Admin.IDS), Name = "admin", DisplayName = "admin", attrs = {} }
	pa.SetAttribute = function(self, k, v) self.attrs[k] = v end
	pa.Kick = function() end
	handlers.Ready(pa)
	local mk = handlers.Chars(pa, "create", "책영상", "axion")
	handlers.Chars(pa, "enter", mk.id)
	local sa = World.session(pa)
	expect(handlers.Coupon(pa, code).ok, "관리자도 쿠폰을 쓴다")
	sa.acct.bm.mounts.mount_deer = true -- 산 탈것
	local res = handlers.Admin(pa, "coupons")
	expect(res and res.ok and string.find(res.msg or "", "탈것", 1, true) ~= nil, "쿠폰 기록을 지운다 — " .. tostring(res and res.msg))
	expect(not sa.acct.bm.mounts.mount_book and sa.acct.bm.mount == false, "쿠폰 탈것이 빠지고 고른 것도 풀린다")
	expect(sa.acct.bm.mounts.mount_deer == true, "산 탈것은 그대로")
	local again = handlers.Coupon(pa, code)
	expect(again and again.ok and sa.acct.bm.mounts.mount_book, "다시 처음부터 쿠폰을 쓸 수 있다")
	World.removePlayer(pa)
end
