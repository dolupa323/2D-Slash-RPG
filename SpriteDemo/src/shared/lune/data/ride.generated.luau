-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 펫 · 탈것(dino-workshop/js/lune/design/ride.js): pets · mounts = 이름(그림은 chars.generated의 같은 이름 — 탈것은 <동작>_front가 영웅 앞에 다시 그리는 점) ·
--  seat = 탈것의 기준점(발밑 가운데)에서 영웅의 발까지(dx는 오른쪽을 볼 때) · bob = 동작의 장마다 영웅을 더 내리는 점(위 = 음수) · pet = 따라오는 자리(behind) · 줍는 거리(reach) · 한 번에 하나씩(every초)
return {
	pets = {
		{ id = "pet_silver", name = "은빛 달토끼" },
		{ id = "pet_lantern", name = "초롱 달토끼" },
		{ id = "pet_scarf", name = "목도리 달토끼" },
	},
	mounts = {
		{
			id = "mount_wolf",
			name = "달빛 늑대",
			seat = { dx = -1, dy = -15 },
			bob = {
				idle = { 0, 0, 0, 0 },
				run = { 0, -1, 0, 0, -1, 0 },
				jump = { -1 },
			},
		},
		{
			id = "mount_deer",
			name = "수정 사슴",
			seat = { dx = -3, dy = -12 },
			bob = {
				idle = { 0, 0, 0, 0 },
				run = { 0, -1, 0, 0, -1, 0 },
				jump = { -1 },
			},
		},
		{
			id = "mount_boar",
			name = "쇠 멧돼지",
			seat = { dx = -3, dy = -15 },
			bob = {
				idle = { 0, 0, 0, 0 },
				run = { 0, -1, 0, 0, -1, 0 },
				jump = { -1 },
			},
		},
	},
	pet = { behind = 44, base = 40, per = 2, max = 160, chase = 150, reach = 96, slack = 32, every = 0.3, windup = 0.2, warpX = 384, warpY = 72, stuck = 1.2, lookUp = 18, lookDown = 4 },
}
