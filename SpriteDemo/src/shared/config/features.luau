-- 기능 스위치(클라이언트·서버 공용) — 「오문 닌자전」 기획(NINJA_DESIGN.md §13)에서 지금은 빼 둔 것들.
--  코드는 지우지 않고 꺼 둔다. 나중에 다시 켤 때 여기만 바꾸면 된다.
return {
	-- 어느 게임을 켤 것인가: "ninja" = 「오문 닌자전」(탑다운, 멈춰 둔 것) · "lune" = 「달의 계승자」(횡스크롤 MMORPG, 지금 만드는 것).
	--  두 게임의 코드는 섞이지 않는다 — lune은 shared/lune · server/lune · client/lune 아래에만 있다.
	GAME = "lune",
	PETS = false, -- 펫(소환수): 나중에 BM으로 넣는다 — 펫 상자 · 따라다니기 · 펫 스킬
	CAPTURE = false, -- 포획(맺음 방울 던지기)
}
