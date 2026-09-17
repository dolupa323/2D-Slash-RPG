-- 서버는 원래 씬 개념이 없었다 — 이 프로젝트가 지금까지 전부 클라이언트 UI로만 씬을
-- 그리는 구조였고(client/sceneLoader.luau), 서버 쪽 main.server.luau는 UpsideEngine을
-- 최초 1회 require만 하고 SceneManager를 전혀 쓰지 않았다.
--
-- 서버 권위 몬스터(AI/이동을 서버가 계산하고 자동 복제하는 방식 — 공식 문서
-- Replication Guide/Authority System: "Server objects replicate to clients automatically
-- by default")를 만들려면 서버도 "Monster_XXX" 같은 마커의 좌표를 읽을 수 있어야 한다.
-- 클라이언트(sceneLoader.luau)와 똑같은 방법으로 레벨 데이터를 불러온다 —
-- PluginSupportService:LoadPluginContent()는 ReplicatedStorage.UpsideEngineDB
-- Attribute(플러그인이 저장해둔 레벨 JSON)를 읽어서 Scene들을 만든다. 이 Attribute는
-- 게시된 place 데이터의 일부라 서버든 클라이언트든 각자 독립적으로 읽을 수 있고,
-- LoadPluginContent 내부에서 "isClient일 때만" 다 읽은 뒤 로컬로 지우기 때문에(클라이언트
-- 스크립트에서의 SetAttribute는 그 클라이언트 자신에게만 영향을 주고 서버나 다른
-- 클라이언트에는 전파되지 않음) 서버가 이걸 불러도 클라이언트 쪽에는 전혀 영향이 없다.
--
-- 화면에 그릴 필요가 없으니(서버는 렌더링을 안 함) Scene:Enable()로 SceneManager의
-- ActiveScenes 등록만 해두면 충분하다 — Instance를 어디 Parent할 필요도 없다.
--
-- 여러 몬스터 서버 모듈이 각자 LoadPluginContent()를 부르면 호출될 때마다 새 Id로
-- 씬을 통째로 다시 만들어버려서(같은 레벨이 여러 개 중복 등록됨) 문제가 생긴다 — 그래서
-- 최초 1회만 실제로 로드하고, 이후 호출은 이미 만들어진 씬을 그대로 돌려준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local PluginSupportService = UpsideEngine.GetService("PluginSupportService")
local SceneManager = UpsideEngine.GetService("SceneManager")

local loaded = false
local scenesByOriginalName = {}

local exports = {}

-- (실측 버그 이력) 씬 오브젝트는 NetworkingService의 자동 서버 복제(ServerReplication,
-- 기본 true)에 그대로 걸려서 클라이언트로도 전송된다 — 클라이언트가 이걸 받으면
-- Scene.new()가 또 호출되면서 SceneManager.Scenes에 이름이 똑같은(예: "Backfield") 빈
-- 씬 사본이 하나 더 생겨버린다. 그러면 클라이언트의 SceneManager:FindByName("Backfield")가
-- 진짜 씬과 이 빈 가짜 씬 중 어느 걸 돌려줄지 순서가 보장이 안 돼서(테이블 순회 순서는
-- 불특정), 간헐적으로 빈 씬을 잡아 포탈 등 이름 기반 오브젝트 검색이 전부 실패하는
-- 버그가 있었다(heroController.luau의 findObjectByName이 "씬은 찾았는데 그 안에 아무것도
-- 없음"으로 실패). 서버 쪽 씬의 이름을 원래 이름과 절대 겹치지 않게 바꿔서, 설령
-- 클라이언트에 복제되어 빈 가짜 사본이 생기더라도 원래 이름으로는 절대 안 잡히게 한다.
--
-- LoadPluginContent()는 JSON에 들어있는 씬을 "전부" 한 번에 만든다(village, Backfield
-- 등) — Backfield만 GetScene()으로 가져다 썼다고 해서 village가 안 만들어지는 게
-- 아니다. 그래서 이름 충돌을 막으려면 실제로 쓰는 씬만이 아니라 로드되는 씬 "전부"를
-- 즉시 리네임해야 한다.
local SERVER_NAME_SUFFIX = "__ServerOnly"

local function ensureLoaded()
	if loaded then
		return
	end
	loaded = true

	PluginSupportService:LoadPluginContent()

	for _, scene in SceneManager.Scenes do
		local originalName = scene.Name
		scene:Enable()
		scene:SetName(originalName .. SERVER_NAME_SUFFIX)
		scenesByOriginalName[originalName] = scene
	end
end

-- 필요한 씬을 이름으로 가져온다. 여러 몬스터/사냥터 모듈이 안전하게 반복 호출할 수 있다.
function exports.GetScene(name: string): Scene?
	ensureLoaded()
	return scenesByOriginalName[name]
end

function exports.load() end
function exports.start() end
function exports.unload() end

return exports
