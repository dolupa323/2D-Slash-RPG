-- 조작 안내의 글 — 처음 하는 사람에게 지금 누를 키를 한 줄로 알려 준다(공방 js/lune/design/startplan.js의 차례 ② 「첫 5분」 · basics.js의 START).
--  화면을 모르는 셈이다: 캐릭터의 지금 상태에서 그때그때 고른다 — 무엇을 봤는지 따로 저장하지 않는다(할 일을 하면 그 안내는 저절로 사라진다).
--  맨 처음에만 가르친다(사용자 2026-10-11: "레벨업 했을때 능력치, 스킬 찍으라고 계속 글씨뜨는거 이거 빼세요 맨처음 튜토리얼때 가르쳐주는거지 계속적인 알림을 보내는게 아닙니다."):
--   첫 사냥 퀘스트 「마을 밖의 그림자」를 돌려주면 그 뒤로는 어떤 안내도 뜨지 않는다. 능력치 · 스킬을 찍으라는 안내는 처음 점수를 받은 Lv.2에서만 뜬다(그 뒤의 레벨업에서는 뜨지 않는다).
--  그리는 것은 client/lune/guide.luau. 자동 검사(27_lune_start)가 모든 안내 글이 칸(W x LINES줄)에 들어가는지 본다.
local Quests = require(script.Parent.Parent.sim.quests)

local Guide = {}
Guide.W, Guide.LINES = 420, 2 -- 안내 글의 칸(화면 틀의 고운 격자의 점 · 작은 글씨)
Guide.UNTIL = 5 -- 이 레벨이 지나면 조작 안내는 뜨지 않는다(퀘스트의 길잡이는 알리미가 한다)

-- 지금 띄울 안내를 고른다. s = 지금의 상태:
--  { level, quests(book), scene(장면 이름표), touch(스마트폰 단추인가), nearNpc(가까이 선 주민의 id), drop(주울 것이 발밑에 있는가), hpShare(체력 0~1), potions(가방의 물약 수),
--    ap · sp(안 찍은 점수), key = function(하는 일) → 키 이름, slotOf = function(갈래 "mob" · "boss" · "move" · "potion") → 그것이 놓인 칸의 키 이름과 이름(없으면 nil) }
--  돌려주는 것: 안내 글(없으면 nil). 화면을 모르는 셈이라 자동 검사가 그대로 부른다
function Guide.pick(s): string?
	if s.level > Guide.UNTIL then
		return nil
	end
	local book = s.quests or {}
	local key = s.key
	local first, second = book.r1m1, book.r1m2
	-- 튜토리얼(첫 기술 → 첫 사냥)이 끝났으면 더 가르치지 않는다
	if second and second.done then
		return nil
	end
	-- ① 첫 퀘스트 「첫 기술」: 사제에게 걸어가서 말을 걸어 받고, 한 번 더 말을 걸어 끝낸다(새 캐릭터 — Lv.1). 받기 전(first == nil)에도 뜬다 — 퀘스트는 저절로 받지 않는다
	if not (first and first.done) and s.level <= 1 then
		if s.scene ~= "in_shrine" then
			return "달의 사당의 그믐 사제에게 간다"
		elseif s.nearNpc == "master" then
			local what = if first then "한 번 더 말을 걸어 「첫 기술」을 끝낸다" else "그믐 사제에게 말을 걸어 「첫 기술」을 받는다"
			return if s.touch then ("「말 걸기」 단추: %s"):format(what) else ("%s 키: %s"):format(key("up"), what)
		end
		return if s.touch then "왼쪽 아래의 조이스틱으로 걷는다 — 그믐 사제에게 간다" else ("%s %s 키로 걷는다 — 그믐 사제에게 간다"):format(key("left"), key("right"))
	end
	-- ② 주울 것이 발밑에 있다
	if s.drop then
		return if s.touch then "「줍기」 단추: 떨어진 것을 줍는다" else ("%s 키: 떨어진 것을 줍는다"):format(key("pickup"))
	end
	-- ③ 체력이 절반 아래다
	if s.hpShare < 0.5 and s.potions > 0 then
		local potionKey = s.slotOf("potion")
		if potionKey then
			return if s.touch then "물약 단추: 체력을 되찾는다" else ("%s 키: 물약을 마신다"):format(potionKey)
		end
	end
	-- ④ 처음 받은 점수를 찍는다(능력치 → 스킬) — 길 안내보다 먼저: 찍지 않으면 사냥이 느리다. 처음 점수를 받은 Lv.2에서만(그 뒤의 레벨업마다 되풀이하지 않는다)
	if s.level == 2 then
		if s.ap > 0 then
			return if s.touch then "「메뉴」 → 능력치: 받은 점수를 찍는다(「자동으로 찍기」)" else ("%s 키: 능력치 창 — 받은 점수를 찍는다(「자동으로 찍기」)"):format(key("win:stat"))
		elseif s.sp > 0 then
			return if s.touch then "「메뉴」 → 스킬: 스킬 포인트로 스킬을 올린다(「추천대로 찍기」)" else ("%s 키: 스킬 창 — 스킬 포인트로 스킬을 올린다(「추천대로 찍기」)"):format(key("win:skill"))
		end
	end
	-- ⑤ 첫 사냥 「마을 밖의 그림자」: 받기 전에는 샛별에게, 받은 뒤에는 문 밖으로, 사냥터에서는 기술의 키
	if first and first.done and not (second and second.done) then
		if not second then
			if s.scene == "in_shrine" then
				return if s.touch then "문 앞에서 「들어가기」 단추: 사당 밖으로 나간다" else ("문 앞에서 %s 키: 사당 밖으로 나간다"):format(key("up"))
			elseif s.scene == "town" then
				return if s.touch
					then "「점프」로 뛴다 · 조이스틱 아래 + 「점프」로 내려간다 — 샛별은 맨 아래 길의 왼쪽"
					else ("%s 키로 뛴다 · %s + %s 키로 내려간다 — 샛별은 맨 아래 길의 왼쪽"):format(key("jump"), key("down"), key("jump"))
			end
		elseif not Quests.isReady(book, "r1m2") then
			if s.scene == "r1a1" then
				local mobKey, mobName = s.slotOf("mob")
				local moveKey, moveName = s.slotOf("move")
				if s.touch then
					return "오른쪽 아래의 기술 단추로 수습 검병을 쓰러뜨린다"
				elseif mobKey and moveKey then
					return ("수습 검병을 쓰러뜨린다 — %s 키: %s · %s 키: %s"):format(mobKey, mobName, moveKey, moveName)
				end
			elseif s.scene == "town" then
				return if s.touch then "마을 왼쪽 끝의 문 앞에서 「들어가기」 단추: 마을 어귀로 나간다" else ("마을 왼쪽 끝의 문 앞에서 %s 키: 마을 어귀로 나간다"):format(key("up"))
			end
		end
	end
	return nil
end

return Guide
