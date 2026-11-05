-- 보스의 최초 격파(2026-11-05 사용자: "퍼클 이벤트도 들어가야해 최초 격파 3 파티까지야 3인이 아니고 3파티 퍼클 칭호 깨자마자 바로 지급되어야하고,
--  전 서버에 메시지 송출된다 누구,누구, 누구가 잡았다고"). 셈만 — 저장소(세계 기록 firstClear_<보스>) · 알림은 서버 server/lune/modules/firstClear.luau.
--  기록 = 격파한 차례대로 파티들 { { at, members = { { key(캐릭터), name, class } … } } … } — cap(파티 수 — 공방 design/weekboss.js의 first.parties)까지.
--  이미 기록에 있는 캐릭터가 섞인 파티는 더하지 않는다(같은 사람이 두 자리를 차지하지 않게 — 제가 정한 것).
local FirstClear = {}

local function valid(entry): boolean
	if typeof(entry) ~= "table" or typeof(entry.members) ~= "table" or #entry.members == 0 then
		return false
	end
	for _, m in entry.members do
		if typeof(m) ~= "table" or typeof(m.key) ~= "string" or typeof(m.name) ~= "string" then
			return false
		end
	end
	return true
end
FirstClear.valid = valid

-- 그 캐릭터가 든 파티의 차례(1부터 — 없으면 nil)
function FirstClear.rankOf(list: any, key: string): number?
	if typeof(list) ~= "table" then
		return nil
	end
	for i, entry in list do
		if valid(entry) then
			for _, m in entry.members do
				if m.key == key then
					return i
				end
			end
		end
	end
	return nil
end

-- 파티를 더해 본다 → (새 목록, 차례) · 더하지 못하면 (nil, nil, 까닭 "full" · "already" · "bad")
function FirstClear.add(list: any, entry, cap: number)
	local old = if typeof(list) == "table" then list else {}
	if not valid(entry) then
		return nil, nil, "bad"
	elseif #old >= cap then
		return nil, nil, "full"
	end
	for _, m in entry.members do
		if FirstClear.rankOf(old, m.key) then
			return nil, nil, "already"
		end
	end
	local new = table.clone(old)
	table.insert(new, entry)
	return new, #new, nil
end

-- 알림의 이름들 「달그림자, 수정바람, 은빛도끼」
function FirstClear.names(entry): string
	local out = {}
	for _, m in (entry and entry.members) or {} do
		table.insert(out, m.name)
	end
	return table.concat(out, ", ")
end

return FirstClear
