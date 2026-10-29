-- 「달의 계승자」 — 관리 창 「정지」(2026-10-26 사용자: "클라 라는 닉네임 유저 찾아서 ip 까지 딴다음에 아예 게임못하게 정지시켜").
--  보는 것: ① 닉네임 → 이름 장부의 계정 번호 → 로블록스의 정지(BanAsync)를 영구 · 이 게임 모두 · 부계정까지로 건다 ② 풀기(UnbanAsync)
--   ③ 없는 닉네임 · 장부를 못 읽음 · 관리자의 계정은 정지하지 않는다 ④ 관리자가 아니면 서버가 듣지 않는다(정지가 걸리지 않는다)
--   ⑤ 창의 「정지」 탭을 진짜 글 칸 모양으로 짓고 눌러 본다(Ui.text에는 .frame이 없다 — 능력치 창 2026-10-26) · 글이 창 너비에 들어간다
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
local bans = {} -- 로블록스에 건 정지 { kind, config }
local refuse = false -- 로블록스가 받지 않는 때
SERVICE("Players", {
	PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end,
	BanAsync = function(_, config)
		if refuse then
			error("HTTP 500")
		end
		table.insert(bans, { kind = "ban", config = config })
	end,
	UnbanAsync = function(_, config)
		table.insert(bans, { kind = "unban", config = config })
	end,
	GetNameFromUserIdAsync = function(_, uid) return "robloxer" .. tostring(uid) end,
})
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, book = {}, {}
local bookBroken = false
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) if bookBroken then return false end return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local OWNER = 10311679477
local function join(uid, name)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "riven")
	handlers.Chars(p, "enter", made.id)
	return p
end
local pAdmin = join(OWNER, "달빛지기")
local pUser = join(9501, "보통사람")
book["클라"] = 9502 -- 정지할 사람(이 서버에 없다 — 정지는 로블록스가 모든 서버에서 쫓아낸다)

