-- 탑다운 전투 수치(기본 공격·몬스터 체력) — 숫자는 전부 여기서 고친다.
-- 거리 단위는 "도트"(바닥 타일 1칸 = 16도트).
return {
	-- 기본 공격: 몸이 들썩이는 4장 애니메이션(공방 캐릭터 탭 "기본 공격"), hitFrame번째 장에서 한 번 판정.
	ATTACK_DAMAGE = 10,
	ATTACK_FRAME_TIME = 0.08, -- 한 장에 걸리는 시간(4장 = 0.32초)
	ATTACK_COOLDOWN = 0.1, -- 공격이 끝나고 다음 공격까지 쉬는 시간

	-- 일반 공격 범위: 바라보는 방향 앞쪽 사각형(발 위치 기준).
	--  reach = 앞으로 얼마나 닿나, width = 옆으로 얼마나 넓나
	ATTACK_REACH = 22,
	ATTACK_WIDTH = 22,

	-- 몬스터(체력·경험치는 레벨에 따라 — shared/config/monsterLevels.luau)
	MONSTER_RESPAWN = 6, -- 쓰러진 뒤 같은 스폰 구역에 다시 나타날 때까지(초)
}
