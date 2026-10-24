-- 「달의 계승자」 — 거대 탈것 「이끼 골렘」(2026-10-22 — 공방 design/ride.js의 mount_golem · tools/lune_ride_hand.mjs · assetpack/lune/ride/golem/).
--  사용자: "탈것 하나 만들자 엄청큰데 엄청느린 보스몬스터같은" → "이끼골렘으로하자" → "오케이 작업하고 근데 캐릭터가 여기서 살짝 뒤쪽에 서있어야한다"
--  보는 것: ① 탈것 자료(이름 · 느린 빠르기 · 앉는 자리) ② 그림(서기 · 걷기 · 점프 + 영웅 앞에 다시 그리는 판 · 크기) ③ 상품(꾸밈 탭 · 399 · 번호 전까지 「준비 중」 · 설명은 느려진다고)
--   ④ 산 계정에 들어간다 · 타면 걸음이 느려진다(화면이 쓰는 배수)
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")

-- ① 자료
local golem = nil
for _, q in RIDE.mounts do
	if q.id == "mount_golem" then
		golem = q
	end
end
expect(golem ~= nil, "탈것 목록에 이끼 골렘이 있다")
eq(golem.name, "이끼 골렘", "이름")
eq(golem.speed, 0.6, "걸음 = 걷는 빠르기의 0.6배(걷기보다 느리다)")
expect(golem.speed < 1 and (RIDE.mountSpeed or 1) > 1, "다른 탈것(1.3배)보다 느리다")
expect(golem.free == nil, "상점에서 파는 탈것(쿠폰 탈것이 아니다)")
expect(golem.seat and golem.seat.dy < -50, ("영웅은 높은 등 위에 앉는다(발이 탈것 발밑보다 %d점 위)"):format(-(golem.seat and golem.seat.dy or 0)))

-- ② 그림
local c = CHARS.chars.mount_golem
expect(c ~= nil, "그림이 있다")
for _, clip in { "idle", "run", "jump", "idle_front", "run_front", "jump_front" } do
	expect(c.clips[clip] ~= nil and #c.clips[clip].frames >= 1, clip .. " 동작")
end
eq(#c.clips.run.frames, 4, "걷기 네 장")
eq(#c.clips.idle.frames, 4, "서기 네 장")
local f1 = c.clips.idle.frames[1]
expect(f1[5] >= 65 and f1[5] <= 80, ("서기 그림의 키 %d점(약 70)"):format(f1[5]))
local tallest = 0
for _, id in { "mount_wolf", "mount_deer", "mount_boar" } do
	local g = CHARS.chars[id].clips.idle.frames[1]
	tallest = math.max(tallest, g[5])
end
expect(f1[5] >= tallest * 1.8, ("다른 탈것 가운데 가장 큰 것(키 %d점 — 수정 사슴의 뿔까지)의 1.8배 넘게 크다"):format(tallest))
for _, fr in c.clips.run.frames do
	expect(fr and math.abs(fr[5] - f1[5]) <= 2, ("걷기의 장마다 키가 서기와 같다(%d점 — 몸이 줄었다 커졌다 하지 않게)"):format(fr and fr[5] or -1))
end

-- ③ 상품
local p = Cash.product("mount_golem")
expect(p ~= nil and p.kind == "product", "개발자 상품")
eq(p.robux, 399, "값 399")
expect(p.built == true and p.trade == false, "게임에 만들어 둔 것 · 거래 안 됨(계정)")
expect(table.find(BM.shop.rows.look, "mount_golem") ~= nil, "달빛 상점 「꾸밈」 탭")
expect(string.find(p.line, "느") ~= nil, "줄의 설명은 느려진다고(빨라진다가 아니다): " .. tostring(p.line))
local acct = Account.new()
local view = Cash.view(acct, os.time(), nil, 1, {})
for _, v in view.list do
	if v.id == "mount_golem" then
		expect(v.ready == (p.rid ~= 0), "대시보드 번호가 없으면 「준비 중」(살 수 없다)")
	end
end

-- ④ 산 계정에 들어간다
local ok = Cash.grant(acct, "mount_golem", "r-golem-1", os.time(), 6, nil)
expect(ok, "산 것을 준다")
expect(acct.bm.mounts.mount_golem == true, "계정에 이끼 골렘")
