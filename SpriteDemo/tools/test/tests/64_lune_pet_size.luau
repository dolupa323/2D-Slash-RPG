-- 「달의 계승자」 — 펫을 그리는 크기(client/lune/sprite.luau의 Sprite.sizeOn — 2026-10-21 사용자 "이게 펫이 해상도가 딱 맞는 크기가 있을거야 좀키우면서 그게 어느정도인지 찾아봐").
--  보는 것: 펫(chars.generated의 size 0.6)의 한 점이 화면마다 정수 화소(점마다 크기가 같다) · 펫이 영웅(키 20점)보다 작다 · 화면에 꽉 차게 키우는 폰(소수 배율)은 그대로 · size 1은 그대로
local stage = { scale = 5 }
MOCK("Client/lune/stage", stage)
local Sprite = req("Client/lune/sprite")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")

local HERO = 20 -- 영웅의 키(점 — 엑시온 서기의 첫 장)
for _, p in RIDE.pets do
	local c = CHARS.chars[p.id]
	expect(c and c.size, p.id .. ": 줄여 그리는 크기가 있다")
	for _, k in { 2, 3, 4, 5, 6, 7, 8, 10 } do
		stage.scale = k
		local s = Sprite.sizeOn(c.size)
		local px = k * s
		expect(math.abs(px - math.floor(px + 0.5)) < 1e-9, ("%s: 배율 %d에서 한 점 %.2f화소 — 정수여야"):format(p.id, k, px))
		expect(math.abs(s - c.size) <= 0.5 / k + 1e-9, ("%s: 배율 %d에서 %.3f배 — 정한 크기 %.2f에서 반 화소 안"):format(p.id, k, s, c.size))
		local tall = (c.oy - 6) * s -- 그림의 키(oy = 위의 빈 줄 6 + 그림의 키 — 공방 lune_ride_hand.mjs의 pad)
		expect(tall < HERO, ("%s: 배율 %d에서 키 %.1f점 — 영웅(%d점)보다 작아야"):format(p.id, k, tall, HERO))
	end
end
stage.scale = 5
eq(Sprite.sizeOn(0.6), 0.6, "1080p(배율 5): 0.6배 = 한 점 3화소")
stage.scale = 6
expect(math.abs(Sprite.sizeOn(0.6) - 4 / 6) < 1e-9, "1440p(배율 6): 한 점 4화소(0.67배)")
stage.scale = 3
expect(math.abs(Sprite.sizeOn(0.6) - 2 / 3) < 1e-9, "720p(배율 3): 한 점 2화소(0.67배)")
stage.scale = 1.8
eq(Sprite.sizeOn(0.6), 0.6, "폰(소수 배율 1.8): 그대로")
stage.scale = 5
eq(Sprite.sizeOn(1), 1, "크기 1은 그대로")
