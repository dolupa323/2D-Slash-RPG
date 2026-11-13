-- 「달의 계승자」 — 잃은 이름 되돌리기(2026-11-11 밤 — 사용자: "LaNu 라는 닉네임을 원래 가지고있던사람이 닉네임이 지금 이름짓기인데 닉네임 뺏겨서 LaNu 라는 닉네임이 유실된이후에 되찾지못하고있어").
--  server world.luau World.nameRestore(들어와 계정을 읽은 뒤): NAME_RESTORE의 사람 · 캐릭터의 이름이 비어 있으면 처음 지었던 이름으로(Roblox 글 거르기는 다시 묻지 않는다 — 지을 때 거른 이름).
--  보는 것: ① 이름이 비어 있으면 되돌리고 장부에 적고 저장한다 ② 장부의 그 이름이 남의 것이면 되돌리지 않는다 ③ 이미 이름이 있으면 그대로 ④ 목록에 없는 사람은 아무 일 없다
--   ⑤ 되돌린 캐릭터로 들어갈 수 있다(「이름을 먼저 지어야 합니다」가 아니다)
--  2026-11-12 사용자 "LaNu 아직 닉네임 되찾지못하는데?" — 더 보는 것: ⑥ Ready가 보내는 고르기 화면의 목록에 이미 LaNu가 있다(전에는 되돌리기 전에 목록이 갈 수 있었다)
--   ⑦ 캐릭터 번호가 맞지 않아도 이름이 빈 같은 직업 · 가장 높은 레벨의 캐릭터에 ⑧ 그 사람이 「이름 짓기」로 LaNu를 적으면 Roblox 거르기가 가려도 지어진다(남은 안 된다)
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Account = req("ReplicatedStorage/shared/lune/sim/account")

local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
	FireAllClients = function() end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
-- (Roblox 거르기는 「LaNu」를 가린다 — 운영에서 그랬다: S407)
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return if string.lower(text) == "lanu" then "####" else text end } end })
local disk, names, saved = {}, {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; saved[id] = (saved[id] or 0) + 1; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return if names[key] then names[key].u else nil end,
	claimName = function(key, id) if claimFail then claimFail = false return nil end if names[key] and names[key].u ~= id then return false end names[key] = { u = id }; return true end, -- claimFail = 한 번 장부를 열지 못한다(⑧)
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	firstMaxGet = function() return nil end, firstMaxClaim = function(rec) return true, rec end,
})
claimFail = false
local World = req("ServerScriptService/server/lune/modules/world")
World.start()

-- 저장된 계정 하나(이름이 빈 1번 캐릭터 — 옛 코드가 지운 꼴)를 만든다
local function account(uid, cname)
	local acct = Account.new()
	local h = Hero.new(uid, "reaper")
	h.level = 141
	local data = Hero.pack(h)
	data.bag.store = nil
	local c = Account.add(acct, "임시", "reaper", data, 1)
	c.name = cname
	return Account.pack(acct)
