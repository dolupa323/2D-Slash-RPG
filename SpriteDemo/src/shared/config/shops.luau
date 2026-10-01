-- NPC 가게 — 가게 id마다: 어느 NPC(공방 js/npc.js 역할 id)에게 말을 걸면 열리는지, 제목, 파는 물건(items.luau id, 값은 Price).
-- 파는 쪽(판매)은 가게와 상관없이 SellPrice가 있는 아이템이면 어디서든 팔 수 있다.
return {
	potion = {
		npc = "potion",
		title = "포션 상점",
		goods = { "RedPotion", "OrangePotion", "WhitePotion" },
	},
	-- 잡화 상점: 낮은 등급 맺음 방울을 직접 판다(높은 등급은 맺음석 세공 — M6)
	merchant = {
		npc = "merchant",
		title = "잡화 상점",
		goods = { "Bell1", "Bell2" },
	},
}
