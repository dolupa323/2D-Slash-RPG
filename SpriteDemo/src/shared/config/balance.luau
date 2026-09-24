-- 게임 규칙 수치(밸런스)의 "단 하나의 출처". 서버와 클라이언트가 같은 값을 각자 하드코딩하면 한쪽만
-- 고쳐서 표시와 실제가 어긋나므로(예: 최대 체력 공식이 클라/서버에 따로 있었음), 규칙에 관련된
-- 숫자와 공식은 전부 여기에만 두고 양쪽이 이 파일을 읽는다.
local balance = {}

-- 성장
balance.BASE_MAX_HEALTH = 100
balance.MAX_HEALTH_PER_LEVEL = 20
balance.BASE_ATTACK = 10
balance.BASE_DEFENSE = 0

function balance.maxHealthFor(level: number): number
	return balance.BASE_MAX_HEALTH + (level - 1) * balance.MAX_HEALTH_PER_LEVEL
end

-- 레벨업 필요 경험치: 1레벨 100, 2레벨 150, ...
function balance.maxExperienceFor(level: number): number
	return 100 + (level - 1) * 50
end

-- 공격(스윙) 최소 간격(초): 서버가 이보다 빠른 공격 요청을 무시한다. 클라이언트 공격 애니메이션(약 0.88초)보다
-- 약간 짧게 잡아 네트워크 지터로 정상 연속 공격이 막히지 않게 한다.
balance.ATTACK_COOLDOWN = 0.6

-- 히어로 스프라이트의 화면 표시 크기(px). 클라이언트 heroController가 이 높이로 그리고(가로는 시트 프레임 비율 192:108),
-- 서버의 포탈 이동 승인 판정도 같은 크기를 쓴다 — 캐릭터 크기를 바꿀 땐 HERO_HEIGHT 하나만 고치면 둘 다 따라간다.
balance.HERO_HEIGHT = 135
balance.HERO_WIDTH = math.floor(balance.HERO_HEIGHT * 192 / 108 + 0.5)
-- 시트 프레임 안에서 발이 있는 세로 위치(프레임 높이 대비, 위=0 → 아래=1). 히어로 히트박스의 바닥(땅에 닿는 선)을 여기에 맞춘다.
balance.HERO_FEET_FRACTION = 0.767
-- 충돌 판정선(히트박스 바닥)이 그림 속 발보다 이만큼(프레임 높이 대비) "위"에 오게 한다 — 판정선이 발과 정확히 같으면 이 게임의
-- 발판 그림은 충돌 상판보다 아래쪽에 그려져 있어서 캐릭터가 떠 보인다(실측). 값이 클수록 발이 땅에 더 파묻힌다(캐릭터가 더
-- 내려가 보임), 작을수록 떠 보인다. 0.127이면 이전(기본 히트박스)과 같은 높이였고, 그때도 살짝 떠 보여서 더 늘렸다.
balance.HERO_GROUND_SINK = 0.19

-- 씬 이동(포탈) 승인: 서버가 플레이어 위치와 포탈이 이만큼(px) 여유를 두고 겹치면 승인한다.
balance.TRAVEL_PORTAL_PADDING = 60

-- 인벤토리 칸 수(클라이언트 UI 그리드도 이 값으로 그린다).
balance.INVENTORY_COLUMNS = 4
balance.INVENTORY_ROWS = 4
balance.INVENTORY_SLOTS = balance.INVENTORY_COLUMNS * balance.INVENTORY_ROWS

return balance
