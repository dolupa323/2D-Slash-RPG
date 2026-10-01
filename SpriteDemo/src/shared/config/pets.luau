-- 펫(잡은 몬스터) 저장·편성 규칙(클라이언트·서버 공용) — GAME_DESIGN.md §5, §9.
--  저장 형태(playerSchema v4): Pets = { Box = { 개체... }, Party = { 상자 번호... }, Slots = 열린 슬롯 수, Boxes = 가진 박스 수 }
--   개체 = { S = 종 id, L = 레벨(잡은 레벨 그대로 평생 고정), C = 이로치(1) 아니면 0, B = 맺은 방울 등급(1~5), T = 잡은 시각(os.time) }
--   Box는 빈 칸 없는 촘촘한 배열(DataStore 안전) — 박스 화면의 칸 = 배열 순서. Party는 Box 번호 배열(1번 = 대표 펫, 남에게 보이는 한 마리).
--   Paid = 유료로 산 펫 칸 수(0~2). (Slots 필드는 v4 초기값 — 칸 수는 SlotCount로 계산한다)
local exports = {}

exports.BOX_SIZE = 30 -- 박스 1개 칸 수
exports.BOXES_START = 8 -- 처음 가진 박스(240마리)
exports.BOXES_MAX = 20 -- 최대 박스(600마리)
exports.SLOTS_START = 1 -- 처음 열린 펫 슬롯
exports.SLOTS_MAX = 4 -- 최대 펫 슬롯(3·4번째는 유료)
exports.SLOT2_LEVEL = 20 -- 플레이어 레벨 20이 되면 2번째 슬롯 무료
exports.SHINY_CHANCE = 1 / 2048 -- 이로치(색만 다름)

-- 도감 상태(Dex[종 id] 값)
exports.DEX_SEEN = 1 -- 봤음(싸워서 쓰러뜨림)
exports.DEX_CAUGHT = 2 -- 잡았음

-- 함께 다니는 펫 칸 수: 1칸 기본 + 플레이어 Lv20이면 1칸 무료 + 유료로 산 칸(최대 2, Pets.Paid)
function exports.SlotCount(level: number, paid: number?): number
	local n = exports.SLOTS_START + (if level >= exports.SLOT2_LEVEL then 1 else 0) + math.clamp(paid or 0, 0, 2)
	return math.min(n, exports.SLOTS_MAX)
end

function exports.Capacity(boxes: number): number
	return boxes * exports.BOX_SIZE
end

return exports
