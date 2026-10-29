-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 기간 이벤트(dino-workshop/js/lune/design/event.js): from · to = [월, 일](그날 0시 ~ 23:59:59 · tz = 세계 표준시 +시간) · candy = 사냥터의 몬스터가 떨어뜨리는 것(chance %)
-- npc = 마을(집)마다 서는 주민(scenes의 npcs에 event = 이 이름표로 들어 있다 — 기간 밖에는 감춘다) · shop = 그 주민의 상점(cost = 사탕 · kind = mount · pet · dskin · dust · title · goods · potion · limit = 계정에 그 해에 몇 번 · roll = 달가루 랜덤 상자의 칸: x = 그 레벨대 달가루 상자의 몇 배 · w = 무게 · say = 알림의 말 · big = 큰 알림)
-- boss = 주간 보스전의 보상의 방에 더하는 사탕 · fly = 사냥터를 날아다니는 장식 · dskins = 데미지 스킨(part = UI 키트의 숫자판) · words = 화면의 글
return {
	list = {
		{
			id = "halloween",
			name = "달빛 할로윈",
			from = { 10, 24 },
			to = { 11, 7 },
			tz = 9,
			candy = { id = "etc_candy", chance = 15 },
			npc = "witch",
			shop = {
				{ id = "mount", kind = "mount", ride = "mount_wolf_hw", cost = 400 },
				{ id = "pet", kind = "pet", ride = "pet_bat_hw", cost = 300 },
				{ id = "dskin", kind = "dskin", dskin = "dskin_halloween", cost = 200 },
				{
					id = "dust",
					kind = "dust",
					cost = 150,
					limit = 5,
					roll = {
						{ x = 0.1, w = 40, say = "dustSmall" },
						{ x = 0.25, w = 25 },
						{ x = 0.5, w = 17 },
						{ x = 1, w = 10 },
						{ x = 2, w = 6, say = "dustBig" },
						{ x = 5, w = 2, say = "dustJackpot", big = true },
					},
				},
				{ id = "title", kind = "title", title = "pumpkin", cost = 100 },
				{ id = "charm", kind = "goods", goods = "charm", n = 1, cost = 20 },
				{ id = "scroll", kind = "goods", goods = "scroll_return", n = 5, cost = 15 },
				{ id = "potion", kind = "potion", n = 20, cost = 10 },
			},
			boss = { normal = 50, hard = 100, pile = 10 },
			fly = {
				kinds = {
					{ "hw_pumpkin", 5 },
					{ "pet_bat_hw", 3 },
					{ "hw_witch", 2 },
				},
				max = 3,
				every = { 3, 7 },
				top = { 18, 70 },
				speed = { 18, 42 },
				bob = 4,
				batSize = 0.6,
			},
			title = "pumpkin",
			dskins = {
				{ id = "dskin_halloween", name = "할로윈 데미지 스킨", part = "dmg_halloween", icon = "dskin_halloween", line = "호박빛 숫자 · 크리티컬은 보랏빛 · 숫자 앞에 작은 호박" },
			},
			words = { bannerSub = "{from} ~ {to} · 사냥터의 몬스터가 호박 사탕을 떨어뜨린다 — 마을의 호박 마녀에게 가져가자", menu = "{what} · 사탕 {n}개", more = "다른 선물 보기", ask = "「{what}」 — 사탕 {n}개와 바꿀까?", yes = "바꾸기", got = "받았다 — {what}", short = "사탕이 모자란다({have}/{n})", once = "이미 받은 선물이다", off = "지금은 할로윈이 아니다", far = "호박 마녀 곁에서 바꿀 수 있다", potionWhat = "{name} {n}개", goodsWhat = "{name} {n}개", titleWhat = "칭호 「{name}」", date = "{m}월 {d}일", shopTitle = "호박 마녀 할로의 상점", candy = "가진 사탕", till = "{to}까지", buy = "구매", own = "보유", soldOut = "다 샀다", count = "{n}/{max}", bought = "받았다 — {what}", dustWhat = "달가루 랜덤 상자", dustGot = "달가루 랜덤 상자 — 달가루 +{n}", dustSmall = "아쉽다… 달가루 +{n}", dustBig = "많이 나왔다! 달가루 +{n}", dustJackpot = "대박! 달가루 +{n}", mountWhat = "탈것 「{name}」", petWhat = "펫 「{name}」", dskinWhat = "{name}" },
		},
	},
}
