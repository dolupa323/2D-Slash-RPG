-- 본 줄거리 퀘스트 규칙(서버 · 클라이언트 공용). 퀘스트 자료는 공방 설계(dino-workshop/js/ninja/design/story.js)를
-- 그대로 옮긴 shared/data/quests.generated.luau — 차례대로 하나씩 진행한다.
--  저장: data.Quest = { Index = 지금 퀘스트 번호(1부터, 다 끝내면 COUNT + 1), Accepted = 받았는가, Progress = 처치 수 등 }
--  흐름: 주는 사람에게 말을 걸어 받는다 → 목표를 채운다 → 끝낼 사람(TurnIn)에게 말을 건다.
--        가기 · 탈것은 그 자리에 닿으면 바로 끝난다. 주는 사람 = 말 걸 사람인 "말 걸기"는 받자마자 끝난다.
local list = require(script.Parent.Parent.data["quests.generated"])

local exports = {}

exports.LIST = list
exports.COUNT = #list

function exports.Get(index: number)
	return list[index]
end

-- 끝내러 갈 NPC 키(nil = 닿으면 바로 끝남)
function exports.TurnIn(q): string?
	if q.kind == "reach" or q.kind == "ride" then
		return nil
	end
	return if q.kind == "talk" then q.target else q.giver
end

-- 받자마자 끝나는가
function exports.Instant(q): boolean
	return q.kind == "talk" and q.target == q.giver
end

-- 처치 수를 세는 퀘스트인가(몬스터 · 보스 id = q.target)
function exports.CountsKill(q, speciesId: string): boolean
	return (q.kind == "kill" or q.kind == "boss") and q.target == speciesId
end

-- 목표를 채웠는가. have = 가진 개수(모으기), job = 전직 단계
function exports.Ready(q, progress: number, have: number, job: number): boolean
	if q.kind == "kill" or q.kind == "boss" then
		return progress >= q.count
	elseif q.kind == "collect" then
		return have >= q.count
	elseif q.kind == "job" then
		return job >= (tonumber(q.target) or math.huge)
	elseif q.kind == "talk" then
		return true
	end
	return progress >= 1
end

-- 추적창에 쓰는 한 줄
function exports.Objective(q, accepted: boolean, progress: number, have: number, job: number, level: number): string
	if not accepted then
		if level < q.level then
			return ("Lv.%d부터 · %s"):format(q.level, q.giverName)
		end
		return q.giverName .. "에게 가기"
	end
	if q.kind == "talk" then
		return q.targetName .. "에게 가기"
	elseif q.kind == "reach" then
		return q.targetName .. " 가기"
	elseif q.kind == "ride" then
		return q.targetName .. " 타기"
	end
	if exports.Ready(q, progress, have, job) then
		return q.giverName .. "에게 돌아가기"
	end
	if q.kind == "job" then
		return q.targetName .. " 하기"
	end
	local n = if q.kind == "collect" then have else progress
	return ("%s %d/%d"):format(q.targetName, math.min(n, q.count), q.count)
end

-- 보상 아이템 id("SchoolScroll" = 내 유파의 두루마리. 유파가 없으면 nil)
local SCROLL = { fire = "ScrollFire", ice = "ScrollIce", plant = "ScrollPlant", rock = "ScrollRock", thunder = "ScrollThunder" }
function exports.RewardItem(q, school: string?): string?
	if q.item == "SchoolScroll" then
		return SCROLL[school or ""]
	end
	return q.item
end

return exports
