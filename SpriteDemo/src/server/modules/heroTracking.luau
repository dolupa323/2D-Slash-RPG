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

	return reportPosition, reportAttack
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
function exports.OnAttack(callback: (Player, number, number) -> ())
	table.insert(attackListeners, callback)
end

function exports.load()
	local reportPosition, reportAttack = ensureRemotes()

	reportPosition.OnServerEvent:Connect(function(player: Player, x, y)
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return
		end
		positions[player.UserId] = Vector2.new(x, y)
	end)

	reportAttack.OnServerEvent:Connect(function(player: Player, x, y)
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return
		end
		for _, callback in attackListeners do
			task.spawn(callback, player, x, y)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		positions[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports
