-- 펫 스킬 연출(M4, 클라) — 서버 PetSkill(발동) · TownMonsterHit("pet:<종>", 맞음)을 받아 이펙트 팩 시트로 그린다.
--  이펙트·색·배율·방향은 종마다(shared/data/petSkills.generated — 공방 「펫 스킬」·「전투 연출」 탭과 같은 고른 값).
--  시트: 64x64 칸이 가로 16칸(shared/config/fxAssets.generated SHEETS — 업로드 전이면 아무것도 안 그림).
--  크기: 공방에서 배율 2 = 캐릭터 도트 1칸 밀도 → 화면 px = 64 × (배율/2) × CHAR_SCALE.
--  패턴(공방 skillTab과 같은 모양):
--   bolt  — 펫 자리에서 대상 몸으로 BOLT_FLIGHT초 날아감(원본 방향을 날아가는 쪽으로, 날 땐 hold 장 고정) → 도착하면 남은 장(또는 맞음 이펙트)
--   burst — 주인 몸 둘레에 크게 한 번
--   orbit — ORBIT_TIME초 동안 주인 둘레를 작은 이펙트 3개가 돎
--   drop  — 대상 자리(바닥에 맞춰, 여러 개면 둘레에 조금씩 늦게)에 DROP_DELAY 무렵 떨어짐/솟음
--   buff  — 주인 몸에 그 몬스터 이펙트
--  맞음: 펫 스킬로 맞은 몬스터마다 그 종의 hit 이펙트(작게).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local Net = require(ReplicatedStorage.shared.net.net)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local petSkills = require(ReplicatedStorage.shared.config.petSkills)
local fxAssets = require(ReplicatedStorage.shared.config["fxAssets.generated"])
local map = require(script.Parent.map)
local monsters = require(script.Parent.monsters)
local pets = require(script.Parent.pets)
local features = require(ReplicatedStorage.shared.config.features)

local G = petSkills.generated
local S = map.S
local CS = townAssets.CHAR_SCALE
local FRAME, COLS, FT = G.FRAME, G.COLS, G.FRAME_TIME
local Z = 8900 -- 월드 그림 위, 머리 위 글씨(9001~)·데미지 숫자(9500) 아래
local BODY = 15 -- 캐릭터 발에서 몸 가운데까지(캐릭터 도트)

local exports = {}
local gameFrame = nil
local active = {}

local function px(scale: number): number -- 이펙트 그림 1px → 화면 px
	return scale / 2 * CS
end

local function makeLabel(e)
	local label = Instance.new("ImageLabel")
	label.Name = "PetFx"
	label.BackgroundTransparency = 1
	label.Image = fxAssets.SHEETS[e.sheet] or ""
	label.ImageRectSize = Vector2.new(FRAME, FRAME)
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = Z
	label.Parent = gameFrame
	return label
end

local function setFrame(label: ImageLabel, e, f: number)
	local c = e.cell + f
	label.ImageRectOffset = Vector2.new((c % COLS) * FRAME, math.floor(c / COLS) * FRAME)
end

-- 이펙트 하나 재생. where(t) → 화면 px 가운데(Vector2) 또는 nil(그만). opt: scale, rotation(도), loop, startFrame, hold(t→고정 장), duration
local function play(key: string, where, opt)
	local e = G.effects[key]
	if not e or not gameFrame or not fxAssets.SHEETS[e.sheet] then
		return
	end
	task.spawn(function()
		local label = makeLabel(e)
		local size = FRAME * px(opt.scale or 2)
		label.Size = UDim2.fromOffset(size, size)
		label.Rotation = opt.rotation or 0
		local t = -(opt.delay or 0)
		label.Visible = false
		local alive = true
		active[label] = true
		while alive and label.Parent do
			t += task.wait()
			if t < 0 then
				continue
			end
			local f
			if opt.hold then
				f = opt.hold(t)
			else
				f = (opt.startFrame or 0) + math.floor(t / FT)
				if opt.loop then
					f %= e.frames
				end
			end
			local at = where(t)
			if not at or f >= e.frames or (opt.duration and t >= opt.duration) then
				alive = false
				break
			end
			setFrame(label, e, f)
			label.Position = UDim2.fromOffset(math.round(at.X), math.round(at.Y))
			label.Visible = true
		end
		active[label] = nil
		label:Destroy()
	end)
end

-- 주인 발(화면 px)
local function ownerFeet(userId: number): Vector2?
	if userId == Players.LocalPlayer.UserId then
		local hero = require(script.Parent.Parent.topDownHero)
		return hero.pos and hero.pos * S
	end
	for _, object in NetworkingService.PlayersData[userId] or {} do
		local instance = object.Instance
		if instance and gameFrame and instance:IsDescendantOf(gameFrame) then
			return Vector2.new(instance.Position.X.Offset, instance.Position.Y.Offset)
		end
	end
	return nil
