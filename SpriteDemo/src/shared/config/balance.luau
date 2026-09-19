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

-- 씬 이동(포탈) 승인: 서버가 플레이어 위치와 포탈이 이만큼(px) 여유를 두고 겹치면 승인한다. 히어로 스프라이트 크기는
-- 클라이언트 heroController의 표시 크기(약 187x105)와 맞춘다.
balance.TRAVEL_PORTAL_PADDING = 60
balance.HERO_WIDTH = 187
balance.HERO_HEIGHT = 105

-- 인벤토리 칸 수(클라이언트 UI 그리드도 이 값으로 그린다).
balance.INVENTORY_COLUMNS = 4
balance.INVENTORY_ROWS = 4
balance.INVENTORY_SLOTS = balance.INVENTORY_COLUMNS * balance.INVENTORY_ROWS

return balance
