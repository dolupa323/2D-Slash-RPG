-- 「달의 계승자」 — 2026-11-03 제보 고침 모음.
--  ① 무니 달빛 파도(제보 「파도 스킬이 점프하면서 쓰면 위 아래 y좌표를 따라오면서 여러개 나오듯이 보이는 버그」): 수정을 지날 때 이는 둘째 파도는 그 수정의 높이에서 —
--     전에는 그때의 무니 높이(g.y)에서 일어, 첫 파도가 구르는 동안 무니가 뛰면 공중 여러 높이에 파도가 생겼다. 다른 층의 수정은 지난 것으로 치지 않는다(높이 차 20 안만)
local Kitset = req("ReplicatedStorage/shared/lune/kitset")

do
	local kit = Kitset.of("mooni")
	local ev
	for _, s in kit.skills do
		if s.id == "mn_wave" then
			ev = s.segs[1].ev[6]
		end
	end
	expect(ev ~= nil, "달빛 파도의 터지는 장")
	local shots = {}
	local g = {
		x = 100, y = 176, dir = 1, tone = { n = 0, l = 0, d = 0, w = 0 }, s = { cr = {} },
		fx = setmetatable({}, { __index = function()
			return function() end
		end }),
		fwd = function(d)
			return 100 + d
		end,
		shot = function(o)
			o.x = o.x or 0
			table.insert(shots, o)
			return o
		end,
	}
	-- 같은 층(176)의 수정 하나 · 위층(112)의 수정 하나 — 둘 다 파도가 가는 길의 가로 자리
	table.insert(g.s.cr, { x = 160, y = 176, t = 0, life = 99 })
	table.insert(g.s.cr, { x = 200, y = 112, t = 0, life = 99 })
	ev(g)
	eq(#shots, 1, "첫 파도 하나")
	local first = shots[1]
	eq(first.y, 176, "첫 파도는 무니의 발 높이")
	-- 첫 파도가 구르는 동안 무니가 뛴다(높이 120) — 둘째 파도는 그래도 수정의 높이에서
	g.y = 120
	for _ = 1, 60 do
		first.x += first.vx / 60
		first.update(first)
	end
	eq(#shots, 2, "같은 층의 수정만 둘째 파도를 일으킨다(위층의 수정은 지나지 않는다)")
	eq(shots[2] and shots[2].y, 176, "둘째 파도는 수정의 높이(무니가 뛰어 있어도)")
end

-- ② 캐시 무기는 캐릭터마다(사용자 "무기스킨 캐릭마다 낄수있게해달라고하네 지금은 하나끼면 전캐릭 다 적용되잖아 캐릭터 각각 뭐껴놨으면 그걸로 되야되는거지"):
--  가진 것은 계정의 것 · 낀 것은 캐릭터의 것(저장한다) · 이것이 생기기 전의 캐릭터는 계정에 껴 두었던 것을 한 번 이어받는다 · 새 캐릭터는 끼지 않은 채
do
	local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local acct = { bm = Cash.new(), chars = {} }
	acct.bm.wskins.wskin_gold, acct.bm.wskins.wskin_frost = true, true
	acct.bm.wskin = "wskin_gold" -- 예전(계정)에 껴 둔 것
	local a, b = Hero.new(1, "axion"), Hero.new(2, "riven")
	eq(a.wskin, false, "새 캐릭터는 끼지 않은 채")
	-- 이것이 생기기 전에 저장된 캐릭터(wskin 없음) → 계정에 껴 두었던 것을 이어받는다
	local packed = Hero.pack(a)
	packed.wskin = nil
	local old = Hero.unpack(1, packed)
	eq(old.wskin, nil, "옛 저장은 아직 정하지 않음")
	eq(Cash.heroWskin(acct, old), "wskin_gold", "옛 캐릭터는 계정에 껴 두었던 것")
	-- 캐릭터마다 따로 낀다
	expect(Cash.setWskin(acct, "wskin_frost", b), "둘째 캐릭터에 서리")
	eq(Cash.heroWskin(acct, b), "wskin_frost", "둘째 캐릭터 = 서리")
	eq(Cash.heroWskin(acct, old), "wskin_gold", "첫째 캐릭터는 그대로 황금")
	eq(Cash.heroWskin(acct, a), false, "셋째(새) 캐릭터는 끼지 않은 채")
	expect(Cash.setWskin(acct, false, old), "첫째 캐릭터 해제")
	eq(Cash.heroWskin(acct, old), false, "해제")
	eq(Cash.heroWskin(acct, b), "wskin_frost", "다른 캐릭터는 그대로")
	expect(not Cash.setWskin(acct, "wskin_lava", a), "가지지 않은 것은 못 낀다")
	-- 저장 · 읽기
	local again = Hero.unpack(2, Hero.pack(b))
	eq(again.wskin, "wskin_frost", "캐릭터의 낀 것이 저장된다")
	-- 상점 창이 보는 낀 것 = 그 캐릭터의 것
	eq(Cash.view(acct, 0, nil, nil, nil, nil, b).wskin, "wskin_frost", "상점 창 = 지금 캐릭터의 것")
end

-- ③ 살라맨더 재점화(사용자 "재점화가 써지고 나서 재사용 쿨 알수가 없어서 버프처럼 위에 보여야하고 … 사용되었을때 극적인 이펙트가 있어야해"):
--  그림(pixelfx로 만든 분홍 불기둥 — 캐릭터 그림판 pfx_sl_rekindle)이 실렸다 · 그 판이 올라가 있다 · 알림(Rekindle)이 있다 · 버프 줄의 글이 있다(터진 뒤의 셈은 22_lune_passives)
do
	local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
	local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")
	local PACKETS = req("ReplicatedStorage/shared/lune/net/packets")
	local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local c = CHARS.chars.pfx_sl_rekindle
	expect(c ~= nil and c.clips.play ~= nil, "재점화의 그림(pfx_sl_rekindle · play)")
	expect(c and #c.clips.play.frames >= 30, "재점화의 그림이 서른 장 넘게(1초에 12장 — 3초쯤)")
	local pages, up = {}, true
	for _, f in (c and c.clips.play.frames or {}) do
		if f then
			pages[f[1]] = true
		end
	end
	for pg in pages do
		local file = CHARS.pages[pg]
		up = up and ASSETS[file] ~= nil and ASSETS[file] ~= ""
	end
	expect(next(pages) ~= nil and up, "그 그림의 판이 로블록스에 올라가 있다")
	expect(PACKETS.Rekindle ~= nil, "알림 Rekindle")
	expect(UI.buffTip.rekindle ~= nil and UI.buffTip.rekindleFloat ~= nil, "버프 줄 · 머리 위의 글")
end

-- ④ 스케줄러(사용자 "스케줄러를 만들어서 … 일일퀘스트, 보스 했는지 이번주 잡았는지, 오늘 깼는지 던전 이런거 보이고 깨면 체크표시되고 메이플에 스케줄러기능이있어 참고하면된다"):
--  sim/schedule.luau — 일일(출석 · 일일 의뢰 게시판마다 · 토벌 · 던전마다) · 주간(보스마다) · 잠김 / 진행 / 끝냄(체크) · 날 · 주가 바뀌면 다시 0
do
	local Schedule = req("ReplicatedStorage/shared/lune/sim/schedule")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
	local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
	local Rift = req("ReplicatedStorage/shared/lune/sim/rift")
	local Attend = req("ReplicatedStorage/shared/lune/sim/attend")
	local UIG = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local NOW = 1793700000 -- (2026-11 어느 날)
	local function find(rows, id)
		for _, r in rows do
			if r.id == id then
				return r
			end
		end
		return nil
	end
	local h = Hero.new(1, "axion")
	h.level = 1
	local acct = { att = Attend.new() }
	local v = Schedule.view(h, acct, NOW)
	expect(#v.daily >= 5 and #v.weekly >= 3, ("줄: 일일 %d · 주간 %d"):format(#v.daily, #v.weekly))
	expect(find(v.daily, "daily:r1").locked, "Lv.1 — 일일 의뢰는 잠김(Lv.10부터)")
	expect(find(v.daily, "rift").locked, "Lv.1 — 토벌은 잠김")
	expect(find(v.daily, "dungeon:dg1").locked and find(v.daily, "dungeon:dg1").text == UIG.schedule.closed, "던전은 퀘스트를 끝내야 열린다")
	expect(find(v.weekly, "boss:" .. Weekly.DATA.bosses[1].id).locked, "보스는 퀘스트를 끝내야 열린다")
	local d0, t0 = Schedule.count(v.daily)
	eq(t0, 1, "Lv.1에 할 수 있는 것 = 출석 하나")
	expect(not find(v.daily, "attend").done, "출석 전")
	-- 출석하고 받는다 → 체크
	Attend.checkIn(acct.att, NOW)
	acct.att.got = acct.att.n
	expect(Schedule.view(h, acct, NOW).daily[1].done, "출석하고 받으면 체크")
	-- Lv.35 · 던전 퀘스트 끝 · 오늘의 의뢰 둘 다 냈다 · 던전 끝 · 토벌 두 번
	h.level = 35
	local dg = Rift.DUNGEON.tiers[1]
	h.quests[dg.quest] = { done = true }
	Daily.sync(h, "r1", NOW)
	for _, t in h.daily.r1.tasks do
		t.st = Daily.DONE
	end
	Rift.dungeonMark(h.rift, dg.id, NOW)
	Rift.use(h.rift, NOW)
	v = Schedule.view(h, acct, NOW)
	expect(find(v.daily, "daily:r1").done, "일일 의뢰 둘 다 냈으면 체크")
	expect(find(v.daily, "dungeon:" .. dg.id).done, "오늘 던전을 끝냈으면 체크")
	local rift = find(v.daily, "rift")
	expect(not rift.done and not rift.locked, ("토벌 한 번 — 아직(%s)"):format(rift.text))
	Rift.use(h.rift, NOW)
	expect(find(Schedule.view(h, acct, NOW).daily, "rift").done, "토벌 두 번이면 체크")
	-- 다음 날: 다시 0
	local next = Schedule.view(h, acct, NOW + 86400)
	expect(not find(next.daily, "daily:r1").done and not find(next.daily, "dungeon:" .. dg.id).done and not find(next.daily, "rift").done, "다음 날이면 일일은 다시 0")
	-- 주간 보스: 퀘스트 끝 → 열림 · 격파 → 체크(노말) · 다음 주 → 다시 0
	local b = Weekly.DATA.bosses[1]
	h.quests[b.quest] = { done = true }
	h.level = math.max(h.level, b.normal.need)
	local row = find(Schedule.view(h, acct, NOW).weekly, "boss:" .. b.id)
	expect(not row.locked and not row.done, "보스 퀘스트를 끝내면 열린다")
	Weekly.mark(h.rift, b.id, "normal", NOW)
	row = find(Schedule.view(h, acct, NOW).weekly, "boss:" .. b.id)
	expect(row.done and string.find(row.text, Weekly.DATA.modes.normal.name, 1, true) ~= nil, "격파하면 체크 · 「노말 격파」")
	expect(not find(Schedule.view(h, acct, NOW + 7 * 86400).weekly, "boss:" .. b.id).done, "다음 주면 다시 0")
	expect(v.dayLeft > 0 and v.dayLeft <= 86400 and v.weekLeft > 0 and v.weekLeft <= 7 * 86400, "다음 초기화까지의 초")
end