end

local function bodyOf(feet: Vector2): Vector2
	return feet - Vector2.new(0, BODY * CS)
end

local function cast(userId: number, slot: number, speciesId: string, pattern: string, targetId: number, x: number, y: number)
	local sk = G.species[speciesId]
	if not sk then
		return
	end
	local fixedFeet = Vector2.new(x, y) * S -- 대상(없으면 주인 발) 자리 — 대상이 사라져도 여기에
	if pattern == "bolt" then
		local petAt = pets.PetPosition(userId, slot)
		local fromFeet = if petAt then petAt * S else ownerFeet(userId)
		if not fromFeet then
			return
		end
		local from = fromFeet - Vector2.new(0, monsters.BODY_PX * 0.6)
		local function target()
			local f = monsters.Feet(targetId) or fixedFeet
			return f - Vector2.new(0, monsters.BODY_PX)
		end
		local flight = petSkills.BOLT_FLIGHT
		local to0 = target()
		local ang = math.atan2(to0.Y - from.Y, to0.X - from.X)
		local rot = if sk.aim then math.deg(ang - sk.aim) else 0
		play(sk.fx, function(t)
			if t >= flight then
				return nil
			end
			local k = t / flight
			local to = target()
			return from + (to - from) * k - Vector2.new(0, math.sin(k * math.pi) * 6 * CS)
		end, { scale = sk.scale, rotation = rot, hold = function(t)
			return math.min(sk.hold, math.floor(t / FT))
		end })
		-- 도착: 남은 장(투사체가 터지는 모양) — 남은 장이 엉뚱한 그림이면 맞음 이펙트가 대신(TownMonsterHit 쪽)
		if not sk.noRest then
			play(sk.fx, function()
				return target()
			end, { scale = sk.scale, rotation = rot, startFrame = sk.hold, delay = flight })
		end
	elseif pattern == "burst" then
		local feet = ownerFeet(userId) or fixedFeet
		play(sk.fx, function()
			return bodyOf(feet)
		end, { scale = math.max(3, sk.scale) })
	elseif pattern == "orbit" then
		local r = petSkills.ORBIT_RADIUS * S
		for j = 0, 2 do
			play(sk.fx, function(t)
				local feet = ownerFeet(userId)
				if not feet then
					return nil
				end
				local a = t * 4 + j / 3 * math.pi * 2
				return feet + Vector2.new(math.cos(a) * r, math.sin(a) * r * 0.5 - BODY * CS * 0.6)
			end, { scale = 1, loop = true, duration = petSkills.ORBIT_TIME })
		end
	elseif pattern == "drop" then
		local spots = { { 0, 0, 0 }, { -22, -8, 0.1 }, { 20, 6, 0.18 } }
		local lift = 26 * px(sk.scale) -- 그림 아래쪽이 바닥에 오도록
		for i = 1, math.min(sk.multi or 1, 3) do
			local o = spots[i]
			local feet = (monsters.Feet(targetId) or fixedFeet) + Vector2.new(o[1], o[2]) * CS / 2
			play(sk.fx, function()
				return feet - Vector2.new(0, lift)
			end, { scale = sk.scale, delay = math.max(0, petSkills.DROP_DELAY - 0.2) + o[3] })
		end
	elseif pattern == "buff" then
		play(sk.fx, function()
			local feet = ownerFeet(userId)
			return feet and bodyOf(feet)
		end, { scale = sk.scale })
	end
end

function exports.load(scene: Scene)
	if not features.PETS then
		return
	end
	local d = map.Use(scene)
	if not d then
		return
	end
	gameFrame = scene.Instance.GameFrame
	local key = map.key
	exports.conns = {
		Net.OnClient("PetSkill", function(sceneKey, userId, slot, speciesId, pattern, targetId, x, y)
			if sceneKey == key and gameFrame then
				cast(userId, slot, speciesId, pattern, targetId, x, y)
			end
		end),
		-- 펫 스킬로 맞은 몬스터 몸 위에 그 종의 맞음 이펙트
		Net.OnClient("TownMonsterHit", function(sceneKey, id, _hp, _damage, _attacker, source)
			if sceneKey ~= key or typeof(source) ~= "string" or string.sub(source, 1, 4) ~= "pet:" then
				return
			end
			local sk = G.species[string.sub(source, 5)]
			local feet = monsters.Feet(id)
			if not sk or sk.hit == "" or not feet then
				return
			end
			local at = feet - Vector2.new(math.random(-3, 3), monsters.BODY_PX + math.random(-3, 3))
			play(sk.hit, function()
				return at
			end, { scale = 1.4 })
		end),
	}
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	for _, c in exports.conns or {} do
		c:Disconnect()
	end
	exports.conns = nil
	for label in active do
		label:Destroy()
	end
	table.clear(active)
	gameFrame = nil
end

return exports
