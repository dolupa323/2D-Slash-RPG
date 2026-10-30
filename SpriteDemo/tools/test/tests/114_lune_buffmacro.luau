-- 「달의 계승자」 — 시퀀스(2026-10-30 사용자: "버프를 한버튼에 배치해서 한 버튼만 눌러서 버프를 사용할수있는 시퀀스 기능 … 메이플에 이미 있는 기능" → "버프 매크로가 아니라고 내가 시퀀스라고 말했잖아").
--  (파일 이름은 처음 만든 「버프 매크로」의 것 그대로 — 지금은 시퀀스를 본다)
--  보는 것: ① 셈(sim/sequence.luau — 가지 · 번호 · 넣을 수 있는 것 · 거르기) ② 캐릭터(sim/hero.luau — 처음 · 바꾸기 · 퀵슬롯에 놓기 · 저장 → 읽기 · 내 상태)
--   ③ 퀵슬롯(ui/quick.luau — 칸의 그림 = 첫 칸 · 구석의 「S1」 · 「B1」) ④ 시퀀스 창(client ui/seqWindow.luau — 짓고 · 탭 · 넣고 · 빼고 · 비우고 · 퀵슬롯에 놓기) ⑤ 스킬 창의 「시퀀스」 단추
--  (같은 폴더의 macro.luau = 「매크로 확인」(매크로 사용자 잡기) — 다른 것이다)
local Seq = req("ReplicatedStorage/shared/lune/sim/sequence")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Quick = req("ReplicatedStorage/shared/lune/ui/quick")

-- ① 셈 — 메이플의 수: 스킬 시퀀스 10개 · 버프 시퀀스 5개 · 됐으면 0.12초 · 안 됐으면 0.03초
eq(Seq.N.skill, 10, "스킬 시퀀스 열")
eq(Seq.N.buff, 5, "버프 시퀀스 다섯")
eq(Seq.SIZE.skill, 15, "스킬 시퀀스 하나에 열다섯 칸")
eq(Seq.DATA.ok, 0.12, "걸렸으면 0.12초 뒤 다음")
eq(Seq.DATA.fail, 0.03, "안 걸렸으면 0.03초 뒤 다음")
eq(Seq.id("skill", 2), "seq_2", "스킬 시퀀스의 이름표")
eq(Seq.id("buff", 3), "bseq_3", "버프 시퀀스의 이름표")
local k1, n1 = Seq.of("seq_10")
local k2, n2 = Seq.of("bseq_5")
expect(k1 == "skill" and n1 == 10 and k2 == "buff" and n2 == 5, "이름표 → 가지 · 번호")
expect(Seq.of("seq_11") == nil and Seq.of("bseq_6") == nil and Seq.of("macro_1") == nil and Seq.of(nil) == nil and Seq.of("ax_roar") == nil, "시퀀스가 아닌 것")
eq(Seq.name("skill", 3), "스킬 시퀀스 3", "이름")

