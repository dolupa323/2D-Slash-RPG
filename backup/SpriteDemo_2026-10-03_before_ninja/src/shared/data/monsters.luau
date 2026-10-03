-- 몬스터 정의(정적 표) — Ryzom의 creature sheet처럼 "몬스터가 어떤 존재인가"(스탯/스프라이트/판정 범위/드롭)를
-- 코드가 아니라 데이터로 둔다. 서버 몬스터 서비스(server/services/monsterAI.luau)와 클라이언트(체력바 식별,
-- 로딩 시 에셋 미리 받기)가 같은 표를 읽는다. 키는 lootTables.luau의 키와 같다.
local scenes = require(script.Parent.Parent.config.scenes)

local monsters = {}

-- 스폰 마커 이름 접두사(모든 몬스터 공통) — 레벨 디자이너가 씬에 "Monster_<종류><번호>" 이름의 마커를 놓는다.
monsters.MARKER_PREFIX = "Monster_"

monsters.SproutGrub = {
	Scene = scenes.HUNTING_GROUND,
	MarkerPrefix = "Monster_SproutGrub",

	-- 스프라이트 시트(상태+방향당 한 장). Source: Assets/character/talchar/three/monster/Sprout Grub/
	Sheets = {
		walk_left = "rbxassetid://92264999271413",
		walk_right = "rbxassetid://100223635620373",
		attack_left = "rbxassetid://98419651702250",
		attack_right = "rbxassetid://93586067969223",
		hit_left = "rbxassetid://107018587663153",
		hit_right = "rbxassetid://121503629119574",
	},
	Cell = Vector2.new(192, 108),
	DisplayHeight = 60, -- 화면에 보이는 높이(px)
	Grid = {
		walk_left = { cols = 5, frames = 35 },
		walk_right = { cols = 5, frames = 35 },
		attack_left = { cols = 5, frames = 35 },
		attack_right = { cols = 5, frames = 35 },
		-- hit는 12프레임 안에 끝나고 나머지는 같은 포즈 padding이라 12에서 끊는다.
		hit_left = { cols = 5, frames = 35, loopEnd = 12 },
		hit_right = { cols = 5, frames = 35, loopEnd = 12 },
	},
	SecondsPerFrame = { walk = 1 / 12, attack = 1 / 24, hit = 1 / 20 },
	Looping = { walk = true, attack = true, hit = false },
	AttackImpactFrame = 14, -- 공격 애니메이션(35프레임)의 약 40% 지점에서 판정

	-- 능력치
	MaxHealth = 30,
	AttackDamage = 5,
	ExperienceReward = 20,

	-- AI/판정 범위(px)
	PatrolRangeFallback = 80, -- 마커 폭이 0에 가까울 때 최소 순찰 범위
	PatrolSpeed = 70,
	AggroRange = 220,
	VerticalRange = 70, -- 어그로/공격이 가능한 세로 거리(같은 층만)
	AttackRange = 130, -- 몬스터 자신의 공격이 닿는 거리
	-- 플레이어 기본공격이 이 몬스터에 닿는 범위(바라보는 방향 앞쪽 기준)
	HitRangeFront = 170,
	HitRangeBack = 20,
	HitRangeVertical = 70,
	KnockbackDistance = 18,

	DeathFadeDuration = 0.5,
	RespawnDelayMin = 3,
	RespawnDelayMax = 4,
}

-- 모든 몬스터가 쓰는 스프라이트 시트 이미지 목록(클라이언트가 리플리케이트된 오브젝트가 몬스터인지 식별하거나
-- 로딩 화면에서 미리 받을 때 사용). 몬스터 정의를 추가하면 자동으로 포함된다.
function monsters.allSheetImages(): { [string]: boolean }
	local set = {}
	for key, def in monsters do
		if type(def) == "table" and def.Sheets then
			for _, image in def.Sheets do
				set[image] = true
			end
		end
	end
	return set
end

return monsters
