-- 서버 권위 몬스터(sproutGrub.luau 등)가 어그로/피격 판정을 하려면 "플레이어가 지금
-- 어디 있는지", "언제 공격 버튼을 눌렀는지"를 알아야 한다. 이 프로젝트의 히어로는
-- client-authoritative(클라이언트가 직접 만들고 조작 — 공식 문서 Replication Guide/
-- Client Setup 패턴)라 서버는 히어로의 실제 좌표를 기본적으로 모른다 —
-- server/modules/replication.luau는 그냥 다른 클라이언트에게 전달만 해주는 릴레이라
-- 서버 자신은 내용물을 들여다보지 않는다(request:Approve()만 부르고 Accept()는 안 함).
--
-- 그래서 클라이언트가 자기 위치와 공격 순간을 이 전용 RemoteEvent로 서버에 직접
-- 알려주는 가벼운 경로를 둔다. 이 프로젝트 전체가 "일단 클라이언트를 신뢰하고 나중에
-- 필요해지면 검증을 추가한다"는 정책이라(server/modules/replication.luau 주석 참고)
-- 이 정도 신뢰 수준을 그대로 따른다 — 나중에 치트 방지가 필요해지면 여기서 신고된
-- 좌표를 실제 리플리케이션 데이터와 대조하는 식으로 검증을 추가할 수 있다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local reportPosition = remotes:FindFirstChild("ReportHeroPosition")
	if not reportPosition then
		reportPosition = Instance.new("RemoteEvent")
		reportPosition.Name = "ReportHeroPosition"
		reportPosition.Parent = remotes
	end

	local reportAttack = remotes:FindFirstChild("ReportHeroAttack")
	if not reportAttack then
		reportAttack = Instance.new("RemoteEvent")
		reportAttack.Name = "ReportHeroAttack"
		reportAttack.Parent = remotes
	end

	-- 반대 방향(서버 -> 클라): 몬스터가 플레이어를 때렸다고 서버가 판정하면, 그 플레이어의
	-- 히어로 Health를 깎는 건 클라이언트 자신만 할 수 있다(히어로는 client-authoritative
	-- 오브젝트라 서버가 직접 필드를 건드릴 수 없음) — 그래서 "너 맞았다"만 알려주고
	-- 실제 UpdateHealth 호출은 heroController.luau가 자기 로컬 히어로에 대고 한다.
	local monsterAttackedPlayer = remotes:FindFirstChild("MonsterAttackedPlayer")
	if not monsterAttackedPlayer then
		monsterAttackedPlayer = Instance.new("RemoteEvent")
		monsterAttackedPlayer.Name = "MonsterAttackedPlayer"
		monsterAttackedPlayer.Parent = remotes
	end

	-- (실측 버그 이력) 서버가 죽은 몬스터를 Destroy()해도 그건 서버 쪽 Lua 오브젝트에만
	-- 일어나는 일이라, 클라이언트가 이미 리플리케이트해서 로컬에 만들어둔 사본은 아무
	-- 신호도 못 받고 그대로 남는다(체력바까지 같이 유령처럼 계속 보임/희미한 채로
	-- 멈춤). NetworkingService에는 "이 오브젝트 없어졌다"를 알려주는 자동 매커니즘이
	-- 없어서(플레이어가 나갈 때만 자동 정리됨), 이 전용 이벤트로 직접 알려준다.
	local monsterDespawned = remotes:FindFirstChild("MonsterDespawned")
	if not monsterDespawned then
		monsterDespawned = Instance.new("RemoteEvent")
		monsterDespawned.Name = "MonsterDespawned"
		monsterDespawned.Parent = remotes
	end

	return reportPosition, reportAttack, monsterAttackedPlayer, monsterDespawned
end

-- UserId -> Vector2(화면 좌표계 Position.Offset)
local positions = {}
-- 공격 신고를 구독하는 콜백들: function(player, x, y)
local attackListeners = {}

local exports = {}

-- 몬스터 AI가 매 프레임 순회할 수 있게 원본 테이블을 그대로 노출한다(읽기 전용으로
-- 쓸 것 — 몬스터 쪽에서 이 테이블 자체를 수정하면 안 된다).
function exports.GetPositions()
	return positions
end

-- 여러 몬스터 모듈이 각자 구독할 수 있게 리스너 목록에 추가한다.
function exports.OnAttack(callback: (Player, number, number, string) -> ())
	table.insert(attackListeners, callback)
end

-- 몬스터 모듈이 "이 플레이어가 방금 맞았다"고 알릴 때 쓴다. attackerX는 넉백 방향
-- 계산용(플레이어 클라이언트가 "나보다 몬스터가 왼쪽/오른쪽 어디 있었는지" 알아야
-- 반대쪽으로 밀려나는 연출을 넣을 수 있다) — Phase 1 전투 타격감(ROADMAP.md).
function exports.NotifyPlayerHit(player: Player, damage: number, attackerX: number?)
	if not exports.monsterAttackedPlayerRemote then
		return
	end
	exports.monsterAttackedPlayerRemote:FireClient(player, damage, attackerX)
end

-- 몬스터 모듈이 "이 몬스터(Id)는 이제 완전히 없앨 것"이라고 모든 클라이언트에 알릴 때
-- 쓴다 — 죽는 페이드 애니메이션이 다 끝난 뒤, 실제로 Destroy()하기 직전에 호출해야 한다.
function exports.NotifyMonsterDespawned(monsterId: string)
	if not exports.monsterDespawnedRemote then
		return
	end
	exports.monsterDespawnedRemote:FireAllClients(monsterId)
end

function exports.load()
	local reportPosition, reportAttack, monsterAttackedPlayer, monsterDespawned = ensureRemotes()
	exports.monsterAttackedPlayerRemote = monsterAttackedPlayer
	exports.monsterDespawnedRemote = monsterDespawned

	reportPosition.OnServerEvent:Connect(function(player: Player, x, y)
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return
		end
		positions[player.UserId] = Vector2.new(x, y)
	end)

	reportAttack.OnServerEvent:Connect(function(player: Player, x, y, facing)
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return
		end
		if facing ~= "left" and facing ~= "right" then
			facing = "right"
		end
		for _, callback in attackListeners do
			task.spawn(callback, player, x, y, facing)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		positions[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports
