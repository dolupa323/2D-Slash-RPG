-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 음악: tracks = 배경 음악(이름표 → 오디오 번호 · 크기) · jingles = 징글(번호 · 크기 · 길이 — 레벨 업 · 전직) · sfx = 효과음(번호 · 크기 · 틈) · scene = 장면 → 배경 음악의 이름표 · hidden = 숨은 방(들어설 때 효과음 secret3) · title = 처음 화면의 곡
-- fade = 곡이 넘어가는 시간(초) · duck = 징글 동안 배경 음악의 크기 배수. 번호가 빈 곡은 아직 올리지 않은 것이다(게임은 건너뛴다).
return {
	tracks = {
		title = { id = "rbxassetid://108938411850831", volume = 0.042 },
		dream = { id = "rbxassetid://107384588322765", volume = 0.058 },
		town = { id = "rbxassetid://94891703951435", volume = 0.069 },
		field_a = { id = "rbxassetid://112773487319935", volume = 0.258 },
		field_b = { id = "rbxassetid://126305062295156", volume = 0.02 },
		field_c = { id = "rbxassetid://136561045038967", volume = 0.057 },
		dark = { id = "rbxassetid://93422022707334", volume = 0.018 },
		lair = { id = "rbxassetid://103009526667711", volume = 0.024 },
	},
	jingles = {
		victory = { id = "rbxassetid://93782438182811", volume = 0.36, sec = 1.2 },
		jobup = { id = "rbxassetid://80598227621761", volume = 0.4, sec = 1.3 },
	},
	sfx = {
		damage = { id = "rbxassetid://140612589056574", volume = 0.05, gap = 0, upto = 0.2 },
		coin = { id = "rbxassetid://79292770217834", volume = 0.4, gap = 0.05 },
		pick = { id = "rbxassetid://111062578947331", volume = 0.6, gap = 0.05 },
		gameover = { id = "rbxassetid://107365336695883", volume = 0.6, gap = 1 },
		success = { id = "rbxassetid://71717913154830", volume = 0.18, gap = 0.5 },
		secret2 = { id = "rbxassetid://133179236459298", volume = 0.17, gap = 0.5 },
		secret3 = { id = "rbxassetid://92242689796809", volume = 0.5, gap = 0.5 },
		secret4 = { id = "rbxassetid://97651473620570", volume = 0.5, gap = 0.5 },
	},
	scene = { hunt = "field_a", town = "town", in_storage = "town", in_store = "town", in_elder = "town", in_forge = "town", in_hall = "town", in_shrine = "town", in_cellar = "dark", r1a1 = "field_a", dream = "dream", r1af = "town", r1a3 = "field_a", r1a4 = "field_a", r1b1 = "field_b", r1b2 = "field_b", r1bv = "town", r1b3 = "field_b", r1cc = "town", r1c1 = "field_c", r1c2 = "field_c", r1c3 = "field_c", r2a1 = "field_b", r2a2 = "field_b", r2af = "town", r2a3 = "field_b", r2a4 = "field_b", r2b1 = "dark", r2b2 = "dark", r2b3 = "dark", r2bs = "town", r2b4 = "dark", r2c1 = "dark", r2c2 = "dark", r2c3 = "dark", ct = "town", port = "town", r3a1 = "dark", r3a2 = "dark", r3ah = "town", r3a3 = "dark", r3a4 = "dark", r3b1 = "field_c", r3b2 = "field_c", r3t = "town", r3c1 = "field_c", r3c2 = "field_c", r3cs = "town", r3c3 = "field_c", r3d1 = "field_c", r3d2 = "field_c", r3d3 = "field_c", r4a1 = "field_c", r4a2 = "field_c", r4a3 = "field_c", r4a4 = "field_c", r4b1 = "field_c", r4b2 = "field_c", r4b3 = "dark", r4bh = "town", r4b4 = "field_c", r4c1 = "field_c", r4c2 = "dark", r4ch = "town", r4c3 = "dark", r4d1 = "dark", r4d2 = "dark", seat = "town", sea1 = "field_b", sea2 = "field_b", r3b3 = "field_c", r3b4 = "field_c", r4d3 = "dark", r4e1 = "dark", sea5 = "dark", sea6 = "dark", r1c4 = "lair", r2c4 = "lair", r3d4 = "lair", r4d4 = "lair", sea8 = "lair", r4es = "town", r1bl = "lair", r2bl = "lair", r2cl = "lair", r3al = "lair", r3cl = "lair", r4bl = "lair", r4cl = "lair", r4dl = "lair", r1bh = "dark", r2ah = "dark", r2bh = "dark", r3bh = "dark", r4ah = "dark", r4dh = "dark", sea3 = "dark", seaf = "town", sea4 = "dark", sea7 = "dark", dg1 = "field_a", ct_store = "town", ct_smith = "town", ct_storage = "town", ct_auction = "town", ct_office = "town", ct_harbor = "town", ct_inn = "town", ct_fisher = "town", ct_stable = "town", ct_spice = "town", ct_guardpost = "town", ct_musician = "town", ct_flower = "town", ct_oldhouse = "town", ct_scribe = "town", ct_maid = "town", ct_castle = "town", ct_terrace = "town", ct_tower = "town", ship_out = "field_b", ship_home = "field_b", ship_sea_out = "field_b", ship_sea_home = "field_b", air_out = "town", air_home = "town", rf1 = "dark", rf2 = "dark", rf3 = "dark" },
	hidden = { r1bh = true, r2ah = true, r2bh = true, r3bh = true, r4ah = true, r4dh = true },
	title = "title",
	fade = 1.2,
	duck = 0.35,
}
