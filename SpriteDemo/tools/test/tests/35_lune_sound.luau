-- 「달의 계승자」 — 소리 설정(배경 음악 · 효과음의 크기 · 모두 끄기).
--  사용자 2026-10-13: "소리조절 있어야합니다."
--  셈(shared/lune/sim/account.luau의 sound · client/lune/music.luau의 크기)과 창(client/lune/ui/soundWindow.luau)을 화면 없이 돌려 본다.
--  서버에 저장되고 다시 들어와도 남는지는 34_lune_keys_persist.luau의 끝이 본다.
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local L = req("ReplicatedStorage/shared/lune/ui/layout")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local pixelText = req("Client/ui/pixelText")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})
local S = L.SOUND

local function same(a, b): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- ---- 1) 치수: 창의 목록에 있다 · 줄이 창의 폭에 든다 ----
local listed = false
for _, w in UI.windows do
	listed = listed or (w.id == "sound" and w.key == false)
end
expect(listed, "소리 설정 창이 창의 목록에 있다(여는 키는 없다 — 메뉴에서 연다)")
eq(#S.rows, 2, "줄은 둘(배경 음악 · 효과음)")
eq(S.rows[1][1], "music", "첫 줄은 배경 음악")
eq(S.rows[2][1], "sfx", "둘째 줄은 효과음")
expect(S.steps == 10 and S.start >= 1 and S.start <= S.steps, "열 칸 · 처음 크기는 그 안")
expect(S.btn >= 22 and S.seg + S.gap >= 12, "손가락으로도 누를 만한 크기(단추 22 · 칸 12 이상)")

-- ---- 2) 계정의 소리 설정 ----
local acct = Account.new()
expect(same(acct.sound, { music = S.start, sfx = S.start, on = true, fx = true, nums = true, myNums = true, lang = "auto", touch = "new" }), "새 계정은 처음 크기 · 모두 켬 · 화면도 모두 켜짐")
-- 화면(2026-10-18 — fx · nums): 받으면 언제나 실린다(없으면 켜짐)
expect(Account.setSound(acct, { music = 3, sfx = 0, on = false }) == true and same(acct.sound, { music = 3, sfx = 0, on = false, fx = true, nums = true, myNums = true, lang = "auto", touch = "new" }), "설정을 받는다(화면은 없으면 켜짐)")
expect(Account.setSound(acct, { music = 3, sfx = 0, on = false, fx = false, nums = true }) == true and acct.sound.fx == false and acct.sound.nums == true, "화면 설정도 받는다")
expect(Account.setSound(acct, { music = 3, sfx = 0, on = false, fx = true, nums = true, myNums = false }) == true and acct.sound.myNums == false, "내 피해 숫자 끄기도 받는다(2026-10-30)")
expect(Account.setSound(acct, { music = 3, sfx = 0, on = false, myNums = "no" }) == false and acct.sound.myNums == false, "내 피해 숫자가 참거짓이 아니면 받지 않는다")
local given = { music = 5, sfx = 5, on = true, extra = "x" }
expect(Account.setSound(acct, given) and acct.sound ~= given and acct.sound.extra == nil, "받은 표를 그대로 쥐지 않는다(다른 것이 딸려 오지 않는다)")
for _, bad in { "x", 3, { music = 5 }, { music = 5, sfx = 5, on = "true" }, { music = S.steps + 1, sfx = 0, on = true }, { music = 0, sfx = -1, on = true }, { music = 2.5, sfx = 1, on = true }, { music = 5, sfx = 5, on = true, fx = "no" }, { music = 5, sfx = 5, on = true, nums = 0 } } do
	expect(Account.setSound(acct, bad) == false and same(acct.sound, { music = 5, sfx = 5, on = true, fx = true, nums = true, myNums = true, lang = "auto", touch = "new" }), "말이 안 되는 설정은 받지 않는다")
