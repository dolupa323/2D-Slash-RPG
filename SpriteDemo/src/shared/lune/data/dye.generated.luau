-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 무기 · 로브 색 바꾸기(염색 — js/lune/design/dye.js · 2026-10-22). body = 몸(로브)의 점만 흰색으로 담은 판(로브 색을 입혀 겹친다) · point[].page = 무기의 점만 그 색으로 담은 판.
-- 영웅의 장(chars.generated)의 8 · 9번째 수가 이 판에서의 자리다. chips[영웅][색] = 색 칸의 두 색(본색 · 밝은 날 — 0xRRGGBB). base = 「원래」의 두 색
return {
	body = "dye_body.png",
	bodyRgb = 3751494,
	heroes = {
		axion = {
			hair = false,
			base = { 4128727, 11337687 },
			chips = {
				gold = { 16764222, 16765868 },
				flame = { 16733758, 16755896 },
				violet = { 11353855, 12954879 },
				sky = { 4108543, 11334911 },
				leaf = { 5242686, 13303724 },
				silver = { 13030374, 14213606 },
			},
		},
		riven = {
			hair = false,
			base = { 4128727, 11337687 },
			chips = {
				gold = { 16764222, 16765868 },
				flame = { 16733758, 16755896 },
				violet = { 11353855, 12954879 },
				sky = { 4108543, 11334911 },
				leaf = { 5242686, 13303724 },
				silver = { 13030374, 14213606 },
			},
		},
		reaper = {
			hair = false,
			base = { 16727711, 16744098 },
			chips = {
				gold = { 16764478, 16776062 },
				flame = { 16734014, 16755838 },
				violet = { 11419391, 15105791 },
				sky = { 4108287, 8302079 },
				leaf = { 5242686, 8322960 },
				silver = { 13030374, 13751782 },
			},
		},
		mooni = {
			hair = false,
			base = { 4128727, 11337687 },
			chips = {
				gold = { 16764222, 16765868 },
				flame = { 16733758, 16755896 },
				violet = { 11353855, 12954879 },
				sky = { 4108543, 11334911 },
				leaf = { 5242686, 13303724 },
				silver = { 13030374, 14213606 },
			},
		},
		salamander = {
			hair = true,
			base = { 16727711, 11607973 },
			chips = {
				gold = { 16764478, 11620127 },
				flame = { 16734014, 11607881 },
				violet = { 11419391, 3612593 },
				sky = { 4108287, 2077105 },
				leaf = { 5242686, 6861087 },
				silver = { 13030374, 8952735 },
			},
		},
	},
	point = {
		{ id = "gold", name = "금빛", page = "dye_p_gold.png" },
		{ id = "flame", name = "불꽃", page = "dye_p_flame.png" },
		{ id = "violet", name = "보라", page = "dye_p_violet.png" },
		{ id = "sky", name = "하늘", page = "dye_p_sky.png" },
		{ id = "leaf", name = "풀빛", page = "dye_p_leaf.png" },
		{ id = "silver", name = "은빛", page = "dye_p_silver.png" },
	},
	robe = {
		{ id = "navy", name = "남색", rgb = 2898526 },
		{ id = "wine", name = "자주", rgb = 5385284 },
		{ id = "forest", name = "숲", rgb = 2902586 },
		{ id = "brown", name = "갈색", rgb = 5127214 },
		{ id = "blood", name = "핏빛", rgb = 5909034 },
		{ id = "ash", name = "잿빛", rgb = 5923182 },
	},
	words = {
		title = { point = "무기 색 바꾸기", hair = "머리 색 바꾸기", robe = "로브 색 바꾸기" },
		text = "색을 고르고 「변경」 — 염색약 한 개를 쓴다",
		have = "가진 염색약 {n}개",
		base = "원래",
		go = "변경",
		done = "색을 바꿨다 — 「{name}」",
		same = "지금과 같은 색이다",
		none = "염색약이 없다",
		pick = "바꿀 색을 고르세요",
	},
}
