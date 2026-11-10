-- 뽑기 상자를 산 기록 — 겹침의 자동 보상에 쓴다(2026-11-10 사용자: "그사람이 가지고있는 캐시템이랑 산 상자를 비교하면 얼마나 사라졌는지 알수있는거아니야? 정확히 파악해야 내가 보상을하지").
--  출처: 로블록스 「내 거래 → 상품 판매」(economy.roblox.com/v2/users/10311679477/transactions?transactionType=Sale — 에고 라이트로 사용자의 계정에서 읽음) ·
--   2026-06-18 ~ 2026-11-10 14:47:42 UTC의 1,492줄 전부 · 상자 판매 43줄(11-10 10:25 ~ 14:45 UTC · 산 사람 셋).
--  buys[로블록스 계정 번호] = { name = 그때의 로블록스 이름(보기만), <상자> = 산 수, direct = 그 상자에서도 나오는 것을 따로 산 것(옛 상점의 달토끼 — 상자에서 나온 것으로 세지 않는다) }
--  셈은 shared/lune/sim/cash.luau의 Cash.dupfixAuto: 사라진 수 = 산 수 − 그 상자의 것 가운데 가진 수(direct 뺌) → 그만큼 겹침 보상(이미 준 수 fixGiven은 빼고 — 다시 받아 적어도 모자란 만큼만).
--  upTo = 이 기록을 받은 때(유닉스 초) — 이 뒤에 새 서버에서 산 것은 결제의 기록(bm.log)으로 따로 센다.
--  더 산 사람이 생기면(옛 서버가 남아 있던 동안) 판매 기록을 다시 받아 이 표를 새로 적는다
-- 2026-11-10 사용자: "다시 다뺏고 안연상자를 산것보다 카테고리별로 +3인거야 그리고 상자별로 선택상자를 주는걸로" → 이 표로 상자 판매를 바로잡는다(sim/cash.luau Cash.boxReset —
--  계정을 읽을 때 한 번: 상자에서 받은 것을 거두고 · 안 연 상자(산 수 + 3) · 선택 상자 하나를 상자마다). reset = 바로잡기의 차례(올리면 다시 한 번 — 표를 고쳤을 때)
return {
	reset = 1,
	upTo = 1794322062, -- 2026-11-10 14:47:42 UTC
	buys = {
		[1372895479] = { name = "hinoo", dmgskin = 18, mountbox = 7, tagskin = 4, bubblebox = 2, direct = { "pet_silver", "pet_lantern", "pet_scarf" } },
		[1275060964] = { name = "Tuesday", petbox = 3, tagskin = 3, bubblebox = 2, dmgskin = 1, mountbox = 1, direct = { "pet_lantern" } },
		[11858280522] = { name = "1ca_dy1", mountbox = 2, direct = { "pet_scarf" } },
	},
}
