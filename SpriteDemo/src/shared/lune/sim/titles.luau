-- 칭호(2026-10-26 사용자: "지금 레벨 선착순 150 만렙 달성자들 top 10 까지 칭호 만들어서 발급할거고, 강타는 top10 칭호도 주고, 1위 칭호도 줄거야 / 칭호이름 멋지게해서 만들고").
--  캐릭터가 갖는다(h.titles = { [id] = true } — 저장한다) · 이름표 아래에 하나를 단다(h.title = id — 없으면 nil · 다른 사람에게도 보인다).
--  자료 = 공방 js/lune/design/achieve.js의 TITLES(data/achieve.generated.luau의 titles — 목록의 앞일수록 높다). 주는 것은 서버(server/lune/modules/titles.luau)가 세계 기록을 보고 한다 — 여기는 셈만.
local AC = require(script.Parent.Parent.data["achieve.generated"])

local Titles = {}
Titles.LIST = AC.titles.list
Titles.WORDS = AC.titles.words
Titles.CAP = AC.titles.ten -- 「만월의 십인」의 수(만렙에 오른 차례로)

local BY, ORDER = {}, {}
for i, t in Titles.LIST do
	BY[t.id], ORDER[t.id] = t, i
end

function Titles.def(id: any)
	return if typeof(id) == "string" then BY[id] else nil
end

-- 가진 칭호의 목록(높은 차례 — 저장 · 화면에 보내는 꼴)
function Titles.owned(h): { string }
	local list = {}
	for id in h.titles or {} do
		if BY[id] then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return ORDER[a] < ORDER[b]
	end)
	return list
end

-- 저장된 것에서 되살린다(모르는 칭호 · 갖지 않은 칭호를 단 것은 버린다)
function Titles.unpack(h, list: any, worn: any)
	h.titles = {}
	if typeof(list) == "table" then
		for i, id in list do
			if typeof(i) == "number" and i <= 40 and typeof(id) == "string" and BY[id] then
				h.titles[id] = true
			end
		end
	end
	h.title = if typeof(worn) == "string" and h.titles[worn] then worn else nil
end

-- 준다: 새로 받았으면 true. 받은 것이 단 것보다 높으면(또는 단 것이 없으면) 받은 것을 단다
function Titles.give(h, id: string): boolean
	if not BY[id] or h.titles[id] then
		return false
	end
	h.titles[id] = true
	if not h.title or ORDER[id] < ORDER[h.title] then
		h.title = id
	end
	return true
end

-- 단다(""이면 뗀다). 가진 것만 — 됐으면 true
function Titles.wear(h, id: any): boolean
	if id == "" or id == nil or id == false then
		h.title = nil
		return true
	end
	if typeof(id) == "string" and h.titles[id] then
		h.title = id
		return true
	end
	return false
end

-- 「바꾸기」의 다음: 없음 → 가진 것을 높은 차례로 → 없음(가진 것이 없으면 nil)
function Titles.nextOf(h): string?
	local list = Titles.owned(h)
	if #list == 0 then
		return nil
	end
	if not h.title then
		return list[1]
	end
	local i = table.find(list, h.title) or 0
	return list[i + 1] -- 마지막 다음 = 없음(nil)
end

return Titles