end
local function player(uid)
	return { UserId = uid, Name = "p" .. uid, DisplayName = "p" .. uid, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
end

-- ① 이름이 비어 있다 → 되돌린다
local target = next(World.NAME_RESTORE)
local want = World.NAME_RESTORE[target][1]
eq(want.name, "LaNu", "되돌릴 이름 = LaNu")
disk[target] = account(target, "")
local p1 = player(target)
local ready = handlers.Ready(p1)
local s1 = World.session(p1)
-- ⑥ 고르기 화면의 목록
local listed = nil
for _, v in (ready and ready.select and ready.select.chars) or {} do
	if v.id == want.cid then
		listed = v.name
	end
end
eq(listed, "LaNu", "Ready가 보낸 고르기 화면의 목록에 이미 LaNu(「이름 짓기」가 아니다)")
local c1 = s1 and Account.find(s1.acct, want.cid)
eq(c1 and c1.name, "LaNu", "들어오자 1번 캐릭터의 이름이 LaNu로 돌아왔다")
eq(names[Account.nameKey("LaNu")] and names[Account.nameKey("LaNu")].u, target, "장부의 lanu = 그 사람")
expect((saved[target] or 0) >= 1, "저장했다")
-- ⑤ 그 캐릭터로 들어간다
local res = handlers.Chars(p1, "enter", want.cid)
expect(res ~= nil and (res.ok ~= false), "되돌린 캐릭터로 들어갈 수 있다 — " .. tostring(res and res.why))
World.removePlayer(p1)

-- ② 장부의 lanu가 남의 것 → 되돌리지 않는다
disk[target] = account(target, "")
names[Account.nameKey("LaNu")] = { u = 1234567 }
local p2 = player(target)
handlers.Ready(p2)
local s2 = World.session(p2)
eq(Account.find(s2.acct, want.cid).name, "", "장부의 이름이 남의 것이면 비운 채로 둔다")
eq(names[Account.nameKey("LaNu")].u, 1234567, "남의 장부는 그대로")
World.removePlayer(p2)

-- ③ 이미 이름이 있다 → 그대로
names[Account.nameKey("LaNu")] = nil
disk[target] = account(target, "새이름")
local p3 = player(target)
handlers.Ready(p3)
eq(Account.find(World.session(p3).acct, want.cid).name, "새이름", "이미 지은 이름은 그대로")
eq(names[Account.nameKey("LaNu")], nil, "장부에 적지 않는다")
World.removePlayer(p3)

-- ④ 목록에 없는 사람
disk[777001] = account(777001, "")
local p4 = player(777001)
handlers.Ready(p4)
eq(Account.find(World.session(p4).acct, 1).name, "", "목록에 없는 사람의 빈 이름은 그대로(스스로 짓는다)")
World.removePlayer(p4)

-- ⑦ 번호가 맞지 않는다: 1번은 다른 이름의 무니 · 이름이 빈 리퍼(Lv.141)는 2번 · 이름이 빈 리퍼(Lv.5)는 3번 → 2번에
do
	names[Account.nameKey("LaNu")] = nil
	local acct = Account.new()
	local function add(cls, lv, nm)
		local h = Hero.new(target, cls)
		h.level = lv
		local data = Hero.pack(h)
		data.bag.store = nil
		local c = Account.add(acct, "임시", cls, data, 1)
		c.name = nm
		return c
	end
	add("mooni", 60, "다른캐릭")
	local big = add("reaper", 141, "")
	add("reaper", 5, "")
	disk[target] = Account.pack(acct)
	local p7 = player(target)
	handlers.Ready(p7)
	local s7 = World.session(p7)
	eq(Account.find(s7.acct, big.id).name, "LaNu", "이름이 빈 리퍼 가운데 Lv.141(" .. big.id .. "번)에 되돌렸다")
	eq(Account.find(s7.acct, 1).name, "다른캐릭", "이름이 있는 1번은 그대로")
	World.removePlayer(p7)
end

-- ⑧ 들어올 때 장부를 열지 못해 되돌리지 못했다 → 그 사람이 「이름 짓기」로 LaNu를 적는다(Roblox 거르기는 가리지만 지어진다) · 남은 같은 이름을 못 짓는다
do
	names[Account.nameKey("LaNu")] = nil
	disk[target] = account(target, "")
	claimFail = true
	local p8 = player(target)
	handlers.Ready(p8)
	local s8 = World.session(p8)
	eq(Account.find(s8.acct, want.cid).name, "", "장부를 열지 못해 이번에는 되돌리지 못했다")
	local chk = handlers.Chars(p8, "check", "LaNu")
	expect(chk and chk.ok, "이름 확인: 그 사람에게는 LaNu가 된다 — " .. tostring(chk and chk.why))
	local r8 = handlers.Chars(p8, "name", want.cid, "LaNu")
	expect(r8 and r8.ok, "「이름 짓기」로 LaNu를 지었다 — " .. tostring(r8 and r8.why))
	eq(Account.find(s8.acct, want.cid).name, "LaNu", "이름이 LaNu")
	World.removePlayer(p8)
	-- 남(목록에 없는 사람)은 Roblox 거르기가 가린 이름을 못 짓는다
	names[Account.nameKey("LaNu")] = nil
	disk[777002] = account(777002, "")
	local p9 = player(777002)
	handlers.Ready(p9)
	local r9 = handlers.Chars(p9, "name", 1, "LaNu")
	expect(r9 and not r9.ok, "남은 LaNu를 못 짓는다(거르기) — " .. tostring(r9 and r9.why))
	World.removePlayer(p9)
end
