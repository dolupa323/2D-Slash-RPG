-- 「달의 계승자」 — 캐시 무기(2026-10-23 — 공방 design/wskin.js · bm.js의 wskin_* · shared sim/cash.luau · server world.luau의 Cash "wskin" · client weaponFx.luau).
--  사용자: "캐쉬 무기를 만들어보자 멋지게 가능해?" → 제안 ① 무기 재질 ② 피어오르는 점 ③ 공격할 때의 색 가운데 "1,2 적용"
--  보는 것: ① 자료(테마 넷 · 판 · 점의 움직임 · 영웅의 장마다 무기 자리) ② 상품(꾸밈 탭 · 699 / 799 · 번호 · 계정 · 거래 안 됨) ③ 사면 계정에 · 바로 장착 · 해제 · 다른 것으로 · 저장
--   ④ 서버: 장착하면 방 사람들에게(Who의 wskin) · 가진 것만 장착
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local DYE = req("ReplicatedStorage/shared/lune/data/dye.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")

-- ① 자료
eq(#DYE.skins, 4, "테마 넷(황금 · 용암 · 서리 · 그림자)")
for _, q in DYE.skins do
	expect(typeof(q.page) == "string" and string.sub(q.page, 1, 6) == "wskin_", q.id .. ": 무기 재질의 판")
	expect(q.fx and q.fx.rate > 0 and q.fx.life > 0 and #q.fx.colors >= 1, q.id .. ": 피어오르는 점의 움직임")
end
expect(DYE.skinMax and DYE.skinMax > 0, "한 영웅 둘레의 점 상한")
for _, q in DYE.skins do
	if q.id == "wskin_gold" then
		expect(q.fx.plus == true and q.fx.twinkle == true, "황금 무기: 반짝이는 + 모양 별")
	end
	expect(q.fx.plus == nil or type(q.fx.plus) == "boolean", q.id .. ": plus는 켜고 끄는 값")
end
do
	local withSpots, heroFrames = 0, 0
	for _, cls in CLASSES.order do
		for _, clip in CHARS.chars[cls].clips do
			for _, f in clip.frames do
				if f and f[8] then
					heroFrames += 1
					local sp = DYE.spots[f[8] .. "," .. f[9]]
					if sp then
						withSpots += 1
						expect(#sp % 2 == 0 and #sp >= 2, "자리는 x, y의 짝")
						for i = 1, #sp, 2 do
							if sp[i] < 0 or sp[i] >= f[4] or sp[i + 1] < 0 or sp[i + 1] >= f[5] then
								expect(false, ("자리 (%d, %d)가 장(%dx%d) 밖"):format(sp[i], sp[i + 1], f[4], f[5]))
							end
						end
					end
				end
			end
		end
	end
	expect(withSpots >= heroFrames * 0.8, ("영웅의 장 대부분에 무기 자리가 있다(%d / %d — 무기가 가려진 장은 없다)"):format(withSpots, heroFrames))
end

-- ② 상품
for _, q in DYE.skins do
	local p = Cash.product(q.id)
	local price = ({ wskin_gold = 699, wskin_lava = 799, wskin_frost = 699, wskin_shadow = 799 })[q.id] -- 사용자가 대시보드에 올린 값(10-23)
	expect(p ~= nil and p.kind == "product" and p.robux == price, q.id .. ": 개발자 상품 · " .. tostring(price))
	expect(p and Cash.ready(p) == true, q.id .. ": 상품 번호가 들어가 「구매」(10-23)")
	expect(p and p.trade == false and p.built == true, q.id .. ": 계정 · 거래 안 됨 · 게임에 만들어 둔 것")
	expect(table.find(BM.shop.rows.look, q.id) ~= nil, q.id .. ": 달빛 상점 「꾸밈」 탭")
end
expect(BM.shop.words.skinOn == "장착" and BM.shop.words.skinOff == "해제", "가방 캐시 탭의 단추 「장착」 · 「해제」(~다 아님)")

-- ③ 계정
local acct = Account.new()
expect(Cash.grant(acct, "wskin_lava", "r-ws-1", os.time(), 6, nil), "용암 무기를 샀다")
expect(acct.bm.wskins.wskin_lava == true, "계정에 들어왔다")
eq(acct.bm.wskin, "wskin_lava", "사면 바로 장착")
expect(Cash.setWskin(acct, "wskin_gold") == nil, "가지지 않은 것은 장착하지 못한다")
expect(Cash.setWskin(acct, false) == true and acct.bm.wskin == false, "해제")
expect(Cash.grant(acct, "wskin_frost", "r-ws-2", os.time(), 6, nil), "서리 무기도 샀다")
eq(acct.bm.wskin, "wskin_frost", "새로 산 것이 장착된다")
expect(Cash.setWskin(acct, "wskin_lava") == true and acct.bm.wskin == "wskin_lava", "가진 다른 것으로 바꾼다")
local v = Cash.view(acct, os.time(), nil, 1, {})
eq(#v.wskins, 2, "상점 상태에 가진 캐시 무기 둘")
eq(v.wskin, "wskin_lava", "상점 상태에 장착한 것")
for _, row in v.list do
	if row.id == "wskin_lava" then
		expect(row.own == true, "상점에 「보유」")
	end
end
local back = Cash.unpack(Cash.pack(acct.bm))
expect(back.wskins.wskin_lava and back.wskins.wskin_frost and back.wskin == "wskin_lava", "저장하고 다시 읽어도 그대로")
local bad = Cash.unpack({ wskins = { "wskin_rainbow", "wskin_gold" }, wskin = "wskin_rainbow" })
expect(bad.wskins.wskin_rainbow == nil and bad.wskins.wskin_gold == true and bad.wskin == false, "모르는 것 · 가지지 않은 것은 버린다")

-- ④ 서버
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
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
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
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
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function join(uid, name, cls)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, val) self.attrs[k] = val end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	World.jump(p, "town")
	return p, World.session(p)
end
local p, s = join(8110, "캐시무기", "reaper")
local p2 = join(8111, "구경꾼둘", "mooni")
local r0 = handlers.Cash(p, "wskin", "wskin_gold")
expect(r0 and not r0.ok, "가지지 않은 것은 장착하지 못한다(서버)")
s.acct.bm.wskins.wskin_shadow = true
table.clear(sent)
local r1 = handlers.Cash(p, "wskin", "wskin_shadow")
expect(r1 and r1.ok and r1.wskin == "wskin_shadow", "장착했다(서버)")
local seen = false
for _, f in sent do
	if f.name == "Who" and f.player == p2 then
		for _, w in f.args[2] do
			if w.id == s.hero.id and w.wskin == "wskin_shadow" then
				seen = true
			end
		end
	end
end
expect(seen, "같은 마을의 다른 사람에게 그 캐시 무기가 간다(Who의 wskin)")
local r2 = handlers.Cash(p, "wskin", false)
expect(r2 and r2.ok and s.acct.bm.wskin == false, "해제(서버)")
World.removePlayer(p2)
World.removePlayer(p)
