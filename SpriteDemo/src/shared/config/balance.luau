-- 게임 규칙 수치(밸런스)의 "단 하나의 출처". 서버와 클라이언트가 같은 값을 각자 하드코딩하면 한쪽만
-- 고쳐서 표시와 실제가 어긋나므로(예: 최대 체력 공식이 클라/서버에 따로 있었음), 규칙에 관련된
-- 숫자와 공식은 전부 여기에만 두고 양쪽이 이 파일을 읽는다.
local balance = {}

-- 성장
balance.BASE_MAX_HEALTH = 100
balance.MAX_HEALTH_PER_LEVEL = 20
balance.BASE_ATTACK = 10
balance.ATTACK_PER_LEVEL = 2 -- 레벨업마다 오르는 공격력(「오문 닌자전」 §3-3 — 따로 찍지 않고 자동으로 오른다)
balance.BASE_DEFENSE = 0

-- 사망 페널티(GAME_DESIGN §7): 지금 레벨 필요 경험치의 5% + 가진 골드의 5%를 잃는다. 레벨은 내려가지 않는다.
balance.DEATH_EXP_LOSS = 0.05
balance.DEATH_GOLD_LOSS = 0.05

-- 레벨에서 오는 공격력(무기 · 강화는 따로 더한다 — server inventoryService.GetAttackDamage)
function balance.attackFor(level: number): number
	return balance.BASE_ATTACK + (math.max(level, 1) - 1) * balance.ATTACK_PER_LEVEL
end

function balance.maxHealthFor(level: number): number
	return balance.BASE_MAX_HEALTH + (level - 1) * balance.MAX_HEALTH_PER_LEVEL
end

-- 레벨업 필요 경험치: 1레벨 100, 2레벨 150, ...
function balance.maxExperienceFor(level: number): number
	return 100 + (level - 1) * 50
end

-- 인벤토리: 탭(장비·소비·기타·캐시·중요)마다 칸이 따로 있다. 탭당 칸 수(클라이언트 UI 그리드도 이 값으로 그린다).
balance.INVENTORY_TABS = { "Equip", "Use", "Etc", "Cash", "Key" }
balance.INVENTORY_TAB_NAMES = { Equip = "장비", Use = "소비", Etc = "기타", Cash = "캐시", Key = "중요" }
balance.INVENTORY_COLUMNS = 6
balance.INVENTORY_ROWS = 4
balance.INVENTORY_SLOTS = balance.INVENTORY_COLUMNS * balance.INVENTORY_ROWS

-- 월드 드랍(땅에 버려진 아이템): 이 시간(초)이 지나면 사라진다. 줍기 거리(도트, 발 기준) — 서버는 복제 지연만큼 여유를 더 준다.
balance.WORLD_DROP_LIFETIME = 90
balance.PICKUP_RANGE = 20
balance.PICKUP_PAD = 16

-- 탑다운 전투(서버 권위): 공격 판정 최소 간격(초) — 클라이언트 공격 동작(4장 x 0.08초 + 쉬는 0.1초)보다 약간 짧게.
balance.TOWN_ATTACK_COOLDOWN = 0.35

return balance