end
-- 언어(2026-10-27 영문): 자동 · 한국어 · English만 받는다
expect(Account.setSound(acct, { music = 5, sfx = 5, on = true, lang = "en" }) == true and acct.sound.lang == "en", "언어 English를 받는다")
expect(Account.setSound(acct, { music = 5, sfx = 5, on = true, lang = "jp" }) == false and acct.sound.lang == "en", "모르는 언어는 받지 않는다")
expect(Account.setSound(acct, { music = 5, sfx = 5, on = true }) == true and acct.sound.lang == "auto", "언어가 없으면 자동")
-- 폰 단추 배치(2026-10-28 사용자 "모바일 ui … 이전 구조가 더 익숙한 사람들은 전버전으로도 쓸수있게 설정창에서 바꿀수있게"): "new" · "old" · 없으면 "new" · 모르는 값은 받지 않는다
expect(Account.setSound(acct, { music = 5, sfx = 5, on = true, touch = "old" }) == true and acct.sound.touch == "old", "예전 배치를 받는다")
expect(Account.setSound(acct, { music = 5, sfx = 5, on = true, touch = "left" }) == false and acct.sound.touch == "old", "모르는 배치는 받지 않는다")
expect(Account.setSound(acct, { music = 5, sfx = 5, on = true }) == true and acct.sound.touch == "new", "배치가 없으면 새 배치")
local back = Account.unpack(Account.pack(acct))
expect(back ~= nil and same(back.sound, acct.sound), "싸고 풀어도 그대로다")
local raw = Account.pack(acct)
raw.sound = nil
expect(same(Account.unpack(raw).sound, { music = S.start, sfx = S.start, on = true, fx = true, nums = true, myNums = true, lang = "auto", touch = "new" }), "설정이 없던 저장은 처음 크기")
raw.sound = { music = 99, sfx = 1, on = true }
expect(same(Account.unpack(raw).sound, { music = S.start, sfx = S.start, on = true, fx = true, nums = true, myNums = true, lang = "auto", touch = "new" }), "망가진 설정도 처음 크기")
expect(same(Account.view(acct).sound, acct.sound), "캐릭터 고르기 화면이 받는 것에 소리 설정이 있다")

-- ---- 3) 크기의 셈(client/lune/music.luau) ----
SERVICE("RunService", { Heartbeat = { Connect = function() end } })
local Music = req("Client/lune/music")
eq(Music.MAX, S.steps, "칸 수")
expect(Music.on and Music.level.music == S.start and Music.level.sfx == S.start, "처음에는 모두 켬 · 처음 크기")
eq(Music.gain("music"), S.start / S.steps, "처음 크기의 배경 음악")
expect(Music.setLevel("music", 7) == true and Music.level.music == 7 and math.abs(Music.gain("music") - 0.7) < 1e-9, "배경 음악을 7칸으로 = 70%")
eq(Music.gain("sfx"), S.start / S.steps, "효과음은 그대로다(따로 다룬다)")
expect(Music.setLevel("sfx", 0) == true and Music.gain("sfx") == 0, "효과음을 0칸으로 = 나지 않는다")
expect(Music.sfx("coin") == false, "효과음이 0이면 효과음을 내지 않는다")
for _, bad in { -1, S.steps + 1, 2.5, 0 / 0 } do
	expect(Music.setLevel("music", bad) == false and Music.level.music == 7, "범위 밖의 크기는 받지 않는다")
end
expect(Music.setLevel("music", "3" :: any) == false and Music.setLevel("music", nil :: any) == false and Music.setLevel("voice", 3) == false, "숫자가 아닌 것 · 없는 갈래는 받지 않는다")
expect(Music.setLevel("music", 7) == false, "같은 값이면 바뀌지 않았다고 알린다(저장하지 않게)")
expect(Music.toggle() == false and Music.gain("music") == 0 and Music.gain("sfx") == 0, "모두 끄면 둘 다 0")
eq(Music.level.music, 7, "모두 꺼도 맞춰 둔 크기는 남는다")
expect(Music.toggle() == true and math.abs(Music.gain("music") - 0.7) < 1e-9, "다시 켜면 그 크기로")
expect(same(Music.export(), { music = 7, sfx = 0, on = true }), "저장할 꼴")
Music.import({ music = 2, sfx = 9, on = false })
expect(same(Music.export(), { music = 2, sfx = 9, on = false }), "저장된 것을 얹는다")
Music.import(nil)
Music.import({ music = 4 })
expect(same(Music.export(), { music = 4, sfx = 9, on = true }), "모자란 것은 있는 것만 얹는다(없는 on은 켬)")
expect(Account.cleanSound(Music.export()) ~= nil, "화면이 보내는 꼴을 계정이 받는다")

