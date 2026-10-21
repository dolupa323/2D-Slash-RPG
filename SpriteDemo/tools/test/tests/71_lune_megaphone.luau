-- 「달의 계승자」 — 관리자의 확성기(server/lune/modules/megaphone.luau · world.luau onAdmin "megaphone" · 2026-10-21).
--  사용자: "로블록스는 서버가 여러개가 돌아가는 구조잖아 내가 모든 서버에 확성기로 말할수있나? 어드민기능으로 확성기같은게 필요한데"
--  보는 것: ① 글 고르기(빈 글 · 80자 넘음 · 줄바꿈) ② 관리자가 보내면 글을 거른 뒤 이 서버의 모두에게(캐릭터 고르기 화면의 사람도) · 다른 서버로 보낸다(MessagingService)
--   ③ 보낸 서버로 되돌아온 소식은 다시 띄우지 않는다 · 다른 서버에서 온 소식은 띄운다 ④ 5초에 한 번 ⑤ 관리자가 아니면 듣지 않는다
local PACKETS = req("ReplicatedStorage/shared/lune/net/packets")
local packets = PACKETS.list or PACKETS
expect(packets.Megaphone ~= nil and packets.Megaphone.Direction == "ServerToClient", "확성기 패킷(서버 → 화면)")

local handlers, fired, published = {}, {}, {}
local subscribed = nil
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
SERVICE("MessagingService", {
	PublishAsync = function(_, topic, data)
		table.insert(published, { topic = topic, data = data })
	end,
	SubscribeAsync = function(_, topic, fn)
		if topic == "LuneMegaphone" then
			subscribed = fn
		end
	end,
})
SERVICE("HttpService", { GenerateGUID = (function()
	local n = 0
	return function()
		n += 1
		return "id-" .. n
	end
end)() })
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return (string.gsub(text, "나쁜말", "####")) end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Admin = req("ServerScriptService/server/lune/modules/admin")
local Megaphone = req("ServerScriptService/server/lune/modules/megaphone")
World.start()
expect(subscribed ~= nil, "다른 서버의 소식을 듣는다(MessagingService · LuneMegaphone)")

-- ① 글 고르기
eq((Megaphone.clean("  점검 안내  ")), "점검 안내", "앞뒤 빈칸을 뺀다")
eq((Megaphone.clean("한 줄\n두 줄")), "한 줄 두 줄", "줄바꿈은 빈칸으로")
local none, whyEmpty = Megaphone.clean("   ")
expect(none == nil and whyEmpty ~= nil, "빈 글은 보내지 않는다")
local long, whyLong = Megaphone.clean(string.rep("가", Megaphone.MAX + 1))
expect(long == nil and string.find(whyLong or "", tostring(Megaphone.MAX)) ~= nil, "80자를 넘으면 보내지 않는다 — " .. tostring(whyLong))
expect(Megaphone.clean(string.rep("가", Megaphone.MAX)) ~= nil, "80자는 보낸다")
expect(Megaphone.clean("가나" .. string.sub("다", 1, 2)) == nil, "깨진 글은 보내지 않는다")

local function person(id: number, name: string?)
	local p = { UserId = id, Name = "u" .. id, DisplayName = "u" .. id, attrs = {} }
	p.SetAttribute = function(self, k, v) self.attrs[k] = v end
	p.Kick = function() end
	handlers.Ready(p)
	if name then
		local made = handlers.Chars(p, "create", name, "riven")
		handlers.Chars(p, "enter", made.id)
	end
	return p
end
local admin = person(next(Admin.IDS), "확성기시험")
local other = person(7101, "듣는사람")
local lobby = person(7102) -- 캐릭터 고르기 화면에 있는 사람
local function heard(p)
	local out = {}
	for _, f in fired do
		if f.name == "Megaphone" and f.player == p then
			table.insert(out, f.args[1])
		end
	end
	return out
end

-- ② 보낸다
local r = handlers.Admin(admin, "megaphone", "오늘 밤 9시에 점검합니다 나쁜말")
expect(r and r.ok and r.msg == "모든 서버에 보냈다", "보냈다 — " .. tostring(r and r.msg))
for _, p in { admin, other, lobby } do
	local got = heard(p)
	eq(#got, 1, p.Name .. ": 한 번 받는다")
	eq(got[1], "오늘 밤 9시에 점검합니다 ####", p.Name .. ": 거른 글을 받는다")
end
eq(#published, 1, "다른 서버로 한 번 보낸다")
eq(published[1].topic, "LuneMegaphone", "확성기의 주제")
eq(published[1].data.text, "오늘 밤 9시에 점검합니다 ####", "다른 서버로도 거른 글")
-- ③ 되돌아온 소식 · 다른 서버의 소식
subscribed({ Data = published[1].data })
eq(#heard(other), 1, "보낸 서버로 되돌아온 소식은 다시 띄우지 않는다")
subscribed({ Data = { id = "other-server-1", text = "다른 서버의 공지" } })
eq(heard(other)[2], "다른 서버의 공지", "다른 서버에서 온 소식은 띄운다")
subscribed({ Data = { id = "other-server-1", text = "다른 서버의 공지" } })
eq(#heard(other), 2, "같은 소식이 두 번 와도 한 번만")
subscribed({ Data = { text = "번호 없는 소식" } })
eq(#heard(other), 2, "꼴이 이상한 소식은 버린다")
-- ④ 5초에 한 번
local again = handlers.Admin(admin, "megaphone", "한 번 더")
expect(again and not again.ok and string.find(again.msg or "", "초 뒤") ~= nil, "5초 안에 다시 보내지 못한다 — " .. tostring(again and again.msg))
-- ⑤ 관리자가 아니면
eq(handlers.Admin(other, "megaphone", "몰래 공지"), nil, "관리자가 아니면 듣지 않는다")
eq(#published, 1, "(보내지 않았다)")
for _, p in { admin, other, lobby } do
	World.removePlayer(p)
end

-- 큰 알림(client guide.luau — Guide.BANNER_W 480점 · 두 줄)에 80자가 들어간다(채팅에는 다 보인다)
do
	local BANNER_W = 480 -- guide.luau의 Guide.BANNER_W(guide는 화면 모듈을 줄줄이 불러서 여기서 부르지 않는다)
	local pixelText = req("Client/ui/pixelText")
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	pixelText.Register("small_o", KIT.font.small_o, {})
	for _, text in { string.rep("가", Megaphone.MAX), string.rep("점검 안내 ", 16) } do
		local cut = text
		local n = utf8.len(cut) :: number
		if n > Megaphone.MAX then
			cut = string.sub(cut, 1, (utf8.offset(cut, Megaphone.MAX + 1) :: number) - 1)
		end
		local fit = pixelText.Fit(cut, BANNER_W, 2, "small_o")
		expect(string.sub(fit, -3) ~= "…", ("80자가 큰 알림 두 줄에 들어간다(%d자)"):format(utf8.len(cut) :: number))
	end
end
