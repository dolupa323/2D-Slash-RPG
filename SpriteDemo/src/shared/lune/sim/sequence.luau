-- 시퀀스(2026-10-30 사용자: "버프를 한버튼에 배치해서 한 버튼만 눌러서 버프를 사용할수있는 시퀀스 기능을 만들어줘 메이플에 이미 있는 기능이야 참고해서 만들어"
--  → "버프 매크로가 아니라고 내가 시퀀스라고 말했잖아"). 메이플스토리 「시퀀스」(스킬 시퀀스 2024-12-19 · 버프 시퀀스 2025-06-19 — 공방 design/ui.js의 SKILLWORDS.seq에 출처)를 따른다.
--  두 가지(kind): "skill" = 스킬 시퀀스(배운 「누르면 바로 걸리는 버프」 · 「바로 놓이는 설치 · 소환」) · "buff" = 버프 시퀀스(버프 아이템 — 경험치 · 드롭률 쿠폰 — 과 공용 버프)
--  캐릭터마다 저장 = h.seqs { skill = { { 이름표, … } × N.skill }, buff = { … × N.buff } } · 바꾸기 = 서버 "Sequence"(kind, 번호, 목록 — Hero.setSeq)
--  퀵슬롯의 이름표 = seq_<번호>(스킬) · bseq_<번호>(버프) — sim/hero.luau Hero.canSlot. 쓰기 = 화면(client boot.luau runSeq): 앞 칸부터 — 됐으면 ok초 · 안 됐으면 fail초 · 아이템은 item초 뒤 다음
--  (같은 폴더의 macro.luau는 「매크로 확인」(매크로 사용자 잡기)의 셈이다 · 다른 것)
local root = script.Parent.Parent
local UI = require(root.data["ui.generated"])
local COMBAT = require(root.data["combat.generated"])
local CLASSES = require(root.data["classes.generated"])
local Buffs = require(script.Parent.buffs)

local Seq = {}
Seq.DATA = UI.skillWords.seq
Seq.KINDS = { "skill", "buff" }
Seq.N = { skill = Seq.DATA.kinds.skill.n, buff = Seq.DATA.kinds.buff.n }
Seq.SIZE = { skill = Seq.DATA.kinds.skill.size, buff = Seq.DATA.kinds.buff.size }
local ITEM = {} -- 버프 시퀀스에 넣는 아이템
for _, id in Seq.DATA.items do
	ITEM[id] = true
end
Seq.ITEM = ITEM

-- 퀵슬롯의 이름표
function Seq.id(kind: string, k: number): string
	return (if kind == "buff" then "bseq_" else "seq_") .. k
end
-- 퀵슬롯에 놓인 것이 시퀀스면 그 가지 · 번호
function Seq.of(what: any): (string?, number?)
	if typeof(what) ~= "string" then
		return nil, nil
	end
	local b = tonumber(string.match(what, "^bseq_(%d+)$"))
	if b and b >= 1 and b <= Seq.N.buff then
		return "buff", b
	end
	local k = tonumber(string.match(what, "^seq_(%d+)$"))
	if k and k >= 1 and k <= Seq.N.skill then
		return "skill", k
	end
	return nil, nil
end
-- 이름(「스킬 시퀀스 1」)
function Seq.name(kind: string, k: number): string
	return (string.gsub(Seq.DATA.name[kind] or "", "{n}", tostring(k)))
end

function Seq.new()
	local out = {}
	for _, kind in Seq.KINDS do
		out[kind] = {}
		for k = 1, Seq.N[kind] do
			out[kind][k] = {}
		end
	end
	return out
end

-- 그 시퀀스에 넣을 수 있는가
--  스킬: 배운 「누르면 바로 걸리는 버프」(공용 포함) · 배운 「바로 놓이는 설치 · 소환」(쓰는 동작이 있는 것 — 연막탄 — 은 아니다)
--  버프: 버프 아이템(가지지 않아도 넣어 둔다 — 메이플의 버프 매니저처럼) · 배운 공용 버프
function Seq.can(h, kind: string, id: any): boolean
	if typeof(id) ~= "string" then
		return false
	end
	if kind == "buff" then
		if ITEM[id] then
			return true
		end
		return Buffs.instant(id) and Buffs.data[id].who == "all" and Buffs.learned(h, id)
	end
	if kind ~= "skill" then
		return false
	end
	if Buffs.instant(id) then
		return Buffs.learned(h, id)
	end
	local placed = COMBAT.placed[id]
	return placed ~= nil and placed.cast == "instant" and not Buffs.is(id) and placed.who == h.class and (h.skills[id] or 0) > 0
end

-- 넣을 수 있는 것들(스킬 창의 차례 — 차수마다 · 그 안의 차례 — 다음에 나머지 버프 · 버프는 아이템이 먼저)
function Seq.candidates(h, kind: string): { string }
	local out, seen = {}, {}
	local function add(id: string)
		if not seen[id] and Seq.can(h, kind, id) then
			seen[id] = true
			table.insert(out, id)
		end
	end
	if kind == "buff" then
		for _, id in Seq.DATA.items do
			add(id)
		end
	end
	local cls = CLASSES.classes[h.class]
	for _, t in (cls and cls.tiers) or {} do
		for _, sk in t.skills do
			add(sk.id)
		end
	end
	local rest = {}
	for id in Buffs.data do
		if not seen[id] and Seq.can(h, kind, id) then
			table.insert(rest, id)
		end
	end
	table.sort(rest)
	for _, id in rest do
		add(id)
	end
	return out
end

-- 시퀀스 하나(받은 목록)를 거른다: 꼴이 틀리면 nil · 넣을 수 없는 것 · 겹친 것은 뺀다 · SIZE까지
function Seq.cleanOne(h, kind: string, list: any): { string }?
	local size = Seq.SIZE[kind]
	if not size or typeof(list) ~= "table" or #list > size * 2 then
		return nil
	end
	local out, seen = {}, {}
	for _, id in list do
		if typeof(id) ~= "string" or #id > 40 then
			return nil
		end
		if not seen[id] and Seq.can(h, kind, id) and #out < size then
			seen[id] = true
			table.insert(out, id)
		end
	end
	return out
end

-- 저장된 시퀀스들을 읽는다(없으면 · 꼴이 틀리면 빈 것 — 배우지 않은 스킬은 빠진다)
function Seq.clean(h, data: any)
	local out = Seq.new()
	if typeof(data) == "table" then
		for _, kind in Seq.KINDS do
			local got = data[kind]
			if typeof(got) == "table" then
				for k = 1, Seq.N[kind] do
					out[kind][k] = Seq.cleanOne(h, kind, got[k]) or {}
				end
			end
		end
	end
	return out
end

-- 저장할 꼴(깊은 복사)
function Seq.copy(seqs)
	local out = Seq.new()
	for _, kind in Seq.KINDS do
		for k = 1, Seq.N[kind] do
			out[kind][k] = table.clone((seqs and seqs[kind] and seqs[kind][k]) or {})
		end
	end
	return out
end

return Seq
