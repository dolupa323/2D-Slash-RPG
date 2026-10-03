-- 탑다운 전투 수치(기본 공격·몬스터 체력) — 숫자는 전부 여기서 고친다.
-- 거리 단위는 "도트"(바닥 타일 1칸 = 16도트).
return {
	-- 기본 공격: 몸이 들썩이는 4장 애니메이션(공방 캐릭터 탭 "기본 공격"), hitFrame번째 장에서 한 번 판정.
	ATTACK_DAMAGE = 10,
	ATTACK_FRAME_TIME = 0.08, -- 한 장에 걸리는 시간(4장 = 0.32초)
	ATTACK_COOLDOWN = 0.1, -- 공격이 끝나고 다음 공격까지 쉬는 시간

	-- 일반 공격 범위: 바라보는 방향 앞쪽 사각형(발 위치 기준).
	--  reach = 앞으로 얼마나 닿나, width = 옆으로 얼마나 넓나
	ATTACK_REACH = 20,
	ATTACK_WIDTH = 22,

	-- 투척 무기(단축칸): 연달아 던지는 최소 간격(초). 무기별 수치는 shared/data/ninjaItems.luau Throw
	THROW_COOLDOWN = 0.45,

	-- 몬스터(체력·경험치·공격력은 레벨에 따라 — shared/config/monsterLevels.luau)
	MONSTER_RESPAWN = 6, -- 쓰러진 뒤 같은 스폰 구역에 다시 나타날 때까지(초)

	-- 몬스터 반격: 맞으면 때린 사람을 쫓아가 공격한다(먼저 덤비지는 않음 — GAME_DESIGN §2 [제안])
	MONSTER_ATTACK_RANGE = 13, -- 이 거리(도트) 안이면 공격
	MONSTER_ATTACK_COOLDOWN = 1.6, -- 공격 간격(초)
	MONSTER_CHASE_SPEED = 1.3, -- 쫓을 때 속도 = 평소 × 이 값
	MONSTER_LEASH = 128, -- 집(나타난 자리)에서 이만큼 멀어지면 포기하고 돌아간다(도트)
	MONSTER_AGGRO_TIME = 8, -- 마지막으로 맞은 뒤 이 시간이 지나면 포기(초)
}
