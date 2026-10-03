-- NPC 가게 — 가게 id마다: 어느 NPC(공방 js/npc.js 역할 id)에게 말을 걸면 열리는지, 제목, 파는 물건(items.luau id, 값은 Price).
-- 파는 쪽(판매)은 가게와 상관없이 SellPrice가 있는 아이템이면 어디서든 팔 수 있다.
return {
	potion = {
		npc = "potion",
		title = "밥집",
		goods = { "Onigiri", "Sushi", "Yakitori" },
	},
	-- 잡화 상점: 투척 무기(수리검 · 쿠나이 · 폭탄) + 들판 무기(닌자도 · 사이 · 곤봉). 포획 방울은 팔지 않는다(포획 꺼 둠).
	merchant = {
		npc = "merchant",
		title = "잡화 상점",
		goods = { "Shuriken", "Kunai", "Bomb", "Ninjato", "Sai", "Club", "GuardCharm" },
	},
}
