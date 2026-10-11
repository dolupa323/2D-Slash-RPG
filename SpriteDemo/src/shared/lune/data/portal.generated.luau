-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 포탈: 맵의 문과 건물의 입구에 똑같이 놓이는 움직이는 그림. img = 그림(가로로 frames장) · w · h = 한 장 · fps = 초당 장 수 · near = 이만큼(도트) 안에 서면 문 위에 「↑ 어디로」를 적는다.
return {
	img = "portal.png",
	w = 22,
	h = 34,
	frames = 8,
	fps = 10,
	near = { x = 30, y = 40 },
}
