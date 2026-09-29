-- NPC 가게 — 가게 id마다: 어느 NPC(공방 js/npc.js 역할 id)에게 말을 걸면 열리는지, 제목, 파는 물건(items.luau id, 값은 Price).
-- 파는 쪽(판매)은 가게와 상관없이 SellPrice가 있는 아이템이면 어디서든 팔 수 있다.
return {
	potion = {
		npc = "potion",
		title = "포션 상점",
		goods = { "RedPotion", "OrangePotion", "WhitePotion" },
	},
}