-- ① 정지
local got = handlers.Admin(pAdmin, "ban", "  클라 ", "ban")
expect(got and got.ok, "관리자가 「클라」를 정지했다 — " .. tostring(got and got.msg))
eq(#bans, 1, "로블록스의 정지를 한 번 걸었다")
local c = bans[1] and bans[1].config or {}
expect(bans[1] and bans[1].kind == "ban", "BanAsync")
expect(typeof(c.UserIds) == "table" and #c.UserIds == 1 and c.UserIds[1] == 9502, "닉네임 「클라」의 계정 번호(9502)를")
eq(c.Duration, -1, "영구(-1)")
eq(c.ApplyToUniverse, true, "이 게임의 모든 장소에서")
eq(c.ExcludeAltAccounts, false, "로블록스가 보는 부계정도 함께")
expect(typeof(c.DisplayReason) == "string" and c.DisplayReason ~= "" and utf8.len(c.DisplayReason) <= 400, "정지된 사람이 보는 글(400자까지)")
expect(typeof(c.PrivateReason) == "string" and c.PrivateReason:find("클라", 1, true) ~= nil, "기록용 글에 닉네임")
eq(got and got.uid, 9502, "대답에 계정 번호")
eq(got and got.roblox, "robloxer9502", "대답에 로블록스 이름")
-- 찾기만: 정지를 걸지 않는다
got = handlers.Admin(pAdmin, "ban", "클라", "find")
expect(got and got.ok and got.uid == 9502, "찾기: 누구인지 알려 준다")
eq(#bans, 1, "찾기는 정지를 걸지 않는다")
-- ② 풀기
got = handlers.Admin(pAdmin, "ban", "클라", "unban")
expect(got and got.ok and bans[2] and bans[2].kind == "unban" and bans[2].config.UserIds[1] == 9502 and bans[2].config.ApplyToUniverse == true, "풀기: UnbanAsync(이 게임 모두)")
-- ③ 안 되는 때
local n = #bans
got = handlers.Admin(pAdmin, "ban", "없는이름", "ban")
expect(got and not got.ok and got.msg:find("없다", 1, true) ~= nil, "없는 닉네임: 「없다」 — " .. tostring(got and got.msg))
got = handlers.Admin(pAdmin, "ban", "", "ban")
expect(got and not got.ok, "빈 닉네임")
got = handlers.Admin(pAdmin, "ban", 123, "ban")
expect(got and not got.ok, "글이 아닌 값")
got = handlers.Admin(pAdmin, "ban", "클라", "boom")
expect(got and not got.ok, "모르는 일")
bookBroken = true
got = handlers.Admin(pAdmin, "ban", "클라", "ban")
expect(got and not got.ok and got.msg:find("장부", 1, true) ~= nil, "이름 장부를 못 읽으면 걸지 않는다")
bookBroken = false
book["달빛지기"] = OWNER
got = handlers.Admin(pAdmin, "ban", "달빛지기", "ban")
expect(got and not got.ok and got.msg:find("관리자", 1, true) ~= nil, "관리자의 계정은 정지하지 않는다")
refuse = true
got = handlers.Admin(pAdmin, "ban", "클라", "ban")
expect(got and not got.ok, "로블록스가 받지 않으면 「다시」라고 답한다")
refuse = false
eq(#bans, n, "안 되는 때는 하나도 걸지 않았다")
-- ④ 관리자가 아닌 사람
got = handlers.Admin(pUser, "ban", "클라", "ban")
eq(got, nil, "관리자가 아니면 서버가 대답하지 않는다")
eq(#bans, n, "관리자가 아니면 정지가 걸리지 않는다")

-- ⑤ 창의 「정지」 탭
do
	local pixelText = req("Client/ui/pixelText")
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	pixelText.Register("small", KIT.font.small, {})
	pixelText.Register("body", KIT.font.body, {})
	local function frame(name)
		local f = { Name = name or "Frame" }
		function f:Destroy() self.destroyed = true end
		return f
	end
	local function strict(t, what)
		return setmetatable(t, { __index = function(_, k)
			error(("%s에 없는 칸 「%s」을 읽었다"):format(what, tostring(k)), 2)
		end })
	end
	local texts, buttons, tabClicks, fields = {}, {}, {}, {}
	local any = setmetatable({}, { __index = function() return "c" end })
	MOCK("Client/lune/ui/ui", {
		COLOR = any,
		measure = function(text, font) return (pixelText.Measure(text, font or "small")) end,
		group = function(_, _, _, _, _, name)
			local f = frame(name)
			if name == "Page" then
				table.clear(texts)
				table.clear(buttons)
			end
			return f
		end,
		line = function() return frame("Line") end,
		tab = function(_, text, _, _, onClick)
			tabClicks[text] = onClick
			local t = { width = (pixelText.Measure(text, "small")) }
			function t.setOn() end
			return t
		end,
		-- 진짜 Ui.text와 같은 모양(label · set · color · move · show · size)
		text = function(_, text, x, _, width)
			local it = { label = { Frame = frame("Text") }, value = text, x = x, width = width }
			function it.set(_, v) it.value = v end
			function it.color() end
			function it.move() end
			function it.show() end
			function it.size() return 40, 12 end
			table.insert(texts, it)
			return strict(it, "글 칸(Ui.text)")
		end,
		field = function(_, x, _, w)
			local f = frame("Input")
			f.Text, f.x, f.w = "", x, w
			f.FocusLost = signal()
			local onText = nil
			function f:GetPropertyChangedSignal() return { Connect = function(_, fn) onText = fn end } end
			function f.type(v)
				f.Text = v
				if onText then
					onText()
				end
			end
			table.insert(fields, f)
			return f
		end,
		button = function(_, text, x, _, w, onClick)
			table.insert(buttons, { text = text, x = x, w = w, click = onClick })
			return { frame = frame("Button") }
		end,
	})
	local AdminWindow = req("Client/lune/ui/adminWindow")
	local w, hgt = AdminWindow.size()
	local asked = {}
	local ctx = {
		me = function() return { level = 150, job = 4, admin = { xp = 1, dmg = 1, god = false } } end,
		admin = function(what, a, b)
			table.insert(asked, { what, a, b })
			return handlers.Admin(pAdmin, what, a, b)
		end,
	}
	local ok, view = pcall(AdminWindow.build, frame("Body"), ctx, w, hgt)
	expect(ok, "관리 창을 짓는다 — " .. tostring(view))
	-- 탭 줄이 창 너비에 들어간다(정지 탭까지 일곱)
	local tx = 0
	for _, t in AdminWindow.TABS do
		tx += (pixelText.Measure(t.name, "small")) + 16
	end
	expect(tx - 16 <= w, ("탭 일곱이 창 너비에 들어간다(%d / %d)"):format(tx - 16, w))
	expect(tabClicks["정지"] ~= nil, "「정지」 탭이 있다")
	if ok and tabClicks["정지"] then
		local ok2, err = pcall(tabClicks["정지"])
		expect(ok2, "「정지」 탭을 그린다 — " .. tostring(err))
		local function button(text)
			for _, b in buttons do
				if b.text == text then
					return b
				end
			end
			return nil
		end
		for _, name in { "찾기", "정지", "풀기" } do
			local b = button(name)
			expect(b ~= nil, "단추 「" .. name .. "」")
			if b then
				expect(pixelText.Measure(b.text, "small") <= b.w - 6 and b.x + b.w <= w, "단추가 들어간다 「" .. name .. "」")
			end
		end
		for _, it in texts do
			if it.width then
				expect((pixelText.Measure(it.value, "small")) <= it.width, ("글이 칸에 들어간다 「%s」(%d / %d)"):format(it.value, (pixelText.Measure(it.value, "small")), it.width))
			end
		end
		-- 적고 「정지」를 누른다 → 서버까지 → 다시 그린 탭에 그 사람이 적힌다
		local field = fields[#fields]
		field.type("클라")
		local before = #bans
		button("정지").click() -- (가짜 task.spawn은 바로 돈다 — 대답까지 이 안에서 끝난다)
		expect(asked[#asked] and asked[#asked][1] == "ban" and asked[#asked][2] == "클라" and asked[#asked][3] == "ban", "「정지」 = 서버에 (ban, 닉네임, ban)")
		eq(#bans, before + 1, "창에서 누른 정지가 로블록스에 걸렸다")
		local whoShown, doneShown = false, false
		for _, it in texts do
			whoShown = whoShown or (it.value:find("9502", 1, true) ~= nil)
			doneShown = doneShown or it.value == "영구 정지됨"
		end
		expect(whoShown, "정지한 사람의 계정 번호가 탭에 적힌다")
		expect(doneShown, "「영구 정지됨」이 적힌다")
		expect(fields[#fields].Text == "클라", "다시 그려도 적은 닉네임이 남는다")
		for _, it in texts do
			if it.width then
				expect((pixelText.Measure(it.value, "small")) <= it.width, ("정지한 뒤의 글도 칸에 들어간다 「%s」"):format(it.value))
			end
		end
		view.destroy()
	end
end
