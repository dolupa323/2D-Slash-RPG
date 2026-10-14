-- 채팅이 누구에게 가는지 — Roblox의 채팅(TextChatService)에 얹는다. 글 거르기는 Roblox가 한다. 화면도 Roblox의 기본 채팅 창이다(2026-10-13 — client/lune/chat.luau).
--  둘레(기본 채널 RBXGeneral): 같은 맵에 있는 사람에게만 간다.
--  파티(채널 「파티」): 모두가 들어 있되, 같은 파티인 사람에게만 간다(파티가 없으면 나만 본다).
--  누가 어느 맵 · 어느 파티인지는 world.luau에 묻는다.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PARTY = require(ReplicatedStorage.shared.lune.data["ui.generated"]).chatUi.party.channel -- 파티 채널의 이름(Roblox 채팅의 채널 탭에 그대로 뜬다 — 화면의 chat.luau와 같은 자료)

local Chat = {}

function Chat.start(World)
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 15)
		if not channels then
			warn("[lune] 채팅 채널을 찾지 못했다 — 채팅은 Roblox 기본 그대로 돈다")
			return
		end
		local general = channels:WaitForChild("RBXGeneral", 15)
		if general then
			general.ShouldDeliverCallback = function(message, target)
				local from = message.TextSource
				if not from then
					return true
				end
				local a, b = World.sceneOf(from.UserId), World.sceneOf(target.UserId)
				return a == nil or b == nil or a == b
			end
		end
		local party = Instance.new("TextChannel")
		party.Name = PARTY
		party.Parent = channels
		party.ShouldDeliverCallback = function(message, target)
			local from = message.TextSource
			return from ~= nil and World.sameParty(from.UserId, target.UserId)
		end
		local function add(player)
			pcall(function()
				party:AddUserAsync(player.UserId)
			end)
		end
		Players.PlayerAdded:Connect(add)
		for _, player in Players:GetPlayers() do
			task.spawn(add, player)
		end
	end)
end

return Chat
