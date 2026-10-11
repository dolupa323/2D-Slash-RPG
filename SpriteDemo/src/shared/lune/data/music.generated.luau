-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 음악: tracks = 배경 음악(이름표 → 오디오 번호 · 크기) · jingles = 징글(번호 · 크기 · 길이) · scene = 장면 → 배경 음악의 이름표 · hidden = 숨은 방(들어설 때 징글) · title = 처음 화면의 곡
-- fade = 곡이 넘어가는 시간(초) · duck = 징글 동안 배경 음악의 크기 배수. 번호가 빈 곡은 아직 올리지 않은 것이다(게임은 건너뛴다).
return {
	tracks = {
		title = { id = "", volume = 0.13 },
		town = { id = "", volume = 0.57 },
		field_a = { id = "", volume = 1.03 },
		field_b = { id = "", volume = 1.92 },
		field_c = { id = "", volume = 0.75 },
		dark = { id = "", volume = 0.54 },
		lair = { id = "", volume = 0.13 },
		boss = { id = "", volume = 0.13 },
	},
	jingles = {
		complete = { id = "", volume = 1.67, sec = 4.9 },
		victory = { id = "", volume = 0.7, sec = 6.4 },
		death = { id = "", volume = 1.88, sec = 3.6 },
		strange = { id = "", volume = 3.01, sec = 3.2 },
	},
	sfx = {
		hit1 = { id = "", volume = 0.5, gap = 0.07 },
		hit2 = { id = "", volume = 0.5, gap = 0.07 },
		hit3 = { id = "", volume = 0.5, gap = 0.07 },
		hitBig = { id = "", volume = 0.6, gap = 0.07 },
		kill = { id = "", volume = 0.55, gap = 0.1 },
		hurt = { id = "", volume = 0.55, gap = 0.2 },
		coin = { id = "", volume = 0.4, gap = 0.05 },
		pick = { id = "", volume = 0.6, gap = 0.05 },
	},
	scene = { hunt = "field_a", town = "town", in_storage = "town", in_store = "town", in_elder = "town", in_forge = "town", in_hall = "town", in_shrine = "town", r1a1 = "field_a", r1af = "town", r1a3 = "field_a", r1a4 = "field_a", r1b1 = "field_b", r1b2 = "field_b", r1bv = "town", r1b3 = "field_b", r1b4 = "field_c", r1cc = "town", r1c1 = "field_c", r1c2 = "field_c", r1c3 = "field_c", r2t = "town", r2a1 = "field_b", r2a2 = "field_b", r2af = "town", r2a3 = "field_b", r2a4 = "field_b", r2b1 = "dark", r2b2 = "dark", r2b3 = "dark", r2bs = "town", r2b4 = "dark", r2c1 = "dark", r2c2 = "dark", r2c3 = "dark", ct1 = "town", ct2 = "town", ct3 = "town", ct4 = "town", ct5 = "town", ct6 = "town", port = "town", r3a1 = "dark", r3a2 = "dark", r3ah = "town", r3a3 = "dark", r3a4 = "dark", r3b1 = "field_c", r3b2 = "field_c", r3t = "town", r3c1 = "field_c", r3c2 = "field_c", r3cs = "town", r3c3 = "field_c", r3d1 = "field_c", r3d2 = "field_c", r3d3 = "field_c", r4a1 = "field_c", r4a2 = "field_c", r4a3 = "field_c", r4a4 = "field_c", r4b1 = "field_c", r4b2 = "field_c", r4b3 = "dark", r4bh = "town", r4b4 = "field_c", r4c1 = "field_c", r4c2 = "dark", r4ch = "town", r4c3 = "dark", r4d1 = "dark", r4d2 = "dark", seat = "town", sea1 = "field_b", sea2 = "field_b", r3b3 = "field_c", r3b4 = "field_c", r4d3 = "dark", r4e1 = "dark", sea5 = "dark", sea6 = "dark", r1c4 = "boss", r2c4 = "boss", r3d4 = "boss", r4d4 = "boss", sea8 = "boss", r4es = "town", r1bl = "lair", r2bl = "lair", r2cl = "lair", r3al = "lair", r3cl = "lair", r4bl = "lair", r4cl = "lair", r4dl = "lair", r1bh = "dark", r2ah = "dark", r2bh = "dark", r3bh = "dark", r4ah = "dark", r4dh = "dark", sea3 = "dark", seaf = "town", sea4 = "dark", sea7 = "dark" },
	hidden = { r1bh = true, r2ah = true, r2bh = true, r3bh = true, r4ah = true, r4dh = true },
	title = "title",
	fade = 1.2,
	duck = 0.35,
}
