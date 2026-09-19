--!native
--!optimize 2
local checkCollision = require(script.Parent.CheckCollision)

local function isFar(objectA, objectB)
	local a = objectA.Instance
	local b = objectB.Instance
	local scaleA = objectA.HitboxScale
	local scaleB = objectB.HitboxScale

	local aw, ah = a.AbsoluteSize.X * scaleA, a.AbsoluteSize.Y * scaleA
	local bw, bh = b.AbsoluteSize.X * scaleB, b.AbsoluteSize.Y * scaleB

	local rA = math.sqrt(aw * aw + ah * ah) * 0.5
	local rB = math.sqrt(bw * bw + bh * bh) * 0.5

	local dx = (a.AbsolutePosition.X + a.AbsoluteSize.X * 0.5) - (b.AbsolutePosition.X + b.AbsoluteSize.X * 0.5)
	local dy = (a.AbsolutePosition.Y + a.AbsoluteSize.Y * 0.5) - (b.AbsolutePosition.Y + b.AbsoluteSize.Y * 0.5)
	local sumR = rA + rB

	return dx * dx + dy * dy > sumR * sumR
end

-- ClassNameHistory가 없는 오브젝트(플러그인이 만든 일부 오브젝트)에서도 안전하게 Character 여부를 본다.
local function isCharacter(object)
	local history = object.ClassNameHistory
	return type(history) == "string" and string.find(history, "Character", 1, true) ~= nil
end

local function shouldSkip(object, other)
	-- (프로젝트 패치) SkipCharacterCollisions가 켜진 오브젝트(로컬 플레이어 캐릭터)는 다른 Character(다른 플레이어의 사본/몬스터)와
	-- 물리 충돌하지 않는다 — 플레이어끼리 부딪혀서 못 움직이면 안 된다. 양방향으로 본다(다른 플레이어 사본을 시뮬레이션할 때도 스킵).
	if
		(object.SkipCharacterCollisions and isCharacter(other))
		or (other.SkipCharacterCollisions and isCharacter(object))
	then
		return true
	end

	return object.Id == other.Id
		or other.CollisionGroup ~= object.CollisionGroup
		or other.CollisionBlacklist[object.Id]
		or object.CollisionBlacklist[other.Id]
end

local function toVector3(v2)
	return Vector3.new(v2.X, v2.Y, 0)
end

local function getRotatedArea(instance, area, centre)
	if instance.Rotation == 0 then
		return area
	end

	local rotation = math.rad(instance.Rotation)
	local sin, cos = math.sin(rotation), math.cos(rotation)

	for i, vertex in area do
		local XDistance = vertex.X - centre.X
		local YDistance = vertex.Y - centre.Y

		-- stylua: ignore start
		vertex = Vector3.new(
			centre.X + XDistance * cos - YDistance * sin,
			centre.Y + XDistance * sin + YDistance * cos,
			0
		)
		-- stylua: ignore end
		area[i] = vertex
	end

	return area
end

local function getObjectData(object, velocity)
	local area = {}
	local instance = object.Instance

	local position = toVector3(instance.AbsolutePosition + velocity)
	local size = toVector3(instance.AbsoluteSize)

	local centre = position + size * 0.5
	local radius = if object.Shape == "circle" then (size.X / 2) * object.HitboxScale else nil

	local hitboxSize = size * object.HitboxScale
	local alignment = size * (1 - math.clamp(object.HitboxScale, 0, 1)) * 0.5
	local offset = position + alignment

	for i, vertex in object.Hitbox do
		area[i] = offset + hitboxSize * vertex
	end

	return {
		radius = radius,
		shape = object.Shape,
		centre = centre,
		area = getRotatedArea(instance, area, centre),
	}
end

return function(objects, object, velocity)
	local collisions = {}
	local objectData = getObjectData(object, velocity)

	for _, other in objects do
		if shouldSkip(object, other) or isFar(object, other) then
			continue
		end

		local otherData = getObjectData(other, Vector2.zero)
		local collision, moveVector = checkCollision(objectData, otherData)

		if not collision then
			continue
		end

		-- CanCollide=false인 상대는 겹쳐도 실제로 밀어내면 안 된다(예: 죽지 않는 몬스터
		-- 위에 서있을 수 있어야 함). 그런데 여기서 CanCollide 체크 없이 무조건
		-- velocity를 깎아버리면, 그 뒤에 검사하는 "진짜" 충돌 대상(바닥 등)의 moveVector
		-- 계산이 이미 오염된 velocity 기준으로 이루어져서 위아래로 미세하게 계속
		-- 튕기는 지터가 생긴다(실측 확인: CanCollide=false 몬스터와 겹친 상태에서만
		-- 플레이어 Y좌표가 초당 3~4회 왕복). CanCollide=false 쌍은 이벤트 발생용으로만
		-- collisions에 기록하고, velocity/moveVector 보정에는 관여시키지 않는다.
		if not object.CanCollide or not other.CanCollide then
			table.insert(collisions, {
				object = other,
				moveVector = Vector2.zero,
			})
			continue
		end

		local totalMass = object.Mass + other.Mass
		local ratio = if other.Anchored then 1 elseif totalMass == 0 then 0.5 else other.Mass / totalMass
		moveVector *= ratio
		velocity -= moveVector
		objectData = getObjectData(object, velocity)

		table.insert(collisions, {
			object = other,
			moveVector = moveVector,
		})
	end

	return collisions
end
