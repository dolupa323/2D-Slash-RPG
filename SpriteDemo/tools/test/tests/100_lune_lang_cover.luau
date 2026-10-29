-- 「달의 계승자」 — 영문이 빠짐없이 덮는가(2026-10-27 사용자 "한국어유저가 아닌 유저들이 들어왔을때 모든게 영문번역 되어야해 서비스제공이 누락사안없이").
--  게임의 데이터(data/*.generated — 스킬 · 아이템 · 퀘스트 · 대사 · 맵 · 화면 글 …)에 든 한국어 글을 모두 훑어, 실제 사전(lang_en.generated)으로 영문이 나오는지 본다.
--  코드에 적힌 글은 공방의 규칙 검사(tools/check_lune_design.mjs — tools/lang_keys.mjs가 코드를 훑는다)가 본다. 닉네임 금지어 목록(names)은 화면에 나오지 않아 뺀다.
local Lang = req("ReplicatedStorage/shared/lune/lang")
Lang.set("en")
local MODULES = { "achieve", "attend", "bm", "chars", "cine", "city", "classes", "combat", "daily", "dye", "items", "macro", "numbers", "quests", "ride", "scenes", "title", "ui", "worldmap" }
local seen, count = {}, 0
local function walk(v)
	if typeof(v) == "string" then
		if Lang.hasHangul(v) then
			count += 1
			Lang.t(v)
		end
	elseif typeof(v) == "table" and not seen[v] then
		seen[v] = true
		for _, x in v do
			walk(x)
		end
	end
end
for _, name in MODULES do
	walk(req("ReplicatedStorage/shared/lune/data/" .. name .. ".generated"))
end
local miss = {}
for s in Lang.missing do
	table.insert(miss, s)
end
table.sort(miss)
expect(count > 3000, ("훑은 한국어 글 %d개"):format(count))
expect(#miss == 0, ("영문이 나오지 않는 데이터의 글 %d개(데이터의 한국어 글 %d개 가운데): %s"):format(#miss, count, table.concat(miss, " | ", 1, math.min(#miss, 12))))
Lang.set("ko")
