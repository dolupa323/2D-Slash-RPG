-- 「달의 계승자」 — 영문(2026-10-27 사용자 "한국어유저가 아닌 유저들이 들어왔을때 모든게 영문번역 되어야해 서비스제공이 누락사안없이").
--  ① 바꾸는 셈(shared/lune/lang.luau): 사전 · 숫자 자리(#) · 틀(%s · {이름}) · 이은 글 · 앞뒤의 괄호 · 바꾸지 않는 글 · 못 바꾼 것을 적는다 · 한국어면 그대로 · 언어 고르기
--  ② 실제 사전(data/lang_en.generated.luau)이 게임의 한국어 글을 빠짐없이 덮는가: 공방 tools/lang_keys.mjs가 뽑은 열쇠(lang/keys.json)를 시험이 다시 뽑지 않고 — 게임의 코드 · 데이터를 여기서 훑는다
MOCK("ReplicatedStorage/shared/lune/data/lang_en.generated", { words = {
	["받는 피해 -#% · 같은 맵의 파티원에게도 — #초"] = "Damage taken -#% · also party on the same map — #s",
	["초승달 마을"] = "Crescent Village",
	["%s — 영구 정지했다"] = "{1} — permanently banned",
	["{name}에 닿았다"] = "Arrived at {1}",
	["{name}까지 달돈 {n}이네. 가겠나?"] = "{1} costs {2} Moon Coins. Shall we go?",
	["Lv.# · %s"] = "Lv.# · {1}",
	["정류장"] = "Station",
	["#번째 · #마리"] = "#2 mobs · #1st", -- (번호 붙은 숫자 자리)
	["역마차"] = "Stagecoach",
	["자동"] = "Auto",
	["큰 도끼"] = "Greataxe",
	["빼어난"] = "Superb",
	["큰"] = "Big",
	["주민: "] = "NPCs: ",
	[" (부서짐)"] = " (Broken)",
	["레벨 업! Lv."] = "Level Up! Lv.",
	["달래"] = "Dallae",
	["샛별"] = "Saetbyeol",
	["{name} {n}마리"] = "{1} ×{2}",
	["{weapon} {name}!"] = "{2}'s {1}!",
} })
local Lang = req("ReplicatedStorage/shared/lune/lang")
eq(Lang.t("초승달 마을"), "초승달 마을", "한국어면 그대로")
Lang.set("en")
eq(Lang.t("초승달 마을"), "Crescent Village", "사전")
eq(Lang.t("받는 피해 -10.5% · 같은 맵의 파티원에게도 — 60초"), "Damage taken -10.5% · also party on the same map — 60s", "숫자 자리(#)에 그 숫자를 차례로")
eq(Lang.t("3번째 · 12마리"), "12 mobs · 3st", "#2 · #1 = 번째 숫자")
eq(Lang.t("클라 — 영구 정지했다"), "클라 — permanently banned", "틀(%s): 채운 값(이름)은 그대로 · 나머지는 영문")
eq(Lang.t("초승달 마을에 닿았다"), "Arrived at Crescent Village", "틀({name}): 채운 값도 바꾼다")
eq(Lang.t("초승달 마을까지 달돈 130이네. 가겠나?"), "Crescent Village costs 130 Moon Coins. Shall we go?", "틀의 자리 둘")
eq(Lang.t("Lv.30 · 초승달 마을"), "Lv.30 · Crescent Village", "틀 + 숫자")
eq(Lang.t("초승달 마을 · 정류장"), "Crescent Village · Station", "이은 글: 조각마다")
eq(Lang.t("「역마차」"), "「Stagecoach」", "앞뒤의 꺾쇠를 떼고 찾아 다시 붙인다")
eq(Lang.t("(정류장)"), "(Station)", "괄호")
eq(Lang.t("한국어"), "한국어", "언어 이름은 그대로(설정 창)")
eq(Lang.t("English 123"), "English 123", "한글이 없으면 그대로")
local miss = "번역이 없는 글"
eq(Lang.t(miss), miss, "못 바꾸면 그대로")
expect(Lang.missing[miss] == true, "못 바꾼 것을 적는다")
eq(Lang.pick("ko-kr", nil), "ko", "로블록스의 언어가 한국어면 한국어")
eq(Lang.pick("en-us", nil), "en", "그 밖이면 영문")
eq(Lang.pick("ja-jp", "auto"), "en", "자동")
eq(Lang.pick("en-us", "ko"), "ko", "설정 창에서 고른 것이 먼저")
eq(Lang.t("빼어난 Lv.20 큰 도끼"), "Superb Lv.20 Greataxe", "빈칸으로 이은 이름: 가장 긴 낱말 묶음부터(「큰 도끼」를 쪼개지 않는다)")
eq(Lang.t("주민: 달래 · 샛별"), "NPCs: Dallae · Saetbyeol", "앞 조각(「주민: 」) + 나머지")
eq(Lang.t("빼어난 Lv.20 큰 도끼 (부서짐)"), "Superb Lv.20 Greataxe (Broken)", "나머지 + 뒤 조각(「 (부서짐)」)")
eq(Lang.t("레벨 업! Lv.31"), "Level Up! Lv.31", "앞 조각 + 숫자")
Lang.missing["클라"] = nil
eq(Lang.t("클라 — 영구 정지했다"), "클라 — permanently banned", "틀에 채운 사람 이름은 그대로")
eq(Lang.missing["클라"], nil, "채운 사람 이름은 못 바꾼 것으로 적지 않는다")
eq(Lang.t("빼어난 큰 도끼 8마리"), "Superb Greataxe ×8", "숫자 자리({n})는 숫자만 — 이름 자리가 「빼어난 큰 도끼」 모두를 잡는다(「포자 ×주머니 8」이 되지 않게)")
eq(Lang.t("큰 도끼 달래!"), "Dallae's Greataxe!", "짧게 잡아 못 바꾸면(「큰」 · 「도끼 달래」) 길게 잡아 다시")
local Format = req("ReplicatedStorage/shared/lune/ui/format")
eq(Format.short(12000), "12K", "영문의 큰 수: 1.2만 → 12K")
eq(Format.short(1500000), "1.5M", "150만 → 1.5M")
eq(Format.short(950), "950", "작은 수는 그대로")
Lang.set("ko")
eq(Lang.t("초승달 마을"), "초승달 마을", "다시 한국어로")
eq(Format.short(12000), "1.2만", "한국어는 만 · 억")
