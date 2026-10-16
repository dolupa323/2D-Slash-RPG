-- 관리자(어드민) — 누가 관리자인가. 이 파일은 서버에만 있다(ServerScriptService — 클라이언트로 복제되지 않는다).
--  사용자 2026-10-11: "저만 쓸수있는 어드민용 탭 만들어주세요 다른 유저들에게는 보이지않고, 어드민만 보이는 어드민관리탭 … 경험치 배율증가, 레벨 조정, 아이템발급 등등
--   여러 테스트용 편의 기능 … 누군가 해킹같은거해서 사용도 못해야하고 오직 어드민만 사용할수있어야합니다."
--  지키는 법:
--   ① 관리자인지는 서버가 그 사람의 로블록스 계정 번호(UserId — 로블록스가 정해 주는 값이라 클라이언트가 속일 수 없다)로만 가린다. 클라이언트가 보낸 「나는 관리자다」 같은 말은 어디에서도 듣지 않는다.
--   ② 관리자 명령(패킷 「Admin」)은 올 때마다 서버가 다시 가린다 — 관리 창을 억지로 띄우거나 패킷을 직접 쏴도, 관리자가 아니면 아무 일도 일어나지 않는다(대답도 하지 않는다).
--   ③ 명령의 값(레벨 · 수 · 아이템의 이름 · 장면의 이름)은 서버가 범위와 꼴을 다시 본다(server/lune/modules/world.luau의 onAdmin).
--   ④ 관리 창의 코드는 누구에게나 내려가지만(로블록스의 클라이언트 코드는 감출 수 없다) 창을 여는 단추는 서버가 「관리자」라고 알려 준 사람에게만 보인다. 감추는 것은 보기 좋으라고 하는 것이고, 막는 것은 ① ②다.
--  관리자를 더하려면 아래 IDS에 그 계정의 번호를 적는다(게임의 주인은 적지 않아도 관리자다).
local Admin = {}

-- 관리자의 계정 번호 → 메모(이름). 게임의 주인 dolupa95
Admin.IDS = {
	[10311679477] = "dolupa95",
}

-- 그 사람이 관리자인가(서버만 부른다)
function Admin.is(player: any): boolean
	if typeof(player) ~= "Instance" and typeof(player) ~= "table" then
		return false
	end
	return Admin.isId(player.UserId)
end

-- 그 계정 번호가 관리자인가(명예의 전당이 관리자의 줄을 거른다 — 2026-10-15)
function Admin.isId(id: any): boolean
	if typeof(id) ~= "number" or id <= 0 then
		return false
	end
	if Admin.IDS[id] ~= nil then
		return true
	end
	-- 게임의 주인(개인이 주인일 때)
	local ok, owner = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and game.CreatorId == id
	end)
	return ok and owner == true
end

return Admin