local h = Hero.new(1, "axion")
Hero.setLevel(h, 150, Hero.jobAt(150))
Hero.maxSkills(h)
local cands = Seq.candidates(h, "skill")
expect(#cands >= 4 and table.find(cands, "ax_roar") ~= nil and table.find(cands, "ax_breath") ~= nil, "스킬 시퀀스에 넣을 것 = 배운 바로 걸리는 버프(" .. table.concat(cands, ",") .. ")")
expect(not Seq.can(h, "skill", "ax_wheel") and not Seq.can(h, "skill", "ax_pulse"), "공격 · 쓰는 동작이 있는 스킬은 넣지 못한다")
expect(not Seq.can(h, "skill", "bm_exp"), "스킬 시퀀스에 아이템은 넣지 못한다")
local bcands = Seq.candidates(h, "buff")
expect(bcands[1] == "bm_exp" and bcands[2] == "bm_drop", "버프 시퀀스에 넣을 것 = 경험치 · 드롭률 쿠폰이 먼저(" .. table.concat(bcands, ",") .. ")")
for _, id in bcands do
	expect(id == "bm_exp" or id == "bm_drop" or string.sub(id, 1, 2) == "c_", "버프 시퀀스의 스킬은 공용 버프만 — " .. id)
end
expect(not Seq.can(h, "buff", "ax_roar"), "버프 시퀀스에 직업 버프는 넣지 못한다(그것은 스킬 시퀀스)")
local fresh = Hero.new(2, "axion")
expect(not Seq.can(fresh, "skill", "ax_roar"), "배우지 않은 버프는 넣지 못한다")
expect(Seq.can(fresh, "buff", "bm_exp"), "쿠폰은 가지지 않아도 넣어 둔다(메이플의 버프 매니저처럼)")
local one = Seq.cleanOne(h, "skill", { "ax_roar", "ax_roar", "ax_wheel", "ax_breath" })
expect(one ~= nil and table.concat(one, ",") == "ax_roar,ax_breath", "겹친 것 · 넣을 수 없는 것은 빠진다")
expect(Seq.cleanOne(h, "skill", "x") == nil and Seq.cleanOne(h, "skill", { 3 }) == nil and Seq.cleanOne(h, "nope", {}) == nil, "꼴이 틀리면 받지 않는다")

-- ② 캐릭터
expect(typeof(h.seqs) == "table" and #h.seqs.skill == 10 and #h.seqs.buff == 5 and #h.seqs.skill[1] == 0, "새 캐릭터 = 빈 시퀀스(스킬 10 · 버프 5)")
expect(Hero.setSeq(h, "skill", 1, { "ax_roar", "ax_breath" }), "스킬 시퀀스 1을 바꾼다")
expect(Hero.setSeq(h, "buff", 2, { "bm_drop", "bm_exp" }), "버프 시퀀스 2를 바꾼다")
eq(table.concat(h.seqs.skill[1], ","), "ax_roar,ax_breath", "넣은 차례 그대로")
eq(table.concat(h.seqs.buff[2], ","), "bm_drop,bm_exp", "버프도 넣은 차례 그대로")
expect(not Hero.setSeq(h, "skill", 11, {}) and not Hero.setSeq(h, "buff", 6, {}) and not Hero.setSeq(h, "skill", 1.5, {}) and not Hero.setSeq(h, "x", 1, {}), "없는 가지 · 번호는 받지 않는다")
expect(Hero.canSlot(h, "seq_1") and Hero.canSlot(h, "bseq_5") and not Hero.canSlot(h, "seq_11") and not Hero.canSlot(h, "macro_1"), "퀵슬롯에 놓을 수 있다(비어 있어도)")
local slots = table.clone(h.slots)
local free = {}
for i = 1, Quick.N do
	if not slots[i] then
		table.insert(free, i)
	end
end
slots[free[1]] = "seq_1"
slots[free[2]] = "bseq_2"
expect(Hero.setSlots(h, slots), "퀵슬롯에 시퀀스를 놓는다")
local back = Hero.unpack(1, Hero.pack(h))
expect(back ~= nil and table.concat(back.seqs.skill[1], ",") == "ax_roar,ax_breath" and table.concat(back.seqs.buff[2], ",") == "bm_drop,bm_exp" and #back.seqs.skill[2] == 0, "저장 → 읽기: 시퀀스 그대로")
eq(back and back.slots[free[1]], "seq_1", "저장 → 읽기: 퀵슬롯의 스킬 시퀀스 그대로")
eq(back and back.slots[free[2]], "bseq_2", "저장 → 읽기: 퀵슬롯의 버프 시퀀스 그대로")
local old = Hero.pack(h)
old.seqs = nil
local backOld = Hero.unpack(1, old)
expect(backOld ~= nil and #backOld.seqs.skill == 10 and #backOld.seqs.skill[1] == 0, "그 전의 저장 = 빈 시퀀스")
local packed = Hero.pack(h)
packed.seqs.skill[1][1] = "changed"
eq(h.seqs.skill[1][1], "ax_roar", "저장한 꼴은 따로(고쳐도 캐릭터가 바뀌지 않는다)")
local view = Hero.view(h)
expect(view.seqs ~= nil and view.seqs.skill[1][1] == "ax_roar", "내 상태(Self)에 실린다")

-- ③ 퀵슬롯의 그림 · 표시
Quick.seqFirst = function(kind, k)
	return h.seqs[kind][k] and h.seqs[kind][k][1]
end
eq(Quick.pic("seq_1"), "skill_ax_roar", "칸의 그림 = 넣어 둔 첫 스킬")
eq(Quick.pic("bseq_2"), Quick.pic("bm_drop"), "버프 시퀀스의 칸 = 첫 아이템의 그림")
eq(Quick.pic("seq_2"), "menu_skill", "빈 시퀀스 = 스킬 창의 그림")
eq(Quick.seqMark("seq_2"), "S2", "구석에 「S2」")
eq(Quick.seqMark("bseq_4"), "B4", "구석에 「B4」")
eq(Quick.seqMark("ax_roar"), nil, "스킬에는 표시가 없다")
Quick.seqFirst = nil

-- ④ 시퀀스 창 · ⑤ 스킬 창의 단추(가짜 부품은 진짜와 같은 모양 — 없는 칸을 읽으면 바로 오류: 시험 94와 같은 법)
local function frame(name)
	local f = { Name = name, Visible = true, ZIndex = 1, Size = UDim2.fromOffset(1, 1), Position = UDim2.fromOffset(0, 0), AbsolutePosition = Vector2.new(400, 100), children = {} }
	function f:Destroy() end
	function f:GetPropertyChangedSignal() return { Connect = function() end } end
	return f
end
local function strict(t, what)
	return setmetatable(t, { __index = function(_, k)
		error(("%s에 없는 칸 「%s」을 읽었다"):format(what, tostring(k)), 2)
	end })
end
local texts = {}
local buttons = {}
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end }),
	M = { body = 12, small = 9, bodyLine = 16, smallLine = 13, button = 26 },
	group = function(_, x, y, w, h2, name) return frame(name or "Group") end,
	box = function() return frame("Box") end,
	text = function(_, t)
		local label = { Frame = frame("Text"), Width = 40, Height = 12 }
		local it = { label = label, text = t, shown = true }
		function it.set(_, v) it.text = v end
		function it.color() end
		function it.move() end
		function it.show(_, on) it.shown = on end
		function it.size() return 40, 12 end
		table.insert(texts, it)
		return strict(it, "글 칸(Ui.text)")
	end,
	button = function(_, text, x, y, w, onClick)
		local b = { frame = frame("Button"), click = onClick, text = text }
		function b.setText(_, v) b.text = v end
		function b.setEnabled() end
		function b.setMain() end
		table.insert(buttons, b)
		return strict(b, "단추(Ui.button)")
	end,
	slot = function()
		local s = { frame = frame("Slot"), on = false }
		function s.setOn(_, on) s.on = on end
		return strict(s, "칸(Ui.slot)")
	end,
	pic = function(_, name) local p = frame("Pic"); p.pic = name; return p end,
	setPic = function(label, name) label.pic = name; label.Visible = name ~= nil end,
	measure = function(t) return #t * 4 end,
})
local opened = {}
MOCK("Client/lune/ui/windows", { open = function(id) table.insert(opened, id) end })
local SeqWindow = req("Client/lune/ui/seqWindow")
local sent, picked = {}, nil
local ctx = {
	send = function(...) table.insert(sent, { ... }) end,
	me = function() return view end,
	quick = {
		pick = function(id) picked = id end,
		press = function() end,
		info = function() return { state = "ok", key = nil } end,
		picked = function() return picked end,
	},
}
local w, hh = SeqWindow.size()
local ok, sv = pcall(SeqWindow.build, frame("Body"), ctx, w, hh)
expect(ok, "시퀀스 창을 끝까지 짓는다 — " .. tostring(sv))
local function has(text)
	for _, it in texts do
		if it.text == text then
			return true
		end
	end
	return false