-- ---- 3b) 어느 소리를 내는가(2026-10-14) ----
--  사용자: "플레이어랑 몬스터 때릴 때 나는 소리랑 맞을때 나는 소리 전부 빼겠습니다. 대쉬 소리 빼겠습니다." · "모든 브금 디폴트 소리 줄이세요"
do
	local MUSIC = req("ReplicatedStorage/shared/lune/data/music.generated")
	-- 게임이 내는 효과음 · 트는 징글은 모두 자료에 있고 올린 번호가 있다(없으면 그 자리는 조용하다)
	for _, k in { "coin", "pick", "gameover", "success", "secret2", "secret3", "secret4" } do
		local d = MUSIC.sfx[k]
		expect(d ~= nil and d.id ~= "" and d.volume > 0 and d.volume <= 1 and d.gap > 0, "효과음 " .. k)
	end
	-- 데미지 소리(사용자: "출력되는 데미지는 이소리를 아주 짧게 재생합니다. 한 틱당 한번재생"): 타마다 · 마리마다 한 번씩 — 같은 순간에 여럿이 떠도 하나도 거르지 않는다(틈 0)
	local dmg = MUSIC.sfx.damage
	expect(dmg ~= nil and dmg.id == "rbxassetid://140612589056574" and dmg.gap == 0, "데미지 소리: 사용자의 Sound 「DOD Punch 4」 · 틈 0")
	-- "이 음성파일의 절반 만 재생합니다"(0.3425초) → "데미지 소리 출력 더짧게, 소리 줄이고" → 0.2초 · 크기 0.3(Sound의 0.5에서)
	expect(dmg.upto ~= nil and dmg.upto < 0.3425 and dmg.volume < 0.5, "데미지 소리는 절반보다 짧게 · 0.5보다 작게")
	-- 싸움의 소리(때릴 때 · 맞을 때 · 쓰러뜨림 · 대쉬)는 없다 — 자료에도, 화면 코드에도(Music.hit · Music.swing이 없다)
	for _, k in { "slash", "whoosh", "whoosh2", "hit1", "hit2", "hit3", "hitBig", "kill", "hurt", "dash", "jump" } do
		eq(MUSIC.sfx[k], nil, "효과음 " .. k .. "는 없다")
	end
	expect(Music.hit == nil and Music.swing == nil, "때리는 소리를 내는 함수가 없다")
	for _, k in { "victory", "jobup" } do
		expect(MUSIC.jingles[k] ~= nil and MUSIC.jingles[k].id ~= "", "징글 " .. k)
	end
	for _, k in { "complete", "death", "strange" } do
		eq(MUSIC.jingles[k], nil, "징글 " .. k .. "는 없다(퀘스트 완료 · 사망 · 숨은 방은 효과음만)")
	end
	eq(MUSIC.tracks.boss, nil, "보스의 곡은 하나(lair) — 망루의 부관 · 정찰대장이 같은 방")
	eq(MUSIC.scene.dream, "dream", "튜토리얼 꿈은 제 곡")
	-- 배경 음악의 크기: 2026-10-14 "줄이세요" → "여기서 다시 절반으로"(field_a 1.03 → 0.26) → 2026-10-28 "데미지에비해 나머지소리가 너무작아 다른 마을배경음들도 마찬가지":
	--  이제 곡마다 잰 크기를 같은 목표(데미지보다 9dB 작게)로 맞춘다 — 조용한 곡(field_a −35dB)은 크게 · 큰 곡(field_b · dark −16dB)은 작게. 그 어느 것도 1을 넘지 않는다
	--  2026-10-29 "다른 효과음에 비해 브금이 거의안들려" → 목표를 효과음보다 1dB 작게(−32dB): 아주 조용한 곡(field_a −35dB)은 1을 넘는다 — 로블록스의 Sound.Volume은 10까지 받는다(공방 volOf는 4에서 막는다)
	expect(MUSIC.tracks.field_a.volume > MUSIC.tracks.field_b.volume * 5 and MUSIC.tracks.field_a.volume <= 4, "배경 음악은 곡마다 잰 크기로 맞춘다(조용한 곡을 더 크게)")
	for k, t in MUSIC.tracks do
		expect(t.volume > 0 and t.volume <= 4, "배경 음악의 크기 " .. k)
	end
	expect(MUSIC.tracks.town.volume > 0.5, "마을 곡이 데미지 소리 밑에 묻히지 않는다(효과음보다 1dB 작게)")
	for k, t in MUSIC.sfx do
		expect(t.volume > 0 and t.volume <= 1, "효과음의 크기 " .. k)
	end
	expect(math.abs(MUSIC.sfx.damage.volume - 0.05) < 0.005, "데미지 소리는 사용자가 맞춘 크기 그대로(기준)")
	-- 보스의 소리(2026-10-28 밤 — Sonniss GDC 2024에서 고른 셋을 사용자가 듣고 "다좋아 다 적용해봐"): 여덟 자리마다 셋 · 모두 올린 번호가 있다
	for _, k in { "boss_swing", "boss_slam", "boss_shot", "boss_boom", "boss_roar", "boss_down", "boss_glass", "boss_smoke" } do
		local d = MUSIC.sfx[k]
		expect(d and d.vars and #d.vars == 3, "보스의 소리 " .. k .. ": 셋을 돌려 낸다")
		for i, v in (d and d.vars) or {} do
			expect(string.match(v.id, "^rbxassetid://%d+$") ~= nil and v.volume > 0 and v.volume <= 1, ("보스의 소리 %s의 %d번: 올린 번호 · 크기"):format(k, i))
		end
	end
end

-- ---- 4) 소리 설정 창을 화면 없이 지어 본다 ----
do
	local refreshed = 0
	MOCK("Client/modules/ui/pixelText", { RefreshAll = function() refreshed += 1 end }) -- 언어가 바뀌면 그려 둔 글을 다시 그린다(viewOpts.applyLang)
	local made = {}
	local function frame(name: string?)
		return { Name = name or "Frame", Visible = true }
	end
	local any = setmetatable({}, { __index = function(_, k) return "color:" .. tostring(k) end })
	MOCK("Client/lune/ui/ui", {
		COLOR = any,
		M = L.M,
		group = function(parent, x, y, w, h, name)
			local f = frame(name)
			f.kind, f.parent, f.x, f.y, f.w, f.h = "group", parent, x, y, w, h
			table.insert(made, f)
			return f
		end,
		box = function(parent, x, y, w, h, color)
			local f = frame("Box")
			f.kind, f.parent, f.x, f.y, f.w, f.h, f.BackgroundColor3 = "box", parent, x, y, w, h, color
			table.insert(made, f)
			return f
		end,
		hit = function(parent)
			local h = { Activated = {} }
			function h.Activated:Connect(fn) parent.click = fn end
			return h
		end,
		text = function(parent, text, x, y, width, opts)
			local font = if opts and opts.font then opts.font else "small"
			local item = { kind = "text", parent = parent, value = text, x = x, y = y, w = width, h = if font == "body" then L.M.body else L.M.small, font = font, align = if opts and opts.align then opts.align else "left" }
			function item.set(_, v) item.value = v end
			function item.color(_, c) item.tint = c end
			table.insert(made, item)
			return item
		end,
		button = function(parent, text, x, y, w, onClick, opts)
			local item = { kind = "button", parent = parent, value = text, x = x, y = y, w = w, h = if opts and opts.h then opts.h else L.M.button, font = if opts and opts.font then opts.font else "body", click = onClick, frame = frame("Button"), enabled = true, main = false }
			function item.setEnabled(_, on) item.enabled = on end
			function item.setText(_, v) item.value = v end
			function item.setMain(_, on) item.main = on end
			table.insert(made, item)
			return item
		end,
	})
	local SoundWindow = req("Client/lune/ui/soundWindow")
	local w, h = SoundWindow.size()
	expect(w + 36 <= 768 and h + 64 <= 432, "소리 설정 창이 스마트폰의 화면 틀(768x432)에 들어간다")
	Music.import({ music = 7, sfx = 3, on = true })
	local saved = 0
	local body = frame("Body")
	local view = SoundWindow.build(body, { saveSound = function() saved += 1 end }, w, h)

	local function of(kind: string, value: string?)
		local out = {}
		for _, e in made do
			if e.kind == kind and e.parent == body and (value == nil or e.value == value) then
				table.insert(out, e)
			end
		end
		table.sort(out, function(a, b) return if a.y ~= b.y then a.y < b.y else a.x < b.x end)
		return out
	end
	local minus, plus = of("button", "-"), of("button", "+")
	eq(#minus, 2, "「−」 단추 둘")
	eq(#plus, 2, "「+」 단추 둘")
	local segs = {} -- [줄] = 칸들(왼쪽부터)
	for _, e in of("box") do
		local row = e.y // S.row + 1
		segs[row] = segs[row] or {}
		table.insert(segs[row], e)
	end
	eq(#segs[1], S.steps, "배경 음악의 칸 열 개")
	eq(#segs[2], S.steps, "효과음의 칸 열 개")
	local hits = of("group")
	eq(#hits, S.steps * 2, "칸마다 누르는 자리")
	local function filled(row: number): number
		local n = 0
		for _, e in segs[row] do
			if e.BackgroundColor3 == any.accent or e.BackgroundColor3 == any.off then
				n += 1
			end
		end
		return n
	end
	local function pctOf(row: number): string
		local list = {}
		for _, e in of("text") do
			if e.align == "right" and e.y // S.row + 1 == row and e.y < #S.rows * S.row then
				table.insert(list, e)
			end
		end
		return list[1].value
	end
	eq(filled(1), 7, "배경 음악 7칸이 차 있다")
	eq(filled(2), 3, "효과음 3칸이 차 있다")
	eq(pctOf(1), "70%", "배경 음악 70%")
	eq(pctOf(2), "30%", "효과음 30%")

	-- 겹치지 않고 창 안이다: 글(실제 폭) · 단추 · 칸
	local shown = {}
	for _, e in made do
		if e.parent == body and e.kind ~= "group" and not (e.kind == "text" and e.value == "") then
			local x0, x1 = e.x, e.x + e.w
			if e.kind == "text" then
				local tw = pixelText.Measure(e.value, e.font)
				expect(tw <= e.w, ("글이 제 칸에 든다 「%s」(%d / %d)"):format(e.value, tw, e.w))
				x0, x1 = if e.align == "right" then e.x + e.w - tw else e.x, if e.align == "right" then e.x + e.w else e.x + tw
			elseif e.kind == "button" then
				expect(pixelText.Measure(e.value, e.font) <= e.w - 6, "단추의 글 " .. e.value)
			end
			table.insert(shown, { x0 = x0, x1 = x1, y0 = e.y, y1 = e.y + e.h, name = tostring(e.value or e.Name) })
		end
	end
	for i, a in shown do
		expect(a.x0 >= 0 and a.x1 <= w and a.y0 >= 0 and a.y1 <= h, ("창 안이다 %s(%d~%d, %d~%d / %dx%d)"):format(a.name, a.x0, a.x1, a.y0, a.y1, w, h))
		for j = i + 1, #shown do
			local b = shown[j]
			expect(a.x1 <= b.x0 or b.x1 <= a.x0 or a.y1 <= b.y0 or b.y1 <= a.y0, ("겹친다: %s(%d~%d, %d~%d) · %s(%d~%d, %d~%d)"):format(a.name, a.x0, a.x1, a.y0, a.y1, b.name, b.x0, b.x1, b.y0, b.y1))
		end
	end
	-- 가장 넓은 글(100% · 꺼 둠)도 제 칸에 든다
	expect(pixelText.Measure("100%", "small") <= S.pctW and pixelText.Measure(S.off, "small") <= S.pctW, "% 글이 제 칸에 든다")
	for _, m in S.mute do
		expect(pixelText.Measure(m, "body") <= S.muteW - 6, "「모두 끄기 / 켜기」의 글")
	end

	-- 누른다: + · − · 칸 · 모두 끄기
	plus[1].click()
	expect(Music.level.music == 8 and saved == 1 and filled(1) == 8 and pctOf(1) == "80%", "「+」 = 한 칸 크게 · 저장한다")
	minus[2].click()
	expect(Music.level.sfx == 2 and saved == 2 and filled(2) == 2, "「−」 = 한 칸 작게")
	hits[5].click() -- 배경 음악의 다섯째 칸
	expect(Music.level.music == 5 and saved == 3 and filled(1) == 5 and pctOf(1) == "50%", "칸을 누르면 그 칸까지")
	hits[5].click()
	eq(saved, 3, "같은 칸을 다시 눌러도 다시 저장하지 않는다")
	hits[S.steps + S.steps].click() -- 효과음의 마지막 칸
	expect(Music.level.sfx == S.steps and plus[2].enabled == false and minus[2].enabled == true, "끝까지 올리면 「+」가 꺼진다")
	plus[2].click()
	eq(Music.level.sfx, S.steps, "끝에서 더 올라가지 않는다")
	for _ = 1, S.steps + 2 do
		minus[1].click()
	end
	expect(Music.level.music == 0 and minus[1].enabled == false and filled(1) == 0 and pctOf(1) == "0%", "0까지 내리면 「−」가 꺼진다 · 그 아래로 가지 않는다")
	local mute = of("button", S.mute[1])
	eq(#mute, 1, "「모두 끄기」 단추")
	local before = saved
	mute[1].click()
	expect(Music.on == false and saved == before + 1 and mute[1].value == S.mute[2] and mute[1].main == true, "모두 끄면 단추가 「모두 켜기」(민트)로 바뀌고 저장한다")
	expect(pctOf(2) == S.off and filled(2) == S.steps and segs[2][1].BackgroundColor3 == any.off, "꺼 둔 동안은 % 대신 「꺼 둠」 · 칸은 흐리게(맞춰 둔 크기는 보인다)")
	mute[1].click()
	expect(Music.on == true and mute[1].value == S.mute[1] and pctOf(2) == "100%" and segs[2][1].BackgroundColor3 == any.accent, "다시 켜면 그대로 돌아온다")
	view.refresh()
	-- 화면(2026-10-18): 다른 사람의 스킬 효과 · 피해 숫자 — 켜짐 / 꺼짐 단추가 둘, 누르면 바뀌고 저장한다
	local ViewOpts = req("Client/lune/viewOpts")
	local V = S.view
	local toggles = of("button", V.on)
	eq(#toggles, 3, "화면의 단추 셋(처음은 켜짐 — 셋째 = 내 피해 숫자 · 2026-10-30)")
	toggles[3].click()
	expect(ViewOpts.myNums == false and toggles[3].value == V.off, "「내 피해 숫자」를 누르면 꺼짐")
	expect(ViewOpts.into(Music.export()).myNums == false, "저장하는 표에 실린다")
	toggles[3].click()
	expect(ViewOpts.myNums == true, "다시 누르면 켜짐")
	local saved0 = saved
	toggles[1].click()
	expect(ViewOpts.fx == false and saved == saved0 + 1 and toggles[1].value == V.off and toggles[1].main == false, "누르면 꺼짐 · 저장한다")
	local packed = ViewOpts.into(Music.export())
	expect(packed.fx == false and packed.nums == true and Account.setSound(Account.new(), packed), "저장하는 표에 화면 설정이 실리고 서버가 받는다")
	toggles[1].click()
	expect(ViewOpts.fx == true and toggles[1].value == V.on, "다시 누르면 켜짐")
	ViewOpts.import({ music = 1, sfx = 1, on = true, nums = false })
	expect(ViewOpts.fx == true and ViewOpts.nums == false, "저장된 것을 얹는다(없는 값은 켜짐)")
	expect(ViewOpts.myNums == true, "내 피해 숫자도 없으면 켜짐")
	ViewOpts.import({ music = 1, sfx = 1, on = true, myNums = false })
	expect(ViewOpts.myNums == false and ViewOpts.toggle("myNums") and ViewOpts.myNums == true, "내 피해 숫자를 얹고 · 켜고 끈다")
	ViewOpts.import({ music = 1, sfx = 1, on = true })
	-- 폰 단추 배치(2026-10-28): 「새 배치」 · 「예전 배치」 — 처음은 새 배치 · 누르면 바뀌고 저장 · 저장하는 표에 실린다 · 제목과 한 줄(창이 폰에 들어간다)
	view.refresh()
	local P = S.touch
	local newB, oldB = of("button", P.choices[1][2])[1], of("button", P.choices[2][2])[1]
	expect(newB ~= nil and oldB ~= nil and newB.main == true and oldB.main == false and ViewOpts.touch == "new", "폰 단추 배치: 처음은 새 배치")
	expect(newB.y == oldB.y and of("text", P.head)[1] ~= nil and math.abs(of("text", P.head)[1].y - newB.y) <= 8, "제목과 단추가 한 줄")
	local s0 = saved
	oldB.click()
	expect(ViewOpts.touch == "old" and saved == s0 + 1 and oldB.main == true and newB.main == false, "「예전 배치」를 누르면 바뀌고 저장한다")
	local packed2 = ViewOpts.into(Music.export())
	expect(packed2.touch == "old" and Account.setSound(Account.new(), packed2), "저장하는 표에 폰 단추 배치가 실리고 서버가 받는다")
	ViewOpts.import({ music = 1, sfx = 1, on = true })
	eq(ViewOpts.touch, "new", "저장된 것에 없으면 새 배치")
end
