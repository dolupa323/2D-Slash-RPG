-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 펫 · 탈것(dino-workshop/js/lune/design/ride.js): pets · mounts = 이름(그림은 chars.generated의 같은 이름 — 탈것은 <동작>_front가 영웅 앞에 다시 그리는 점) ·
--  seat = 탈것의 기준점(발밑 가운데)에서 영웅의 발까지(dx는 오른쪽을 볼 때) · bob = 동작의 장마다 영웅을 더 내리는 점(위 = 음수) · pet = 따라오는 자리(behind) · 줍는 거리(reach) · 한 번에 하나씩(every초)
--  riderSize = 탄 동안 영웅을 그리는 크기(서기 그림 그대로 줄여서 — 화면 화소에 맞춰 Sprite.sizeOn) · bobx = 동작의 장마다 영웅을 옮기는 가로 점(어깨를 따라 — 오른쪽을 볼 때 · 안장은 <동작>_front에 그려져 있다)
--  seat · bob · bobx는 탈것 그림의 점 — 탈것은 chars.generated의 size배로 그리므로 영웅의 자리도 그 배(rideView) · mountSpeed = 탄 동안 달리기 배수(탈것에 speed가 있으면 그것 — 쿠폰 탈것 1)
--  free · line = 상점에서 팔지 않는 펫 · 탈것(쿠폰으로만 받는다 — 2026-10-21) · 가방의 설명 한 줄
return {
	pets = {
		{ id = "pet_silver", name = "은빛 달토끼" },
		{ id = "pet_lantern", name = "초롱 달토끼" },
		{ id = "pet_scarf", name = "목도리 달토끼" },
		{ id = "pet_crow", name = "아기 재까마귀", free = "coupon", line = "쿠폰으로 받은 펫 — 떨어진 것을 대신 줍는다" },
	},
	mounts = {
		{
			id = "mount_wolf",
			name = "달빛 늑대",
			seat = { dx = -1, dy = -16 },
			bob = {
				idle = { 0, 0, 0, 0 },
				run = { 0, 0, 0, 0, 0, 0 },
				jump = { 0 },
			},
			bobx = {
				idle = { 0, 0, 0, 0 },
				run = { -4, -4, -4, -4, -4, -4 },
				jump = { -4 },
			},
		},
		{
			id = "mount_deer",
			name = "수정 사슴",
			seat = { dx = -3, dy = -14 },
			bob = {
				idle = { 0, 0, 0, 0 },
				run = { -1, -1, -1, -1, -1, -1 },
				jump = { -1 },
			},
			bobx = {
				idle = { 0, 0, 0, 0 },
				run = { 0, 0, 0, 0, 0, 0 },
				jump = { 0 },
			},
		},
		{
			id = "mount_boar",
			name = "쇠 멧돼지",
			seat = { dx = -3, dy = -16 },
			bob = {
				idle = { 0, 0, 0, 0 },
				run = { 1, 1, 1, 1, 1, 1 },
				jump = { 1 },
			},
			bobx = {
				idle = { 0, 0, 0, 0 },
				run = { -6, -6, -6, -6, -6, -6 },
				jump = { -6 },
			},
		},
		{
			id = "mount_book",
			name = "떠도는 책",
			free = "coupon",
			line = "쿠폰으로 받은 탈것 — 걷는 빠르기 그대로",
			speed = 1,
			seat = { dx = -4, dy = -24 },
			bob = {
				idle = { 0, 0, 0, 0, 0, 0 },
				run = { 0, 0, 0, 0, 0, 0 },
				jump = { 0, 0, 0, 0, 0, 0 },
			},
			bobx = {
				idle = { 0, 0, 0, 0, 0, 0 },
				run = { 0, 0, 0, 0, 0, 0 },
				jump = { 0, 0, 0, 0, 0, 0 },
			},
		},
	},
	pet = { behind = 64, base = 40, per = 2, max = 160, chase = 150, reach = 96, slack = 32, every = 0.3, windup = 0.2, warpX = 384, warpY = 72, stuck = 1.2, magnet = 24 },
	riderSize = 1,
	mountSpeed = 1.3,
}