end
local function btn(name)
	for _, inst in CREATED do
		if inst.ClassName == "TextButton" and inst.Name == name then
			return inst
		end
	end
	return nil
end
local function click(name)
	local b = btn(name)
	if b then
		b.Activated:Fire()
	end
	return b ~= nil
end
if ok then
	local SD = Seq.DATA
	expect(has(SD.tabs.skill) and has(SD.tabs.buff) and has(SD.head.skill) and has(SD.pick.skill) and has(SD.hint) and has("스킬 시퀀스 1"), "탭 「스킬」 · 「버프」 · 안내 · 「넣을 스킬」 · 이름")
	-- 넣을 것을 누르면 고른 시퀀스(스킬 1)의 끝에 더해 서버에 보낸다
	table.clear(sent)
	expect(click("Cand3"), "넣을 것의 칸이 있다")
	local last = sent[#sent]
	expect(last ~= nil and last[1] == "Sequence" and last[2] == "skill" and last[3] == 1 and typeof(last[4]) == "table" and #last[4] == 3, "넣을 것을 누르면 스킬 시퀀스 1에 더해 보낸다(지금 둘 + 하나)")
	-- 설명 칸(2026-10-30 사용자: "넣을스킬에 누르거나 하면 무슨스킬인지 보여야해"): 누른 스킬의 이름 · 설명이 보인다
	local CL = req("ReplicatedStorage/shared/lune/data/classes.generated")
	local pickedSk = nil
	for _, t in CL.classes.axion.tiers do
		for _, sk in t.skills do
			if sk.id == cands[3] then
				pickedSk = sk
			end
		end
	end
	expect(pickedSk ~= nil and has(pickedSk.name) and has(pickedSk.text), "누른 넣을 것의 이름 · 설명이 설명 칸에 보인다(" .. tostring(pickedSk and pickedSk.name) .. ")")
	-- 칸을 누르면 그것을 뺀다
	table.clear(sent)
	click("Cell1")
	last = sent[#sent]
	expect(last ~= nil and last[2] == "skill" and last[3] == 1 and #last[4] == 1 and last[4][1] == "ax_breath", "첫 칸을 누르면 뺀다(남은 것 ax_breath)")
	-- 「비우기」
	table.clear(sent)
	for _, b in buttons do
		if b.text == SD.clear then
			b.click()
		end
	end
	last = sent[#sent]
	expect(last ~= nil and last[3] == 1 and #last[4] == 0, "「비우기」 = 빈 목록을 보낸다")
	-- 시퀀스 아이콘을 누르면 고르고 퀵슬롯에 놓으려고 고른다
	click("Chip4")
	eq(picked, "seq_4", "스킬 시퀀스 4의 아이콘을 누르면 퀵슬롯에 놓으려고 고른다")
	-- 탭 「버프」: 버프 시퀀스 2를 고르고 넣는다
	click("Tab_buff")
	expect(has(SD.head.buff) and has(SD.pick.buff) and has(SD.info), "버프 탭의 안내 · 「넣을 것」 · 설명 칸의 안내")
	click("Chip2")
	eq(picked, "bseq_2", "버프 시퀀스 2를 고른다")
	table.clear(sent)
	h.seqs.buff[2] = { "bm_drop" }
	view = Hero.view(h)
	sv.refresh(view)
	click("Cand1")
	last = sent[#sent]
	expect(last ~= nil and last[1] == "Sequence" and last[2] == "buff" and last[3] == 2 and table.concat(last[4], ",") == "bm_drop,bm_exp", "버프 시퀀스 2에 경험치 쿠폰을 더한다")
	-- 다 찬 시퀀스에는 보내지 않는다
	h.seqs.skill[1] = {}
	for i = 1, Seq.SIZE.skill do
		h.seqs.skill[1][i] = "x" .. i
	end
	view = Hero.view(h)
	click("Tab_skill")
	click("Chip1")
	sv.refresh(view)
	table.clear(sent)
	click("Cand1")
	expect(#sent == 0, "다 찬 시퀀스에는 보내지 않는다")
	expect(has((string.gsub(SD.full, "{max}", tostring(Seq.SIZE.skill)))), "다 찼다는 알림이 설명 칸에 뜬다")
	click("Chip3")
	expect(has("스킬 시퀀스 3") and has(SD.blank), "시퀀스 아이콘을 누르면 그 시퀀스의 이름 · 「비어 있다」")
	expect(pcall(sv.destroy), "닫는다")
end

-- ⑤ 스킬 창의 「시퀀스」 단추 → 시퀀스 창을 연다
local SkillWindow = req("Client/lune/ui/skillWindow")
local sw, shh = SkillWindow.size()
local ok2, skv = pcall(SkillWindow.build, frame("Body2"), ctx, sw, shh)
expect(ok2, "스킬 창을 끝까지 짓는다 — " .. tostring(skv))
if ok2 then
	expect(pcall(skv.refresh, view), "스킬 창을 내 상태로 채운다")
	local found = false
	for _, b in buttons do
		if b.text == Seq.DATA.open and b.frame.Name == "SeqOpen" then
			found = true
			b.click()
		end
	end
	expect(found, "스킬 창에 「시퀀스」 단추가 있다")
	eq(opened[#opened], "seq", "누르면 시퀀스 창을 연다")
end
