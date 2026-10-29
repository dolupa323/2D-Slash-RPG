-- 정지(2026-10-26 사용자: "클라 라는 닉네임 유저 찾아서 ip 까지 딴다음에 아예 게임못하게 정지시켜") — 관리 창 「정지」 탭이 부른다(world.luau의 onAdmin "ban").
--  닉네임 → 이름 장부(LuneNames_v1)의 계정 번호 → 로블록스의 정지(Players:BanAsync): 이 게임의 모든 장소 · 영구(-1) · 로블록스가 같은 사람의 부계정으로 보는 계정도 함께(ExcludeAltAccounts = false).
--  정지되면 접속 중인 서버에서 바로 쫓겨나고, 다시 들어오려 하면 로블록스가 남은 기간과 SHOW의 글을 띄우며 막는다.
--  IP는 쓰지 않는다: 로블록스는 개발자에게 사람의 IP를 주지 않는다 — 부계정까지 막는 것이 그 몫이다.
--  풀기 = Players:UnbanAsync. 관리자의 계정은 정지하지 않는다(잘못 적어 나를 막지 않게).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Account = require(ReplicatedStorage.shared.lune.sim.account)
local Store = require(script.Parent.store)
local Admin = require(script.Parent.admin)

local Ban = {}
Ban.SHOW = "운영 정책 위반으로 이 게임의 이용이 정지되었습니다. / You have been banned from this game for violating its rules." -- 정지된 사람이 보는 글(로블록스의 창 — 400자까지 · 로블록스가 거른다 · 두 말로: 2026-10-27 영문)

-- 앞뒤의 빈칸을 뗀다(빈칸은 ASCII로만 본다 — %s는 한글의 가운데 바이트를 빈칸으로 볼 수 있다: 2026-10-21)
local function trim(text: string): string
	return (string.gsub(string.gsub(text, "^[ \t\r\n]+", ""), "[ \t\r\n]+$", ""))
end

-- 닉네임 → 계정 번호. 못 찾으면 nil과 까닭
function Ban.find(name: any): (number?, string)
	if typeof(name) ~= "string" then
		return nil, "닉네임을 적어 주세요"
	end
	name = trim(name)
	if name == "" or #name > 60 then
		return nil, "닉네임을 적어 주세요"
	end
	local owner = Store.nameOwner(Account.nameKey(name))
	if owner == false then
		return nil, "이름 장부를 읽지 못했다 — 잠시 뒤 다시"
	elseif typeof(owner) ~= "number" then
		return nil, ("「%s」 닉네임은 없다"):format(name)
	end
	return owner, name
end

-- action = "find"(누구인지만) · "ban"(영구 정지) · "unban"(풀기). 돌려주는 것 { ok, msg, uid, roblox }
function Ban.run(by: any, name: any, action: any)
	if action ~= "find" and action ~= "ban" and action ~= "unban" then
		return { ok = false, msg = "모르는 일이다" }
	end
	local uid, shown = Ban.find(name)
	if not uid then
		return { ok = false, msg = shown }
	end
	local okName, roblox = pcall(function()
		return Players:GetNameFromUserIdAsync(uid)
	end)
	roblox = if okName and typeof(roblox) == "string" then roblox else "?"
	if action == "find" then
		return { ok = true, msg = ("%s — 찾았다"):format(shown), uid = uid, roblox = roblox }
	end
	if Admin.isId(uid) then
		return { ok = false, msg = "관리자의 계정은 정지할 수 없다", uid = uid, roblox = roblox }
	end
	local ok, err = pcall(function()
		if action == "ban" then
			Players:BanAsync({
				UserIds = { uid },
				ApplyToUniverse = true,
				Duration = -1,
				DisplayReason = Ban.SHOW,
				PrivateReason = ("관리 창(%s) — 닉네임 %s · %s"):format(tostring(by and by.Name), shown, os.date("!%Y-%m-%d %H:%M UTC")),
				ExcludeAltAccounts = false,
			})
		else
			Players:UnbanAsync({ UserIds = { uid }, ApplyToUniverse = true })
		end
	end)
	if not ok then
		warn("[lune] 정지 실패 " .. tostring(uid) .. ": " .. tostring(err))
		return { ok = false, msg = "로블록스가 받지 않았다 — 잠시 뒤 다시", uid = uid, roblox = roblox }
	end
	return { ok = true, msg = if action == "ban" then ("%s — 영구 정지했다"):format(shown) else ("%s — 정지를 풀었다"):format(shown), uid = uid, roblox = roblox }
end

return Ban
