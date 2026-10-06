-- 「달의 계승자」(횡스크롤 MMORPG) 서버의 시작점. shared/config/features.luau의 GAME이 "lune"일 때 server/main.server.luau가 부른다.
--  server/lune/modules 아래의 모듈을 차례로 켠다. 지금은 world(사람 · 방 · 싸움) 하나다.
local World = require(script.Parent.modules.world)
local Chat = require(script.Parent.modules.chat)

local Boot = {}

function Boot.start()
	-- 이 게임의 캐릭터는 화면 위의 도트 그림이다 — Roblox 기본 캐릭터(3D)는 만들지 않는다.
	--  (만들어 두면 화살표 키로 보이지 않는 캐릭터가 같이 걷고, 스마트폰에서는 기본 조이스틱이 뜬다)
	local Players = game:GetService("Players")
	Players.CharacterAutoLoads = false
	for _, player in Players:GetPlayers() do
		if player.Character then
			player.Character:Destroy()
		end
	end
	World.start()
	Chat.start(World)
	print("[lune] 서버 시작")
end

function Boot.stop()
	World.stop() -- 서버가 닫힐 때 모두 저장한다
end

return Boot
